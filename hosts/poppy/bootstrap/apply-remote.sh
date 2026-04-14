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

# Backup scripts
MEMOS_BACKUP_STAGE="${STAGE_DIR}/memos-backup.sh"
MEMOS_UPLOAD_STAGE="${STAGE_DIR}/memos-upload-backups.sh"
VIKUNJA_BACKUP_STAGE="${STAGE_DIR}/vikunja-backup.sh"
VIKUNJA_UPLOAD_STAGE="${STAGE_DIR}/vikunja-upload-backups.sh"
MOODBOARD_BACKUP_STAGE="${STAGE_DIR}/moodboard-backup.sh"

# Systemd backup units
MEMOS_BACKUP_SERVICE_STAGE="${STAGE_DIR}/memos-backup.service"
MEMOS_BACKUP_TIMER_STAGE="${STAGE_DIR}/memos-backup.timer"

# App compose
MEMOS_COMPOSE_STAGE="${STAGE_DIR}/memos-compose.yml"
VIKUNJA_COMPOSE_STAGE="${STAGE_DIR}/vikunja-compose.yml"
MOODBOARD_COMPOSE_STAGE="${STAGE_DIR}/moodboard-compose.yml"

# App .env (generated from template + secrets)
VIKUNJA_ENV_STAGE="${STAGE_DIR}/vikunja.env"
MOODBOARD_ENV_STAGE="${STAGE_DIR}/moodboard.env"

# App systemd units
MEMOS_SERVICE_STAGE="${STAGE_DIR}/memos.service"
VIKUNJA_SERVICE_STAGE="${STAGE_DIR}/vikunja.service"

# ── Target paths ─────────────────────────────────────────
TARGET_RCLONE_CONF="/root/.config/rclone/rclone.conf"
TARGET_SYNC_SCRIPT="/root/sync-capsule.sh"
TARGET_MEMOS_BACKUP="/root/apps/memos/scripts/backup.sh"
TARGET_MEMOS_UPLOAD="/root/apps/memos/scripts/upload-backups.sh"
TARGET_MEMOS_SERVICE="/etc/systemd/system/memos-backup.service"
TARGET_MEMOS_TIMER="/etc/systemd/system/memos-backup.timer"
TARGET_VIKUNJA_BACKUP="/root/apps/vikunja/scripts/backup.sh"
TARGET_VIKUNJA_UPLOAD="/root/apps/vikunja/scripts/upload-backups.sh"
TARGET_MOODBOARD_BACKUP_A="/root/apps/moodboard/backup-moodboard.sh"
TARGET_MOODBOARD_BACKUP_B="/root/apps/moodboard/scripts/backup-moodboard.sh"
TARGET_MEMOS_COMPOSE="/root/apps/memos/compose.yml"
TARGET_VIKUNJA_COMPOSE="/root/apps/vikunja/compose.yml"
TARGET_MOODBOARD_COMPOSE="/root/apps/moodboard/compose.yml"
TARGET_VIKUNJA_ENV="/root/apps/vikunja/.env"
TARGET_MOODBOARD_ENV="/root/apps/moodboard/.env.prod"
TARGET_MEMOS_SVC="/etc/systemd/system/memos.service"
TARGET_VIKUNJA_SVC="/etc/systemd/system/vikunja.service"

NODE_EXPORTER_PKG="prometheus-node-exporter"
NODE_EXPORTER_SERVICE="prometheus-node-exporter"
SQLITE_PKG="sqlite3"

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

# Backup scripts + systemd backup
require_file "${RCLONE_CONF_STAGE}"
require_file "${SYNC_SCRIPT_STAGE}"
require_file "${CRON_LINE_STAGE}"
require_file "${MEMOS_BACKUP_STAGE}"
require_file "${MEMOS_UPLOAD_STAGE}"
require_file "${VIKUNJA_BACKUP_STAGE}"
require_file "${VIKUNJA_UPLOAD_STAGE}"
require_file "${MOODBOARD_BACKUP_STAGE}"
require_file "${MEMOS_BACKUP_SERVICE_STAGE}"
require_file "${MEMOS_BACKUP_TIMER_STAGE}"

# App stacks
require_file "${MEMOS_COMPOSE_STAGE}"
require_file "${VIKUNJA_COMPOSE_STAGE}"
require_file "${MOODBOARD_COMPOSE_STAGE}"
require_file "${VIKUNJA_ENV_STAGE}"
require_file "${MOODBOARD_ENV_STAGE}"
require_file "${MEMOS_SERVICE_STAGE}"
require_file "${VIKUNJA_SERVICE_STAGE}"

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
ensure_pkg_installed "${SQLITE_PKG}"
ensure_service_enabled_active "${NODE_EXPORTER_SERVICE}"

