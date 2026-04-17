#!/usr/bin/env bash
# restic-prune.sh — prune all repos (keep 7 days)
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPOS=(
  "rclone:gdrive_capsule:garage"
  "rclone:gdrive_capsule:twenty"
  "rclone:gdrive_capsule:memos"
  "rclone:gdrive_capsule:vikunja"
  "rclone:gdrive_capsule:moodboard"
)
KEEP_DAYS=7
LOG="/var/log/restic-prune.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Restic prune started ==="

for repo in "${REPOS[@]}"; do
  repo_name="${repo##*:}"
  log "Pruning ${repo_name}..."
  if restic forget \
    --repo "${repo}" \
    --keep-daily "${KEEP_DAYS}" \
    --prune \
    2>&1 | tee -a "${LOG}"; then
    log "[OK] ${repo_name} pruned"
  else
    log "[WARN] ${repo_name} prune failed"
  fi
done

log "=== Restic prune done ==="