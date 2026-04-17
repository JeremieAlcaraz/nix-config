#!/usr/bin/env bash
# restic-restore.sh — interactive restore via gum picker
# Usage: bash /root/apps/restic/restic-restore.sh
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

declare -A APPS=(
  [memos]="rclone:gdrive_capsule:memos|/root/apps/memos/data|/root/apps/memos"
  [vikunja]="rclone:gdrive_capsule:vikunja|/root/apps/vikunja/data|/root/apps/vikunja"
  [moodboard]="rclone:gdrive_capsule:moodboard|/root/apps/moodboard|/root/apps/moodboard"
  [twenty]="rclone:gdrive_capsule:twenty|/var/lib/containers/storage/volumes|/root/apps/twenty"
)

declare -A SERVICE=(
  [memos]="memos.service"
  [vikunja]="vikunja.service"
  [moodboard]="moodboard.service"
  [twenty]="twenty.service"
)

LOG="/var/log/restic-restore.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

# ── Step 1: pick app ──────────────────────────────────────
APP="$(printf '%s\n' memos vikunja moodboard twenty | gum choose --header "Which app to restore?")"
[[ -z "${APP}" ]] && echo "Cancelled." && exit 0

SVC="${SERVICE[$APP]}"
REPO="${APPS[$APP]%%|*}"
SOURCE_PATH="${APPS[$APP]#*|}"; SOURCE_PATH="${SOURCE_PATH%%|*}"
TARGET_PATH="${APPS[$APP]##*|}"

# ── Step 2: list snapshots (with rate-limit fallback) ────
SNAPSHOTS_RAW=$(timeout 180 restic snapshots --repo "${REPO}" --json 2>/dev/null)

if [[ -z "${SNAPSHOTS_RAW}" ]]; then
  # Fallback: non-JSON output (slower but rate-limit resistant)
  echo "[INFO] Rate limit hit — using fallback listing..."
  SNAPSHOTS=$(timeout 180 restic snapshots --repo "${REPO}" 2>/dev/null | \
    grep -E "^[a-f0-9]{12}" | \
    awk '{print $1" | "$2" | "$4" | "$5}')
