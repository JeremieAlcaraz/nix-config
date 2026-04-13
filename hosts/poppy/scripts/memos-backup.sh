#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/root/apps/memos/backups"
DATA_DIR="/root/apps/memos/data"
STAMP="$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$BACKUP_DIR"

if [[ -f "$DATA_DIR/memos_prod.db" ]]; then
  cp "$DATA_DIR/memos_prod.db" "$BACKUP_DIR/memos-$STAMP.db"
fi

find "$BACKUP_DIR" -type f -mtime "+$RETENTION_DAYS" -delete

echo "[$(date)] Backup Memos termine"
