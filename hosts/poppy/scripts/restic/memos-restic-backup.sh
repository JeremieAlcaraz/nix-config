#!/usr/bin/env bash
# memos-restic-backup.sh — backup memos via restic (versioned snapshots)
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:memos"
SOURCE="/root/apps/memos/data"
LOG="/var/log/memos-restic-backup.log"
KEEP_DAYS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Memos restic backup started ==="

# Backup
if restic backup "${SOURCE}" \
  --repo "${REPO}" \
  --host poppy \
  --tag memos \
  --verbose 2>&1 | tee -a "${LOG}"; then
  log "[OK] Backup complete"
else
  log "[ERROR] Backup failed"
  exit 1
fi

log "=== Memos restic backup done ==="