else
  # JSON parsing
  SNAPSHOTS=$(echo "${SNAPSHOTS_RAW}" | python3 -c "
import sys, json
for s in json.load(sys.stdin):
    ts = s['time'][:19]
    sid = s['id'][:12]
    size = s.get('data_size', '?')
    tags = ','.join(s.get('tags',[])) or '-'
    print(f'{sid} | {ts} | {size} | {tags}')
" 2>/dev/null) || true
fi

if [[ -z "${SNAPSHOTS}" ]]; then
  log "[ERROR] No snapshots found (or rate limit blocking access)"
  log "[HINT] Wait a few minutes and retry, or check 'just poppy-restic-status'"
  exit 1
fi

# Reverse (most recent first)
SNAPSHOTS=$(echo "${SNAPSHOTS}" | sort -r)

echo ""
echo "=== Available snapshots ==="
echo "${SNAPSHOTS}"
echo ""

SELECTED=$(echo "${SNAPSHOTS}" | gum table | awk '{print $1}')
[[ -z "${SELECTED}" ]] && echo "Cancelled." && exit 0

# ── Step 3: confirm ──────────────────────────────────────
gum confirm "Restore ${APP} snapshot ${SELECTED} to ${TARGET_PATH}?
This will STOP the service first. Continue?" \
  || { echo "Cancelled."; exit 0; }

log "=== Restoring ${APP} snapshot ${SELECTED} ==="

# ── Step 4: stop service ─────────────────────────────────
if systemctl is-active -q "${SVC}"; then
  log "Stopping ${SVC}..."
  systemctl stop "${SVC}" || true
  sleep 3
fi

# ── Step 5: restore to temp ───────────────────────────────
RESTORE_DIR="/tmp/restic-restore-${APP}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${RESTORE_DIR}"

log "Restoring to ${RESTORE_DIR}..."
if timeout 600 restic restore "${SELECTED}" \
  --repo "${REPO}" \
  --target "${RESTORE_DIR}" \
  2>&1 | tee -a "${LOG}"; then
  log "[OK] Restore complete"
else
  log "[ERROR] Restore failed"
  exit 1
fi

# ── Step 6: resolve restored paths ─────────────────────────
RESTORED_ROOT=""
if [[ "${APP}" == "twenty" ]]; then
  RESTORED_DB="$(find "${RESTORE_DIR}" -type d -path "*twenty_twenty-db-data/_data" | head -n1 || true)"
  RESTORED_SERVER="$(find "${RESTORE_DIR}" -type d -path "*twenty_twenty-server-data/_data" | head -n1 || true)"
  if [[ -z "${RESTORED_DB}" || -z "${RESTORED_SERVER}" ]]; then
    log "[ERROR] Could not resolve Twenty restored volume paths"
    exit 1
  fi
else
  if [[ -d "${RESTORE_DIR}${SOURCE_PATH}" ]]; then
    RESTORED_ROOT="${RESTORE_DIR}${SOURCE_PATH}"
  else
    RESTORED_ROOT="$(find "${RESTORE_DIR}" -type d -path "*${SOURCE_PATH}" | head -n1 || true)"
  fi
  if [[ -z "${RESTORED_ROOT}" ]]; then
    log "[ERROR] Could not resolve restored path for ${APP} (${SOURCE_PATH})"
    exit 1
  fi
fi

# ── Step 7: preview ───────────────────────────────────────
echo ""
echo "=== Files restored (preview) ==="
if [[ "${APP}" == "twenty" ]]; then
  du -sh "${RESTORED_DB}" "${RESTORED_SERVER}" 2>/dev/null || true
else
  du -sh "${RESTORED_ROOT}" 2>/dev/null || true
fi
echo ""

# Guardrail moodboard: reject obviously incomplete snapshot (e.g. config-only)
if [[ "${APP}" == "moodboard" ]]; then
  for required in package.json bun.lock src server/prod.ts; do
    if [[ ! -e "${RESTORED_ROOT}/${required}" ]]; then
      log "[ERROR] Moodboard snapshot seems incomplete: missing ${required}"
      log "[HINT] Choose an older snapshot from before config-only capture"
      exit 1
    fi
  done
fi

gum confirm "Copy restored files to ${TARGET_PATH}? (will overwrite!)" \
  || { log "Cancelled copy. Files left in ${RESTORE_DIR}"; exit 0; }

log "Copying to ${TARGET_PATH}..."
if [[ "${APP}" == "twenty" ]]; then
  DB_PATH="$(podman volume inspect twenty_twenty-db-data --format '{{.Mountpoint}}' 2>/dev/null || true)"
  SERVER_PATH="$(podman volume inspect twenty_twenty-server-data --format '{{.Mountpoint}}' 2>/dev/null || true)"
  if [[ -z "${DB_PATH}" || -z "${SERVER_PATH}" ]]; then
    log "[ERROR] Could not resolve live Twenty volume mountpoints"
    exit 1
  fi
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${RESTORED_DB}/" "${DB_PATH}/"
    rsync -a --delete "${RESTORED_SERVER}/" "${SERVER_PATH}/"
  else
    find "${DB_PATH}" -mindepth 1 -delete
    find "${SERVER_PATH}" -mindepth 1 -delete
    cp -a "${RESTORED_DB}/." "${DB_PATH}/"
    cp -a "${RESTORED_SERVER}/." "${SERVER_PATH}/"
  fi
elif [[ "${APP}" == "moodboard" ]]; then
  # keep immutable managed files in place; restore app payload only
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude='compose.yml' \
      --exclude='Containerfile' \
      --exclude='.env' \
      --exclude='.env.prod' \
      "${RESTORED_ROOT}/" "${TARGET_PATH}/"
  else
    cp -a "${RESTORED_ROOT}/." "${TARGET_PATH}/"
  fi
  # runtime hardening: build expects this file
  if [[ ! -f "${TARGET_PATH}/infra/garage/garage.toml" && -f "/root/apps/garage/garage-prod.toml" ]]; then
    mkdir -p "${TARGET_PATH}/infra/garage"
    cp -f /root/apps/garage/garage-prod.toml "${TARGET_PATH}/infra/garage/garage.toml"
    log "[OK] Injected ${TARGET_PATH}/infra/garage/garage.toml from garage-prod.toml"
  fi
else
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${RESTORED_ROOT}/" "${TARGET_PATH}/"
  else
    find "${TARGET_PATH}" -mindepth 1 -delete
    cp -a "${RESTORED_ROOT}/." "${TARGET_PATH}/"
  fi
fi
log "[OK] Files copied to ${TARGET_PATH}"

# ── Step 8: restart service ─────────────────────────────
log "Restarting ${SVC}..."
systemctl start "${SVC}" || true
sleep 5

if systemctl is-active -q "${SVC}"; then
  log "[OK] ${SVC} is running"
else
  log "[WARN] ${SVC} may not have started — check manually"
fi

# ── Step 9: cleanup ─────────────────────────────────────
rm -rf "${RESTORE_DIR}"
log "=== Restore complete ==="
echo ""
echo "Check logs: tail -f /var/log/restic-restore.log"
