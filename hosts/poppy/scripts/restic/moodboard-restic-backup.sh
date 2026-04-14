#!/usr/bin/env bash
# moodboard-restic-backup.sh — backup moodboard via restic
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:moodboard-bak"
SOURCE="/root/apps/moodboard"
LOG="/var/log/moodboard-restic-backup.log"
KEEP_DAYS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Moodboard restic backup started ==="

# Exclude Containerfile and docker build cache
if restic backup "${SOURCE}" \
  --repo "${REPO}" \
  --host poppy \
  --tag moodboard \
  --exclude="*/node_modules" \
  --exclude="*/.cache" \
  --exclude="*.log" \
  2>&1 | tee -a "${LOG}"; then
  log "[OK] Backup complete"
else
  log "[ERROR] Backup failed"
  exit 1
fi

if restic forget \
  --repo "${REPO}" \
  --keep-daily "${KEEP_DAYS}" \
  --prune \
  2>&1 | tee -a "${LOG}"; then
  log "[OK] Prune complete"
else
  log "[WARN] Prune failed"
fi

log "=== Moodboard restic backup done ==="