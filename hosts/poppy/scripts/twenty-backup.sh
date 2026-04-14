#!/usr/bin/env bash
# twenty-backup.sh — dump SQL + sync S3 → Drive
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
BAK_DIR="/root/.bak"
RCLONE_CONF="/root/.config/rclone/rclone.conf"
APP_DIR="/root/apps/twenty"
S3_BUCKET="twenty"
S3_ENDPOINT="http://localhost:3900"
REMOTE_PATH="gdrive_capsule:twenty"
LOG_FILE="/var/log/twenty-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

# Source credentials from .env
if [[ -f "${APP_DIR}/.env" ]]; then
  set -a; source "${APP_DIR}/.env"; set +a
else
  log "[ERROR] .env not found at ${APP_DIR}/.env"
  exit 1
fi

# Read PG password from .env
PG_PASSWORD="${PG_DATABASE_PASSWORD}"
PG_USER="${PG_DATABASE_USER:-postgres}"

log "=== Twenty backup started ==="
log "TS: ${TS}"

# ── Dump PostgreSQL ────────────────────────────────────────
DUMP_FILE="${BAK_DIR}/twenty-dump-${TS}.sql.gz"
log "Dumping PostgreSQL DB to ${DUMP_FILE}..."

# pg_dump via podman exec (container name)
if podman exec twenty-db pg_dump -U "${PG_USER}" -d default 2>/dev/null | gzip > "${DUMP_FILE}"; then
  DUMP_SIZE=$(du -h "${DUMP_FILE}" | cut -f1)
  log "[OK] Dump saved: ${DUMP_SIZE}"
else
  log "[ERROR] pg_dump failed"
  exit 1
fi

# ── Sync S3 bucket → Drive ──────────────────────────────────
log "Syncing S3 bucket ${S3_BUCKET} -> ${REMOTE_PATH}/s3-objects/..."

# Build S3 remote config
TEMP_CONF=$(mktemp)
cat > "${TEMP_CONF}" <<EOF
[garage_backup]
type = s3
provider = Other
endpoint = ${S3_ENDPOINT}
region = garage
access_key_id = ${STORAGE_S3_ACCESS_KEY_ID}
secret_access_key = ${STORAGE_S3_SECRET_ACCESS_KEY}
force_path_style = true
no_check_bucket = true
EOF

COMBINED_CONF="${TEMP_CONF}.combined"
cp "${RCLONE_CONF}" "${COMBINED_CONF}"
cat "${TEMP_CONF}" >> "${COMBINED_CONF}"

if rclone sync "garage_backup:${S3_BUCKET}" "${REMOTE_PATH}/s3-objects/" \
  --config "${COMBINED_CONF}" \
  --transfers=4 \
  --fast-list \
  --log-level INFO \
  --log-file "${LOG_FILE}" 2>&1; then
  log "[OK] S3 sync complete"
else
  log "[WARN] S3 sync failed (continuing)"
fi

# ── Upload SQL dump → Drive ────────────────────────────────
log "Uploading SQL dump to ${REMOTE_PATH}/..."
if rclone copyto "${DUMP_FILE}" "${REMOTE_PATH}/dump-twenty.sql.gz" \
  --config "${COMBINED_CONF}" \
  --log-level INFO \
  --log-file "${LOG_FILE}" 2>&1; then
  log "[OK] Dump uploaded to Drive"
else
  log "[ERROR] Failed to upload dump"
fi

# Cleanup
rm -f "${TEMP_CONF}" "${COMBINED_CONF}"

# Prune old dumps (keep last 7)
cd "${BAK_DIR}" || exit 1
ls -t twenty-dump-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
DUMP_COUNT=$(ls twenty-dump-*.sql.gz 2>/dev/null | wc -l)
log "Dumps retained: ${DUMP_COUNT} (max 7)"

log "=== Twenty backup complete ==="