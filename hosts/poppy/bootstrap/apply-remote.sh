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
MEMOS_BACKUP_STAGE="${STAGE_DIR}/memos-backup.sh"
VIKUNJA_BACKUP_STAGE="${STAGE_DIR}/vikunja-backup.sh"
VIKUNJA_UPLOAD_STAGE="${STAGE_DIR}/vikunja-upload-backups.sh"
MOODBOARD_BACKUP_STAGE="${STAGE_DIR}/moodboard-backup.sh"

TARGET_RCLONE_CONF="/root/.config/rclone/rclone.conf"
TARGET_SYNC_SCRIPT="/root/sync-capsule.sh"
TARGET_MEMOS_BACKUP="/root/apps/memos/scripts/backup.sh"
TARGET_VIKUNJA_BACKUP="/root/apps/vikunja/scripts/backup.sh"
TARGET_VIKUNJA_UPLOAD="/root/apps/vikunja/scripts/upload-backups.sh"
TARGET_MOODBOARD_BACKUP_A="/root/apps/moodboard/backup-moodboard.sh"
TARGET_MOODBOARD_BACKUP_B="/root/apps/moodboard/scripts/backup-moodboard.sh"
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
require_file "${MEMOS_BACKUP_STAGE}"
require_file "${VIKUNJA_BACKUP_STAGE}"
require_file "${VIKUNJA_UPLOAD_STAGE}"
require_file "${MOODBOARD_BACKUP_STAGE}"

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
run mkdir -p /root/apps/memos/scripts /root/apps/vikunja/scripts /root/apps/moodboard/scripts

ts="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${TARGET_RCLONE_CONF}" ]]; then
  run cp "${TARGET_RCLONE_CONF}" "${TARGET_RCLONE_CONF}.bak-${ts}"
fi
if [[ -f "${TARGET_SYNC_SCRIPT}" ]]; then
  run cp "${TARGET_SYNC_SCRIPT}" "${TARGET_SYNC_SCRIPT}.bak-${ts}"
fi
for f in "${TARGET_MEMOS_BACKUP}" "${TARGET_VIKUNJA_BACKUP}" "${TARGET_VIKUNJA_UPLOAD}" "${TARGET_MOODBOARD_BACKUP_A}" "${TARGET_MOODBOARD_BACKUP_B}"; do
  if [[ -f "${f}" ]]; then
    run cp "${f}" "${f}.bak-${ts}"
  fi
done

run install -m 600 "${RCLONE_CONF_STAGE}" "${TARGET_RCLONE_CONF}"
run install -m 700 "${SYNC_SCRIPT_STAGE}" "${TARGET_SYNC_SCRIPT}"
run install -m 700 "${MEMOS_BACKUP_STAGE}" "${TARGET_MEMOS_BACKUP}"
run install -m 700 "${VIKUNJA_BACKUP_STAGE}" "${TARGET_VIKUNJA_BACKUP}"
run install -m 700 "${VIKUNJA_UPLOAD_STAGE}" "${TARGET_VIKUNJA_UPLOAD}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_A}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_B}"

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
