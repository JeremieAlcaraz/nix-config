#!/usr/bin/env bash
# garage-restic-backup.sh — backup Garage object storage data via restic
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:garage"
SOURCE="/root/apps/garage/data"
LOG="/var/log/garage-restic-backup.log"
KEEP_DAYS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Garage restic backup started ==="

if [[ ! -d "${SOURCE}" ]]; then
  log "[ERROR] Source path not found: ${SOURCE}"
  exit 1
fi

if restic backup "${SOURCE}" \
  --repo "${REPO}" \
  --host poppy \
  --tag garage \
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

log "=== Garage restic backup done ==="
