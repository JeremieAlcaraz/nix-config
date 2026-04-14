#!/usr/bin/env bash
# memos-backup-s3.sh — backup Garage S3 objects for memos bucket to Drive
# Uses rclone to sync the memos S3 bucket to Google Drive
set -euo pipefail

S3_BUCKET="${S3_BUCKET:-memos}"
S3_ENDPOINT="${S3_ENDPOINT:-http://localhost:3900}"
S3_REGION="${S3_REGION:-garage}"
REMOTE_NAME="gdrive_capsule"
REMOTE_PATH="${REMOTE_NAME}:memos/s3-objects"
RCLONE_CONF="/root/.config/rclone/rclone.conf"

# Read S3 credentials from deployed env file
ENV_FILE="/root/apps/memos/.env.s3"
if [[ -f "${ENV_FILE}" ]]; then
  source "${ENV_FILE}"
fi

: "${MEMOS_GARAGE_ACCESS_KEY_ID:?Missing MEMOS_GARAGE_ACCESS_KEY_ID}"
: "${MEMOS_GARAGE_SECRET_ACCESS_KEY:?Missing MEMOS_GARAGE_SECRET_ACCESS_KEY}"

echo "[$(date)] S3 backup: syncing s3://${S3_BUCKET} -> ${REMOTE_PATH}"

# Create a temporary rclone S3 remote (garage_s3) for this backup
TEMP_CONF=$(mktemp)
cat > "${TEMP_CONF}" <<EOF
[garage_s3_backup]
type = s3
provider = Other
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION}
access_key_id = ${MEMOS_GARAGE_ACCESS_KEY_ID}
secret_access_key = ${MEMOS_GARAGE_SECRET_ACCESS_KEY}
force_path_style = true
no_check_bucket = true
EOF

# Combine S3 remote config with the main rclone.conf (append S3 remote section)
COMBINED_CONF="${TEMP_CONF}.combined"
cp "${RCLONE_CONF}" "${COMBINED_CONF}"
cat "${TEMP_CONF}" >> "${COMBINED_CONF}"

# Sync S3 bucket to Drive
rclone sync "garage_s3_backup:${S3_BUCKET}" "${REMOTE_PATH}/" \
  --config "${COMBINED_CONF}" \
  --transfers=4 \
  --fast-list \
  --log-level INFO \
  --log-file "/var/log/memos-s3-backup.log"

rm -f "${TEMP_CONF}" "${TEMP_CONF}.combined"
echo "[$(date)] S3 backup complete: s3://${S3_BUCKET} -> ${REMOTE_PATH}"
