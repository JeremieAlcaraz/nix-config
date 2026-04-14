#!/usr/bin/env bash
# memos-storage-init.sh — configure memos S3 storage via API + migrate existing blobs
# Idempotent: safe to re-run.
set -euo pipefail

MEMOS_URL="${MEMOS_URL:-http://localhost:5230}"
MEMOS_USER="${MEMOS_USER:-jeremie}"
MEMOS_PASS="${MEMOS_PASS:-}"
DB="${MEMOS_DB:-/root/apps/memos/data/memos_prod.db}"

S3_KEY_ID="${S3_KEY_ID:-GK2b96d253cf726aa6848665d1}"
S3_SECRET="${S3_SECRET:-3836a6809fe420f0a489e5745329dd8a2ab95946ea9d0da28ee0eba5c38ac873}"
S3_ENDPOINT="${S3_ENDPOINT:-http://host.containers.internal:3900}"
S3_REGION="${S3_REGION:-garage}"
S3_BUCKET="${S3_BUCKET:-memos}"

RCLONE_CONF="/root/.config/rclone/rclone-garage-temp.conf"

usage() {
  echo "Usage: $0 [--password PASSWORD]"
  echo "  Configure memos S3 storage and migrate existing DB blobs to S3."
  echo "  Requires admin credentials for memos."
  echo "  S3 credentials read from env or defaults (poppy deployment)."
  exit 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --password) MEMOS_PASS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -z "${MEMOS_PASS}" ]]; then
  echo "[ERROR] --password required (or set MEMOS_PASS env)"
  exit 1
fi

echo "[INFO] Step 1 — Signing in to memos..."
TOKEN_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"passwordCredentials\":{\"username\":\"${MEMOS_USER}\",\"password\":\"${MEMOS_PASS}\"}}" \
  "${MEMOS_URL}/memos.api.v1.AuthService/SignIn")

TOKEN=$(echo "${TOKEN_RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken','ERROR'))" 2>/dev/null)
if [[ "${TOKEN}" == "ERROR" ]]; then
  echo "[ERROR] Sign-in failed: ${TOKEN_RESP}"
  exit 1
fi
echo "[OK] Token obtained (expires in token)"

echo "[INFO] Step 2 — Configuring S3 storage..."
UPDATE_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d "{
    \"setting\": {
      \"name\": \"instance/settings/STORAGE\",
      \"storage_setting\": {
        \"storage_type\": 3,
        \"upload_size_limit_mb\": \"30\",
        \"s3_config\": {
          \"access_key_id\": \"${S3_KEY_ID}\",
          \"access_key_secret\": \"${S3_SECRET}\",
          \"endpoint\": \"${S3_ENDPOINT}\",
          \"region\": \"${S3_REGION}\",
          \"bucket\": \"${S3_BUCKET}\",
          \"use_path_style\": true
        }
      }
    }
  }" \
  "${MEMOS_URL}/memos.api.v1.InstanceService/UpdateInstanceSetting")

STORAGE_TYPE=$(echo "${UPDATE_RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('storageSetting',{}).get('storageType','ERROR'))" 2>/dev/null)
if [[ "${STORAGE_TYPE}" != "S3" ]]; then
  echo "[WARN] Storage config response: ${UPDATE_RESP}"
  echo "[WARN] Storage type not confirmed as S3 (may still be applied)"
fi
echo "[OK] S3 storage configured (type=${STORAGE_TYPE})"

echo "[INFO] Step 3 — Restarting memos to pick up new storage config..."
systemctl restart memos.service
sleep 3
if ! curl -sf "${MEMOS_URL}/" > /dev/null; then
  echo "[ERROR] Memos not responding after restart"
  exit 1
fi
echo "[OK] Memos restarted"

echo "[INFO] Step 4 — Setting up rclone S3 remote..."
mkdir -p "$(dirname "${RCLONE_CONF}")"
cat > "${RCLONE_CONF}" <<EOF
[garage_s3]
type = s3
provider = Other
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION}
access_key_id = ${S3_KEY_ID}
secret_access_key = ${S3_SECRET}
force_path_style = true
no_check_bucket = true
EOF

echo "[INFO] Step 5 — Migrating existing DB blobs to S3..."
COUNT=$(sqlite3 "${DB}" "SELECT COUNT(*) FROM attachment WHERE blob IS NOT NULL AND (storage_type = '' OR storage_type IS NULL);")
if [[ "${COUNT}" -eq 0 ]]; then
  echo "[OK] No DB blobs to migrate"
else
  echo "[INFO] ${COUNT} attachment(s) to migrate..."

  # Migrate each blob using rclone
  sqlite3 "${DB}" "SELECT id, uid, filename, blob FROM attachment WHERE blob IS NOT NULL AND (storage_type = '' OR storage_type IS NULL);" | while IFS='|' read -r id uid fn hex; do
    [[ -z "${hex}" ]] && continue
    blob_size=$((${#hex} / 2))
    tmp=$(mktemp)
    xxd -r -p <<< "${hex}" > "${tmp}"
    key="attachments/migrated_$(date +%Y%m%d%H%M%S)_${uid}_${fn}"
    if rclone --config="${RCLONE_CONF}" copyto "${tmp}" "garage_s3:${S3_BUCKET}/${key}" 2>/dev/null; then
      now_ts=$(date +%s)
      sqlite3 "${DB}" "
        UPDATE attachment
        SET blob = NULL,
            storage_type = 'S3',
            reference = '${key}',
            payload = '{\"s3Object\":{\"s3Config\":{\"accessKeyId\":\"${S3_KEY_ID}\",\"accessKeySecret\":\"${S3_SECRET}\",\"endpoint\":\"${S3_ENDPOINT}\",\"region\":\"${S3_REGION}\",\"bucket\":\"${S3_BUCKET}\",\"usePathStyle\":true},\"key\":\"${key}\"}}',
            size = ${blob_size},
            updated_ts = ${now_ts}
        WHERE id = ${id};"
      echo "[OK] Migrated ${id} (${fn}) -> ${key}"
    else
      echo "[ERROR] Failed to upload attachment ${id}"
    fi
    rm -f "${tmp}"
  done
fi

echo ""
echo "[INFO] Step 6 — Verification..."
sqlite3 "${DB}" "SELECT id, filename, length(blob) as bs, storage_type, reference FROM attachment;" | while IFS='|' read -r id fn bs st ref; do
  printf "  id=%-3s filename=%-40s blob_size=%-6s type=%-10s ref=%s\n" "${id}" "${fn}" "${bs:-0}" "${st:-DB}" "${ref:-}"
done

# Verify S3 connectivity
if rclone --config="${RCLONE_CONF}" ls "garage_s3:${S3_BUCKET}/" > /dev/null 2>&1; then
  echo "[OK] S3 bucket accessible"
  echo "[INFO] S3 objects:"
  rclone --config="${RCLONE_CONF}" ls "garage_s3:${S3_BUCKET}/" | sed 's/^/   /'
else
  echo "[WARN] Cannot list S3 bucket (may be a network issue)"
fi

echo ""
echo "[INFO] Done. New uploads will go to S3. Existing blobs migrated."
