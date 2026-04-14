#!/usr/bin/env bash
# memos-restic-backup.sh — backup memos via restic (versioned snapshots)
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:memos-bak"
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

# Prune old snapshots (keep 7 days)
if restic forget \
  --repo "${REPO}" \
  --keep-daily "${KEEP_DAYS}" \
  --prune \
  2>&1 | tee -a "${LOG}"; then
  log "[OK] Prune complete (keep ${KEEP_DAYS} days)"
else
  log "[WARN] Prune failed (continuing)"
fi

# Check repo stats
restic stats --repo "${REPO}" --mode raw-data 2>&1 | tee -a "${LOG}" || true

log "=== Memos restic backup done ==="