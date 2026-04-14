#!/usr/bin/env bash
# memos-storage-migrate.sh — migrate memos attachments from DATABASE to S3
# Run once. Safe to re-run (checks storage_type before migrating).
set -euo pipefail

DB="${MEMOS_DB:-/root/apps/memos/data/memos_prod.db}"
STORAGE_KEY="GK2b96d253cf726aa6848665d1"
STORAGE_SECRET="3836a6809fe420f0a489e5745329dd8a2ab95946ea9d0da28ee0eba5c38ac873"
S3_ENDPOINT="http://localhost:3900"
S3_REGION="garage"
S3_BUCKET="memos"
RCLONE_CONF="/root/.config/rclone/rclone-garage-temp.conf"

if [[ ! -f "${DB}" ]]; then
  echo "[ERROR] DB not found: ${DB}"
  exit 1
fi

# Ensure rclone config for S3
mkdir -p "$(dirname "${RCLONE_CONF}")"
cat > "${RCLONE_CONF}" <<EOF
[garage_s3]
type = s3
provider = Other
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION}
access_key_id = ${STORAGE_KEY}
secret_access_key = ${STORAGE_SECRET}
force_path_style = true
no_check_bucket = true
EOF

# Count attachments to migrate (storage_type empty = DATABASE)
TOTAL=$(sqlite3 "${DB}" "SELECT COUNT(*) FROM attachment WHERE blob IS NOT NULL AND storage_type = '';")
if [[ "${TOTAL}" -eq 0 ]]; then
  echo "[OK] No attachments to migrate (all already in S3 or LOCAL)"
  exit 0
fi

echo "[INFO] Found ${TOTAL} attachment(s) to migrate from DATABASE to S3"

# Iterate over each attachment with a DB blob
sqlite3 "${DB}" "SELECT id, uid, filename, blob FROM attachment WHERE blob IS NOT NULL AND storage_type = '';" | while IFS='|' read -r id uid filename blob_hex; do
  # Convert hex to binary
  blob_size=$((${#blob_hex} / 2))
  blob_file=$(mktemp)

  # Decode hex blob to binary
  xxd -r -p <<< "${blob_hex}" > "${blob_file}"

  # Upload to S3
  key="attachments/migrated_$(date +%Y%m%d%H%M%S)_${uid}_${filename}"
  echo "[INFO] Uploading attachment ${id} (${filename}, ${blob_size} bytes) to S3..."
  if ! rclone --config="${RCLONE_CONF}" copyto "${blob_file}" "garage_s3:${S3_BUCKET}/${key}" 2>/dev/null; then
    echo "[ERROR] Failed to upload ${id} to S3"
    rm -f "${blob_file}"
    continue
  fi

  # Update DB
  now_ts=$(date +%s)
  python3 - <<PY
import sqlite3, json, os
DB = os.environ['DB']
conn = sqlite3.connect(DB)
cur = conn.cursor()
payload = json.dumps({
    "s3Object": {
        "s3Config": {
            "accessKeyId": "${STORAGE_KEY}",
            "accessKeySecret": "${STORAGE_SECRET}",
            "endpoint": "${S3_ENDPOINT}",
            "region": "${S3_REGION}",
            "bucket": "${S3_BUCKET}",
            "usePathStyle": True
        },
        "key": "${key}"
    }
})
cur.execute("""
    UPDATE attachment
    SET blob = NULL,
        storage_type = 'S3',
        reference = ?,
        payload = ?,
        size = ?,
        updated_ts = ?
    WHERE id = ?
""", ("${key}", payload, ${blob_size}, ${now_ts}, ${id}))
conn.commit()
conn.close()
PY

  rm -f "${blob_file}"
  echo "[OK] Attachment ${id} migrated: S3 key = ${key}"
done

echo "[INFO] Migration complete"
echo "Remaining DB blobs:"
sqlite3 "${DB}" "SELECT id, filename, length(blob), storage_type FROM attachment;" | while IFS='|' read -r id fn sz st; do
  echo "  id=${id} filename=${fn} blob_size=${sz:-0} storage_type=${st}"
done