mkdir -p /root/.config/rclone
chmod 700 /root/.config/rclone

# All app dirs
run mkdir -p \
  /root/apps/memos/scripts \
  /root/apps/vikunja/scripts \
  /root/apps/moodboard/scripts \
  /root/apps/memos \
  /root/apps/vikunja \
  /root/apps/moodboard

# ── Backup existing files ─────────────────────────────────
ts="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${TARGET_RCLONE_CONF}" ]]; then
  run cp "${TARGET_RCLONE_CONF}" "${TARGET_RCLONE_CONF}.bak-${ts}"
fi
if [[ -f "${TARGET_SYNC_SCRIPT}" ]]; then
  run cp "${TARGET_SYNC_SCRIPT}" "${TARGET_SYNC_SCRIPT}.bak-${ts}"
fi
for f in \
  "${TARGET_MEMOS_BACKUP}" "${TARGET_MEMOS_UPLOAD}" \
  "${TARGET_VIKUNJA_BACKUP}" "${TARGET_VIKUNJA_UPLOAD}" \
  "${TARGET_MOODBOARD_BACKUP_A}" "${TARGET_MOODBOARD_BACKUP_B}" \
  "${TARGET_MEMOS_SERVICE}" "${TARGET_MEMOS_TIMER}" \
  "${TARGET_MEMOS_COMPOSE}" "${TARGET_VIKUNJA_COMPOSE}" \
  "${TARGET_MOODBOARD_COMPOSE}" "${TARGET_VIKUNJA_ENV}" \
  "${TARGET_MOODBOARD_ENV}" "${TARGET_MEMOS_SVC}" "${TARGET_VIKUNJA_SVC}"; do
  if [[ -f "${f}" ]]; then
    run cp "${f}" "${f}.bak-${ts}"
  fi
done

# ── Install files ─────────────────────────────────────────
run install -m 600 "${RCLONE_CONF_STAGE}" "${TARGET_RCLONE_CONF}"
run install -m 700 "${SYNC_SCRIPT_STAGE}" "${TARGET_SYNC_SCRIPT}"

# Backup scripts
run install -m 700 "${MEMOS_BACKUP_STAGE}" "${TARGET_MEMOS_BACKUP}"
run install -m 700 "${MEMOS_UPLOAD_STAGE}" "${TARGET_MEMOS_UPLOAD}"
run install -m 700 "${VIKUNJA_BACKUP_STAGE}" "${TARGET_VIKUNJA_BACKUP}"
run install -m 700 "${VIKUNJA_UPLOAD_STAGE}" "${TARGET_VIKUNJA_UPLOAD}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_A}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_B}"

# Systemd backup units
run install -m 644 "${MEMOS_BACKUP_SERVICE_STAGE}" "${TARGET_MEMOS_SERVICE}"
run install -m 644 "${MEMOS_BACKUP_TIMER_STAGE}" "${TARGET_MEMOS_TIMER}"

# App compose files
run install -m 644 "${MEMOS_COMPOSE_STAGE}" "${TARGET_MEMOS_COMPOSE}"
run install -m 644 "${VIKUNJA_COMPOSE_STAGE}" "${TARGET_VIKUNJA_COMPOSE}"
run install -m 644 "${MOODBOARD_COMPOSE_STAGE}" "${TARGET_MOODBOARD_COMPOSE}"

# App .env (from SOPS)
run install -m 600 "${VIKUNJA_ENV_STAGE}" "${TARGET_VIKUNJA_ENV}"
run install -m 600 "${MOODBOARD_ENV_STAGE}" "${TARGET_MOODBOARD_ENV}"

# App systemd units
run install -m 644 "${MEMOS_SERVICE_STAGE}" "${TARGET_MEMOS_SVC}"
run install -m 644 "${VIKUNJA_SERVICE_STAGE}" "${TARGET_VIKUNJA_SVC}"

# ── Cron ──────────────────────────────────────────────────
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

# ── Systemd reload + enable ────────────────────────────────
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: systemctl daemon-reload"
  echo "[DRY-RUN] would run: systemctl enable --now memos-backup.timer"
  echo "[DRY-RUN] would run: systemctl enable --now memos.service"
  echo "[DRY-RUN] would run: systemctl enable --now vikunja.service"
else
  systemctl daemon-reload
  systemctl enable --now memos-backup.timer >/dev/null
  # App units — enable only, don't restart running ones unless needed
  systemctl enable memos.service 2>/dev/null || true
  systemctl enable vikunja.service 2>/dev/null || true
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: rclone listremotes"
else
  rclone listremotes >/dev/null
fi

echo "[INFO] apply-remote completed (dry_run=${DRY_RUN})"