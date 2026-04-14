#!/usr/bin/env bash
# restic-init.sh — Initialize 4 restic repositories on Drive
# Idempotent: safe to run if repos already exist
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

REPOS=(
  "gdrive_capsule:twenty-bak"
  "gdrive_capsule:memos-bak"
  "gdrive_capsule:vikunja-bak"
  "gdrive_capsule:moodboard-bak"
)

LOG="/var/log/restic-init.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

for repo in "${REPOS[@]}"; do
  log "Initializing ${repo}..."
  if restic init --repo "${repo}" 2>&1 | tee -a "${LOG}"; then
    log "[OK] ${repo} initialized"
  else
    # Probably already exists (exit code 0 but "repository already exists")
    log "[WARN] ${repo} may already exist (continuing)"
  fi
done

log "All repos initialized."
