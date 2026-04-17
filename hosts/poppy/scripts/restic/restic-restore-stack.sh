#!/usr/bin/env bash
# restic-restore-stack.sh — restore orchestration with garage-first for S3-dependent apps
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

LOG="/var/log/restic-restore-stack.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

APP="${1:-}"
if [[ -z "${APP}" ]]; then
  APP="$(printf '%s\n' memos moodboard twenty vikunja | gum choose --header 'Restore stack for which app?')"
fi
[[ -z "${APP}" ]] && echo "Cancelled." && exit 0

case "${APP}" in
  memos|moodboard|twenty) NEED_GARAGE=1 ;;
  vikunja) NEED_GARAGE=0 ;;
  *) echo "Unsupported app: ${APP}" >&2; exit 1 ;;
esac

restore_from_repo() {
  local label="$1"
  local repo="$2"
  local target="$3"

  local snapshots raw selected
  raw="$(timeout 180 restic snapshots --repo "${repo}" --json 2>/dev/null || true)"
  if [[ -n "${raw}" ]]; then
    snapshots="$(echo "${raw}" | python3 -c '
import sys, json
for s in json.load(sys.stdin):
  sid = s.get("id","")[:12]
  st = s.get("time","")[:19]
  sz = s.get("data_size","?")
  print(f"{sid} | {st} | {sz}")
' 2>/dev/null || true)"
  else
    snapshots="$(timeout 180 restic snapshots --repo "${repo}" 2>/dev/null | grep -E '^[a-f0-9]{8,12}' | awk '{print $1" | "$2" | "$NF}' || true)"
  fi

  if [[ -z "${snapshots}" ]]; then
    log "[ERROR] No snapshot found for ${label} (${repo})"
    return 1
  fi

  snapshots="$(echo "${snapshots}" | sort -r)"
  echo ""
  echo "=== ${label} snapshots (${repo}) ==="
  echo "${snapshots}"
  echo ""

  selected="$(echo "${snapshots}" | gum table | awk '{print $1}')"
  [[ -z "${selected}" ]] && return 1

  local restore_dir
  restore_dir="/tmp/restic-restore-${label}-$(date +%Y%m%d%H%M%S)"
  mkdir -p "${restore_dir}"

  log "Restoring ${label} snapshot ${selected} into ${restore_dir}"
  timeout 900 restic restore "${selected}" --repo "${repo}" --target "${restore_dir}" 2>&1 | tee -a "${LOG}"

  gum confirm "Copy ${label} restored files to ${target}? (overwrite)" || {
    log "[WARN] Copy cancelled for ${label}, kept at ${restore_dir}"
    return 1
  }

  mkdir -p "${target}"
  cp -a "${restore_dir}"/* "${target}/" 2>/dev/null || true
  rm -rf "${restore_dir}"
  log "[OK] ${label} copied to ${target}"
}

if [[ "${NEED_GARAGE}" -eq 1 ]]; then
  gum confirm "${APP} depends on Garage S3. Restore Garage first?" || {
    log "[WARN] garage-first skipped by operator"
  }
  if gum confirm "Proceed with Garage restore now?"; then
    restore_from_repo "garage" "rclone:gdrive_capsule:garage" "/root/apps/garage/data"
  fi
fi

log "Launching app restore flow for ${APP}"
bash /root/apps/restic/restic-restore.sh
log "Done. Verify app health manually and check ${LOG}."
