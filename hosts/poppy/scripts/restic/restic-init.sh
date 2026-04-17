#!/usr/bin/env bash
# restic-init.sh — Initialize 4 restic repositories on Drive
# Idempotent: safe to run if repos already exist
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

LOG="/var/log/restic-init.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

for repo in "${REPOS[@]}"; do
  log "Initializing ${repo}..."
  if restic init --repo "${repo}" 2>&1 | tee -a "${LOG}"; then
    log "[OK] ${repo} initialized"
  else
    log "[WARN] init failed for ${repo} (already exists or config issue), continuing"
  fi
done

log "All repos initialized."
