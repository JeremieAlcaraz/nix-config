#!/usr/bin/env bash
set -euo pipefail

REMOTE="${MEMOS_REMOTE:-gdrive_capsule:proxmox/memos}"
BACKUP_DIR="${MEMOS_BACKUP_DIR:-/root/apps/memos/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

rclone copy "$BACKUP_DIR" "$REMOTE" --transfers=4 --fast-list --log-level INFO
rclone delete "$REMOTE" --min-age "${RETENTION_DAYS}d"

echo "[$(date)] Upload Memos termine: $REMOTE"
