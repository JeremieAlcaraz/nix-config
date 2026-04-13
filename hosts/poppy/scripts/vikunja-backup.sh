#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/root/apps/vikunja"
STATE_DIR="${APP_DIR}/data"
BACKUP_DIR="${APP_DIR}/backups"
DB_PATH="${STATE_DIR}/vikunja.db"
STAMP="$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$BACKUP_DIR"

sqlite3 "$DB_PATH" ".backup '$BACKUP_DIR/vikunja-$STAMP.sqlite3'"
tar -C "$STATE_DIR" -czf "$BACKUP_DIR/vikunja-files-$STAMP.tar.gz" files

find "$BACKUP_DIR" -type f -mtime "+$RETENTION_DAYS" -delete

echo "[$(date)] Backup termine: $BACKUP_DIR"
