#!/usr/bin/env bash
# vikunja-restic-backup.sh — backup vikunja via restic
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:vikunja-bak"
SOURCE="/root/apps/vikunja/data"
LOG="/var/log/vikunja-restic-backup.log"
KEEP_DAYS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Vikunja restic backup started ==="

if restic backup "${SOURCE}" \
  --repo "${REPO}" \
  --host poppy \
  --tag vikunja \
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

log "=== Vikunja restic backup done ==="