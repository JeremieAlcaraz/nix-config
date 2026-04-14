#!/usr/bin/env bash
# restic-restore.sh — interactive restore via gum picker
# Usage: bash /root/apps/restic/restic-restore.sh
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

declare -A APPS=(
  ["memos"]="rclone:gdrive_capsule:memos-bak|/root/apps/memos/data|/root/apps/memos"
  ["vikunja"]="rclone:gdrive_capsule:vikunja-bak|/root/apps/vikunja/data|/root/apps/vikunja"
  ["moodboard"]="rclone:gdrive_capsule:moodboard-bak|/root/apps/moodboard|/root/apps/moodboard"
  ["twenty"]="rclone:gdrive_capsule:twenty-bak|/var/lib/containers/storage/volumes|/root/apps/twenty"
)

declare -A SERVICE=(
  ["memos"]="memos.service"
  ["vikunja"]="vikunja.service"
  ["moodboard"]="moodboard.service"
  ["twenty"]="twenty.service"
)

SVC="${SERVICE[$APP]}"

# ── Step 1: pick app ──────────────────────────────────────
APP="$(echo -e "memos\nvikunja\moodboard\ntwenty" | gum choose --header "Which app to restore?")"
[[ -z "${APP}" ]] && echo "Cancelled." && exit 0

REPO="${APPS[$APP]%%|*}"
SOURCE_PATH="${APPS[$APP]#*|}"; SOURCE_PATH="${SOURCE_PATH%%|*}"
TARGET_PATH="${APPS[$APP]##*|}"

LOG="/var/log/restic-restore.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

# ── Step 2: list snapshots ────────────────────────────────
SNAPSHOTS=$(timeout 120 restic snapshots --repo "${REPO}" --json 2>/dev/null | \
  python3 -c "
import sys, json
for s in json.load(sys.stdin):
    ts = s['time'][:19]
    sid = s['id'][:12]
    size = s['data_size']
    tags = ','.join(s.get('tags',[])) or '-'
    print(f\"{sid} | {ts} | {size} | {tags}\")
" 2>/dev/null)

[[ -z "${SNAPSHOTS}" ]] && log "[ERROR] No snapshots found for ${APP}" && exit 1

# Reverse (most recent first)
SNAPSHOTS=$(echo "${SNAPSHOTS}" | sort -r)

SELECTED=$(echo "${SNAPSHOTS}" | gum table --header "ID | Time | Size | Tags" | awk '{print $1}')
[[ -z "${SELECTED}" ]] && echo "Cancelled." && exit 0

# ── Step 3: confirm ──────────────────────────────────────
gum confirm "Restore **${APP}** snapshot \`${SELECTED}\` to ${TARGET_PATH}?
This will STOP the service first. Continue?" \
  || { echo "Cancelled."; exit 0; }

log "=== Restoring ${APP} snapshot ${SELECTED} ==="

# ── Step 4: stop service ─────────────────────────────────
SYSTEMD_SVC="${SERVICE[$APP]}"
if systemctl is-active -q "${SYSTEMD_SVC}"; then
  log "Stopping ${SYSTEMD_SVC}..."
  systemctl stop "${SYSTEMD_SVC}" || true
  sleep 3
fi

# ── Step 5: restore to temp ───────────────────────────────
RESTORE_DIR="/tmp/restic-restore-${APP}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${RESTORE_DIR}"

log "Restoring to ${RESTORE_DIR}..."
if timeout 300 restic restore "${SELECTED}" \
  --repo "${REPO}" \
  --target "${RESTORE_DIR}" \
  2>&1 | tee -a "${LOG}"; then
  log "[OK] Restore complete"
else
  log "[ERROR] Restore failed"
  exit 1
fi

# ── Step 6: list what changed ──────────────────────────────
echo ""
echo "=== Files to be restored ==="
du -sh "${RESTORE_DIR}"/* 2>/dev/null | sort -rh | head -20
echo ""

# ── Step 7: copy to target ───────────────────────────────
gum confirm "Copy restored files to ${TARGET_PATH}? (will overwrite!)" \
  || { log "Cancelled copy. Files left in ${RESTORE_DIR}"; exit 0; }

log "Copying to ${TARGET_PATH}..."
if [[ "${APP}" == "twenty" ]]; then
  # Twenty: restore volumes only
  for vol_dir in "${RESTORE_DIR}"/*/; do
    vol_name=$(basename "${vol_dir}")
    cp -r "${vol_dir}"* "${TARGET_PATH}/${vol_name}/" 2>/dev/null || true
  done
else
  cp -r "${RESTORE_DIR}"/* "${TARGET_PATH}/" 2>/dev/null || true
fi
log "[OK] Files copied to ${TARGET_PATH}"

# ── Step 8: restart service ─────────────────────────────
log "Restarting ${SYSTEMD_SVC}..."
systemctl start "${SYSTEMD_SVC}" || true
sleep 5

if systemctl is-active -q "${SYSTEMD_SVC}"; then
  log "[OK] ${SYSTEMD_SVC} is running"
else
  log "[WARN] ${SYSTEMD_SVC} may not have started — check manually"
fi

# ── Step 9: cleanup ─────────────────────────────────────
rm -rf "${RESTORE_DIR}"
log "=== Restore complete ==="
echo ""
echo "Check logs: tail -f /var/log/restic-restore.log"