#!/usr/bin/env bash
# memos-backup-s3.sh — backup Garage S3 objects for memos bucket
# Uses rclone to sync the memos S3 bucket to local + upload to Drive
set -euo pipefail

BACKUP_DIR="/root/apps/memos/backups"
S3_BUCKET="memos"
S3_ENDPOINT="http://localhost:3900"
S3_REGION="garage"
REMOTE_NAME="gdrive_capsule"
REMOTE_PATH="${REMOTE_NAME}:memos/s3-objects"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOCAL_SNAPSHOT="${BACKUP_DIR}/s3-snapshot-${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"

# Read credentials from the memos env file (deployed by poppy-apply)
if [[ -f /root/apps/memos/.env.s3 ]]; then
  source /root/apps/memos/.env.s3
fi

: "${AWS_ACCESS_KEY_ID:?Missing AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Missing AWS_SECRET_ACCESS_KEY}"

echo "[$(date)] S3 backup: syncing s3://${S3_BUCKET} -> ${REMOTE_PATH}"

# Configure rclone S3 remote for Garage
RCLONE_CONF="/root/.config/rclone/rclone.conf"
if ! rclone listremotes | grep -q "^garage_s3:"; then
  echo "[INFO] Adding garage_s3 remote to rclone"
  rclone config create garage_s3 s3 \
    provider=Other \
    endpoint="${S3_ENDPOINT}" \
    region="${S3_REGION}" \
    access_key_id="${AWS_ACCESS_KEY_ID}" \
    secret_access_key="${AWS_SECRET_ACCESS_KEY}" \
    force_path_style=true \
    no_check_bucket=true
fi

# Sync S3 objects to Drive (direct, no local copy)
rclone sync "garage_s3:${S3_BUCKET}" "${REMOTE_PATH}/" \
  --transfers=4 \
  --fast-list \
  --log-level INFO \
  --log-file "/var/log/memos-s3-backup.log"

echo "[$(date)] S3 backup complete: garage_s3:${S3_BUCKET} -> ${REMOTE_PATH}"
