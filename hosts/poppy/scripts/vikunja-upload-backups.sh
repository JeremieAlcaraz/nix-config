#!/usr/bin/env bash
set -euo pipefail

REMOTE="gdrive_capsule:vikunja"
BACKUP_DIR="/root/apps/vikunja/backups"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

rclone copy "$BACKUP_DIR" "$REMOTE" --transfers=4 --fast-list --log-level INFO
rclone delete "$REMOTE" --min-age "${RETENTION_DAYS}d"

echo "[$(date)] Upload termine: $REMOTE"
