#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

STAGE_DIR="${STAGE_DIR:-/tmp/poppy-bootstrap}"
RCLONE_CONF_STAGE="${STAGE_DIR}/rclone.conf"
SYNC_SCRIPT_STAGE="${STAGE_DIR}/sync-capsule.sh"
CRON_LINE_STAGE="${STAGE_DIR}/cron-line.txt"

TARGET_RCLONE_CONF="/root/.config/rclone/rclone.conf"
TARGET_SYNC_SCRIPT="/root/sync-capsule.sh"
NODE_EXPORTER_PKG="prometheus-node-exporter"
NODE_EXPORTER_SERVICE="prometheus-node-exporter"

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

require_file() {
  local f="$1"
  [[ -f "${f}" ]] || { echo "[ERROR] missing file: ${f}"; exit 1; }
}

require_file "${RCLONE_CONF_STAGE}"
require_file "${SYNC_SCRIPT_STAGE}"
require_file "${CRON_LINE_STAGE}"

ensure_pkg_installed() {
  local pkg="$1"
  if dpkg -s "${pkg}" >/dev/null 2>&1; then
    echo "[INFO] package already installed: ${pkg}"
    return 0
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] would run: apt-get update -qq && apt-get install -y ${pkg}"
    return 0
  fi
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkg}"
}

ensure_service_enabled_active() {
  local svc="$1"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] would run: systemctl enable --now ${svc}"
    return 0
  fi
  systemctl enable --now "${svc}" >/dev/null
}

ensure_pkg_installed "${NODE_EXPORTER_PKG}"
ensure_service_enabled_active "${NODE_EXPORTER_SERVICE}"

mkdir -p /root/.config/rclone
chmod 700 /root/.config/rclone

ts="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${TARGET_RCLONE_CONF}" ]]; then
  run cp "${TARGET_RCLONE_CONF}" "${TARGET_RCLONE_CONF}.bak-${ts}"
fi
if [[ -f "${TARGET_SYNC_SCRIPT}" ]]; then
  run cp "${TARGET_SYNC_SCRIPT}" "${TARGET_SYNC_SCRIPT}.bak-${ts}"
fi

run install -m 600 "${RCLONE_CONF_STAGE}" "${TARGET_RCLONE_CONF}"
run install -m 700 "${SYNC_SCRIPT_STAGE}" "${TARGET_SYNC_SCRIPT}"

CRON_LINE="$(cat "${CRON_LINE_STAGE}")"

CURRENT_CRON="$(mktemp)"
NEW_CRON="$(mktemp)"
trap 'rm -f "${CURRENT_CRON}" "${NEW_CRON}"' EXIT

crontab -l 2>/dev/null > "${CURRENT_CRON}" || true
grep -v "/root/sync-capsule.sh" "${CURRENT_CRON}" > "${NEW_CRON}" || true
printf "%s\n" "${CRON_LINE}" >> "${NEW_CRON}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would install cron line:"
  echo "${CRON_LINE}"
else
  crontab "${NEW_CRON}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: rclone listremotes"
else
  rclone listremotes >/dev/null
fi

echo "[INFO] apply-remote completed (dry_run=${DRY_RUN})"
