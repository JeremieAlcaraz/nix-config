#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/root/apps/memos/backups"
DATA_DIR="/root/apps/memos/data"
DB_PATH="${DATA_DIR}/memos_prod.db"
STAMP="$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
OUT_FILE="${BACKUP_DIR}/memos-${STAMP}.sqlite3"

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$DB_PATH" ]]; then
  echo "[WARN] DB introuvable: $DB_PATH"
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[ERROR] sqlite3 introuvable"
  exit 1
fi

sqlite3 "$DB_PATH" ".backup '$OUT_FILE'"

find "$BACKUP_DIR" -type f -mtime "+$RETENTION_DAYS" -delete

echo "[$(date)] Backup Memos termine: $OUT_FILE"
