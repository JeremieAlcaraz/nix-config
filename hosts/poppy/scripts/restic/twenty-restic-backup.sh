#!/usr/bin/env bash
# twenty-restic-backup.sh — backup twenty via restic
# Backs up podman volumes (DB + server local storage)
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPO="rclone:gdrive_capsule:twenty-bak"
LOG="/var/log/twenty-restic-backup.log"
KEEP_DAYS=7

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

get_volume_mountpoint() {
  local vol="$1"
  podman volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null
}

log "=== Twenty restic backup started ==="

# Get volume mountpoints
DB_VOL="twenty_twenty-db-data"
SERVER_VOL="twenty_twenty-server-data"
DB_PATH="$(get_volume_mountpoint "${DB_VOL}")"
SERVER_PATH="$(get_volume_mountpoint "${SERVER_VOL}")"

if [[ -z "${DB_PATH}" ]] || [[ -z "${SERVER_PATH}" ]]; then
  log "[ERROR] Could not get volume mountpoints (volumes may not exist)"
  exit 1
fi

log "Backing up DB: ${DB_PATH}"
log "Backing up Server: ${SERVER_PATH}"

if restic backup "${DB_PATH}" "${SERVER_PATH}" \
  --repo "${REPO}" \
  --host poppy \
  --tag twenty \
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

log "=== Twenty restic backup done ==="