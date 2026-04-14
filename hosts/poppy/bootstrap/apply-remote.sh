#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

STAGE_DIR="${STAGE_DIR:-/var/lib/poppy-deploy}"

# Stage files
RCLONE_CONF_STAGE="${STAGE_DIR}/rclone.conf"
SYNC_SCRIPT_STAGE="${STAGE_DIR}/sync-capsule.sh"
CRON_LINE_STAGE="${STAGE_DIR}/cron-line.txt"

MEMOS_BACKUP_STAGE="${STAGE_DIR}/memos-backup.sh"
MEMOS_UPLOAD_STAGE="${STAGE_DIR}/memos-upload-backups.sh"
VIKUNJA_BACKUP_STAGE="${STAGE_DIR}/vikunja-backup.sh"
VIKUNJA_UPLOAD_STAGE="${STAGE_DIR}/vikunja-upload-backups.sh"
MOODBOARD_BACKUP_STAGE="${STAGE_DIR}/moodboard-backup.sh"

MEMOS_BACKUP_SERVICE_STAGE="${STAGE_DIR}/memos-backup.service"
MEMOS_BACKUP_TIMER_STAGE="${STAGE_DIR}/memos-backup.timer"

MEMOS_COMPOSE_STAGE="${STAGE_DIR}/memos-compose.yml"
VIKUNJA_COMPOSE_STAGE="${STAGE_DIR}/vikunja-compose.yml"
MOODBOARD_COMPOSE_STAGE="${STAGE_DIR}/moodboard-compose.yml"
MOODBOARD_CONTAINERFILE_STAGE="${STAGE_DIR}/moodboard-Containerfile"
VIKUNJA_ENV_STAGE="${STAGE_DIR}/vikunja.env"
MOODBOARD_ENV_STAGE="${STAGE_DIR}/moodboard.env"

MEMOS_SERVICE_STAGE="${STAGE_DIR}/memos.service"
VIKUNJA_SERVICE_STAGE="${STAGE_DIR}/vikunja.service"
MOODBOARD_SERVICE_STAGE="${STAGE_DIR}/moodboard.service"

GARAGE_COMPOSE_STAGE="${STAGE_DIR}/garage-compose.yml"
GARAGE_CONFIG_STAGE="${STAGE_DIR}/garage-prod.toml"
GARAGE_SERVICE_STAGE="${STAGE_DIR}/garage.service"
GARAGE_BOOTSTRAP_STAGE="${STAGE_DIR}/garage-bootstrap.sh"
MEMOS_S3_BACKUP_STAGE="${STAGE_DIR}/memos-backup-s3.sh"
MEMOS_ENV_S3_STAGE="${STAGE_DIR}/memos.env.s3"
MEMOS_STORAGE_INIT_STAGE="${STAGE_DIR}/memos-storage-init.sh"
MEMOS_STORAGE_MIGRATE_STAGE="${STAGE_DIR}/memos-storage-migrate.sh"
MEMOS_S3_BACKUP_SVC_STAGE="${STAGE_DIR}/memos-s3-backup.service"
MEMOS_S3_BACKUP_TMR_STAGE="${STAGE_DIR}/memos-s3-backup.timer"

# Twenty
TWENTY_COMPOSE_STAGE="${STAGE_DIR}/twenty-compose.yml"
TWENTY_ENV_STAGE="${STAGE_DIR}/twenty.env"
TWENTY_SVC_STAGE="${STAGE_DIR}/twenty.service"

# Legacy Garage config path (for migration)
LEGACY_GARAGE_DATA_VOLUME="moodboard_garage-data"
LEGACY_GARAGE_CONFIG="/root/apps/moodboard/infra/garage/garage-prod.toml"

# Targets
TARGET_RCLONE_CONF="/root/.config/rclone/rclone.conf"
TARGET_SYNC_SCRIPT="/root/sync-capsule.sh"

TARGET_MEMOS_BACKUP="/root/apps/memos/scripts/backup.sh"
TARGET_MEMOS_UPLOAD="/root/apps/memos/scripts/upload-backups.sh"
TARGET_MEMOS_S3_BACKUP="/root/apps/memos/scripts/backup-s3.sh"
TARGET_MEMOS_ENV_S3="/root/apps/memos/.env.s3"
TARGET_MEMOS_STORAGE_MIGRATE="/root/apps/memos/scripts/migrate-to-s3.sh"
TARGET_VIKUNJA_BACKUP="/root/apps/vikunja/scripts/backup.sh"
TARGET_VIKUNJA_UPLOAD="/root/apps/vikunja/scripts/upload-backups.sh"
TARGET_MOODBOARD_BACKUP_A="/root/apps/moodboard/backup-moodboard.sh"
TARGET_MOODBOARD_BACKUP_B="/root/apps/moodboard/scripts/backup-moodboard.sh"

TARGET_MEMOS_BACKUP_SERVICE="/etc/systemd/system/memos-backup.service"
TARGET_MEMOS_BACKUP_TIMER="/etc/systemd/system/memos-backup.timer"
TARGET_MEMOS_S3_BACKUP_SERVICE="/etc/systemd/system/memos-s3-backup.service"
TARGET_MEMOS_S3_BACKUP_TIMER="/etc/systemd/system/memos-s3-backup.timer"

TARGET_MEMOS_COMPOSE="/root/apps/memos/compose.yml"
TARGET_VIKUNJA_COMPOSE="/root/apps/vikunja/compose.yml"
TARGET_MOODBOARD_COMPOSE="/root/apps/moodboard/compose.yml"
TARGET_MOODBOARD_CONTAINERFILE="/root/apps/moodboard/Containerfile"
TARGET_VIKUNJA_ENV="/root/apps/vikunja/.env"
TARGET_MOODBOARD_ENV="/root/apps/moodboard/.env"
TARGET_MOODBOARD_ENV_PROD="/root/apps/moodboard/.env.prod"

TARGET_TWENTY_COMPOSE="/root/apps/twenty/compose.yml"
TARGET_TWENTY_ENV="/root/apps/twenty/.env"
TARGET_TWENTY_SVC="/etc/systemd/system/twenty.service"

TARGET_MEMOS_SVC="/etc/systemd/system/memos.service"
TARGET_VIKUNJA_SVC="/etc/systemd/system/vikunja.service"
TARGET_MOODBOARD_SVC="/etc/systemd/system/moodboard.service"

TARGET_GARAGE_DIR="/root/apps/garage"
TARGET_GARAGE_COMPOSE="/root/apps/garage/compose.yml"
TARGET_GARAGE_CONFIG="/root/apps/garage/garage-prod.toml"
TARGET_GARAGE_DATA="/root/apps/garage/data"
TARGET_GARAGE_SVC="/etc/systemd/system/garage.service"
TARGET_GARAGE_BOOTSTRAP="/root/apps/garage/garage-bootstrap.sh"
TARGET_MEMOS_STORAGE_INIT="/root/apps/garage/memos-storage-init.sh"

BAK_DIR="/root/.bak"

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
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  [[ -f "${f}" ]] || { echo "[ERROR] missing file: ${f}"; exit 1; }
}

unlock_file() {
  local f="$1"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  chattr -i "${f}" 2>/dev/null || true
  chmod u+w "${f}" 2>/dev/null || true
}

lock_file() {
  local f="$1"
  local mode="$2"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] chmod ${mode} ${f} && chattr +i ${f}"
    return 0
  fi
  chmod "${mode}" "${f}" 2>/dev/null || true
  chattr +i "${f}" 2>/dev/null || true
}

backup_if_exists() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    local key
    key="$(echo "${f}" | sed 's#^/##; s#/#__#g')"
    run cp "${f}" "${BAK_DIR}/${key}.bak-${TS}"
  fi
}

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

# Validate stage files
for f in \
  "${RCLONE_CONF_STAGE}" "${SYNC_SCRIPT_STAGE}" "${CRON_LINE_STAGE}" \
  "${MEMOS_BACKUP_STAGE}" "${MEMOS_UPLOAD_STAGE}" "${VIKUNJA_BACKUP_STAGE}" "${VIKUNJA_UPLOAD_STAGE}" "${MOODBOARD_BACKUP_STAGE}" \
  "${MEMOS_BACKUP_SERVICE_STAGE}" "${MEMOS_BACKUP_TIMER_STAGE}" \
  "${MEMOS_COMPOSE_STAGE}" "${VIKUNJA_COMPOSE_STAGE}" "${MOODBOARD_COMPOSE_STAGE}" "${MOODBOARD_CONTAINERFILE_STAGE}" \
  "${VIKUNJA_ENV_STAGE}" "${MOODBOARD_ENV_STAGE}" \
  "${MEMOS_SERVICE_STAGE}" "${VIKUNJA_SERVICE_STAGE}" "${MOODBOARD_SERVICE_STAGE}" \
  "${GARAGE_COMPOSE_STAGE}" "${GARAGE_CONFIG_STAGE}" "${GARAGE_SERVICE_STAGE}" "${GARAGE_BOOTSTRAP_STAGE}" \
  "${MEMOS_S3_BACKUP_STAGE}" "${MEMOS_ENV_S3_STAGE}" "${MEMOS_STORAGE_INIT_STAGE}" "${MEMOS_STORAGE_MIGRATE_STAGE}" \
  "${MEMOS_S3_BACKUP_SVC_STAGE}" "${MEMOS_S3_BACKUP_TMR_STAGE}" \
  "${TWENTY_COMPOSE_STAGE}" "${TWENTY_ENV_STAGE}" "${TWENTY_SVC_STAGE}"; do
  require_file "${f}"
done

# Ensure dirs
run mkdir -p /root/.config/rclone
run chmod 700 /root/.config/rclone
run mkdir -p "${BAK_DIR}" /root/apps/memos/scripts /root/apps/vikunja/scripts /root/apps/moodboard/scripts /root/apps/garage/data /root/apps/twenty

# Ensure packages/services
ensure_pkg_installed "${NODE_EXPORTER_PKG}"
ensure_pkg_installed "${SQLITE_PKG}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: systemctl enable --now ${NODE_EXPORTER_SERVICE}"
else
  systemctl enable --now "${NODE_EXPORTER_SERVICE}" >/dev/null
fi

TS="$(date +%Y%m%d-%H%M%S)"

# unlock managed immutable files before replacing
for f in \
  "${TARGET_MEMOS_COMPOSE}" "${TARGET_VIKUNJA_COMPOSE}" "${TARGET_MOODBOARD_COMPOSE}" "${TARGET_MOODBOARD_CONTAINERFILE}" \
  "${TARGET_VIKUNJA_ENV}" "${TARGET_MOODBOARD_ENV}" "${TARGET_MOODBOARD_ENV_PROD}" "${TARGET_MEMOS_ENV_S3}" \
  "${TARGET_TWENTY_COMPOSE}" "${TARGET_TWENTY_ENV}" \
  "${TARGET_MEMOS_SVC}" "${TARGET_VIKUNJA_SVC}" "${TARGET_MOODBOARD_SVC}" "${TARGET_TWENTY_SVC}" \
  "${TARGET_GARAGE_COMPOSE}" "${TARGET_GARAGE_CONFIG}" "${TARGET_GARAGE_SVC}"; do
  unlock_file "${f}"
done

# backup old files
for f in \
  "${TARGET_RCLONE_CONF}" "${TARGET_SYNC_SCRIPT}" \
  "${TARGET_MEMOS_BACKUP}" "${TARGET_MEMOS_UPLOAD}" "${TARGET_MEMOS_S3_BACKUP}" "${TARGET_MEMOS_ENV_S3}" "${TARGET_MEMOS_STORAGE_MIGRATE}" \
  "${TARGET_VIKUNJA_BACKUP}" "${TARGET_VIKUNJA_UPLOAD}" \
  "${TARGET_MOODBOARD_BACKUP_A}" "${TARGET_MOODBOARD_BACKUP_B}" \
  "${TARGET_MEMOS_BACKUP_SERVICE}" "${TARGET_MEMOS_BACKUP_TIMER}" \
  "${TARGET_MEMOS_S3_BACKUP_SERVICE}" "${TARGET_MEMOS_S3_BACKUP_TIMER}" \
  "${TARGET_MEMOS_COMPOSE}" "${TARGET_VIKUNJA_COMPOSE}" "${TARGET_MOODBOARD_COMPOSE}" "${TARGET_MOODBOARD_CONTAINERFILE}" \
  "${TARGET_VIKUNJA_ENV}" "${TARGET_MOODBOARD_ENV}" "${TARGET_MOODBOARD_ENV_PROD}" "${TARGET_TWENTY_ENV}" \
  "${TARGET_MEMOS_SVC}" "${TARGET_VIKUNJA_SVC}" "${TARGET_MOODBOARD_SVC}" "${TARGET_TWENTY_SVC}" \
  "${TARGET_GARAGE_COMPOSE}" "${TARGET_GARAGE_CONFIG}" "${TARGET_GARAGE_BOOTSTRAP}" "${TARGET_MEMOS_STORAGE_INIT}" \
  "${LEGACY_GARAGE_CONFIG}"; do
  backup_if_exists "${f}"
done

# install files
run install -m 600 "${RCLONE_CONF_STAGE}" "${TARGET_RCLONE_CONF}"
run install -m 700 "${SYNC_SCRIPT_STAGE}" "${TARGET_SYNC_SCRIPT}"

run install -m 700 "${MEMOS_BACKUP_STAGE}" "${TARGET_MEMOS_BACKUP}"
run install -m 700 "${MEMOS_UPLOAD_STAGE}" "${TARGET_MEMOS_UPLOAD}"
run install -m 700 "${VIKUNJA_BACKUP_STAGE}" "${TARGET_VIKUNJA_BACKUP}"
run install -m 700 "${VIKUNJA_UPLOAD_STAGE}" "${TARGET_VIKUNJA_UPLOAD}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_A}"
run install -m 700 "${MOODBOARD_BACKUP_STAGE}" "${TARGET_MOODBOARD_BACKUP_B}"

run install -m 644 "${MEMOS_BACKUP_SERVICE_STAGE}" "${TARGET_MEMOS_BACKUP_SERVICE}"
run install -m 644 "${MEMOS_BACKUP_TIMER_STAGE}" "${TARGET_MEMOS_BACKUP_TIMER}"

run install -m 644 "${MEMOS_COMPOSE_STAGE}" "${TARGET_MEMOS_COMPOSE}"
run install -m 644 "${VIKUNJA_COMPOSE_STAGE}" "${TARGET_VIKUNJA_COMPOSE}"
run install -m 644 "${MOODBOARD_COMPOSE_STAGE}" "${TARGET_MOODBOARD_COMPOSE}"
run install -m 644 "${MOODBOARD_CONTAINERFILE_STAGE}" "${TARGET_MOODBOARD_CONTAINERFILE}"
run install -m 600 "${VIKUNJA_ENV_STAGE}" "${TARGET_VIKUNJA_ENV}"
run install -m 600 "${MOODBOARD_ENV_STAGE}" "${TARGET_MOODBOARD_ENV}"
run install -m 600 "${MOODBOARD_ENV_STAGE}" "${TARGET_MOODBOARD_ENV_PROD}"
run install -m 600 "${MEMOS_ENV_S3_STAGE}" "${TARGET_MEMOS_ENV_S3}"

run install -m 644 "${TWENTY_COMPOSE_STAGE}" "${TARGET_TWENTY_COMPOSE}"

run install -m 644 "${MEMOS_SERVICE_STAGE}" "${TARGET_MEMOS_SVC}"
run install -m 644 "${VIKUNJA_SERVICE_STAGE}" "${TARGET_VIKUNJA_SVC}"
run install -m 644 "${MOODBOARD_SERVICE_STAGE}" "${TARGET_MOODBOARD_SVC}"
run install -m 644 "${TWENTY_SVC_STAGE}" "${TARGET_TWENTY_SVC}"

# Garage standalone
run install -m 644 "${GARAGE_COMPOSE_STAGE}" "${TARGET_GARAGE_COMPOSE}"
run install -m 600 "${GARAGE_CONFIG_STAGE}" "${TARGET_GARAGE_CONFIG}"
run install -m 700 "${GARAGE_BOOTSTRAP_STAGE}" "${TARGET_GARAGE_DIR}/garage-bootstrap.sh"
run install -m 700 "${MEMOS_STORAGE_INIT_STAGE}" "${TARGET_GARAGE_DIR}/memos-storage-init.sh"
run install -m 644 "${GARAGE_SERVICE_STAGE}" "${TARGET_GARAGE_SVC}"

# S3 backup + migrate scripts
run install -m 700 "${MEMOS_S3_BACKUP_STAGE}" "${TARGET_MEMOS_S3_BACKUP}"
run install -m 700 "${MEMOS_STORAGE_MIGRATE_STAGE}" "${TARGET_MEMOS_STORAGE_MIGRATE}"

# S3 backup timer + service
run install -m 644 "${MEMOS_S3_BACKUP_SVC_STAGE}" "${TARGET_MEMOS_S3_BACKUP_SERVICE}"
run install -m 644 "${MEMOS_S3_BACKUP_TMR_STAGE}" "${TARGET_MEMOS_S3_BACKUP_TIMER}"

# ── Garage data migration (one-time) ────────────────────────
# If Garage data exists in the old named volume but not in the new host path,
# migrate it before starting Garage.
if [[ "${DRY_RUN}" -eq 0 ]]; then
  VOL_PATH="/var/lib/containers/storage/volumes/${LEGACY_GARAGE_DATA_VOLUME}/_data"
  if [[ -d "${VOL_PATH}/data" ]] && [[ ! -d "${TARGET_GARAGE_DATA}/data" ]]; then
    echo "[MIGRATE] Copying Garage data from named volume to ${TARGET_GARAGE_DATA}/"
    cp -a "${VOL_PATH}/." "${TARGET_GARAGE_DATA}/"
    echo "[MIGRATE] Garage data migrated successfully"
  fi
fi

# lock critical files
lock_file "${TARGET_MEMOS_COMPOSE}" 444
lock_file "${TARGET_VIKUNJA_COMPOSE}" 444
lock_file "${TARGET_MOODBOARD_COMPOSE}" 444
lock_file "${TARGET_MOODBOARD_CONTAINERFILE}" 444
lock_file "${TARGET_VIKUNJA_ENV}" 444
lock_file "${TARGET_MOODBOARD_ENV}" 444
lock_file "${TARGET_MOODBOARD_ENV_PROD}" 444
lock_file "${TARGET_MEMOS_SVC}" 444
lock_file "${TARGET_VIKUNJA_SVC}" 444
lock_file "${TARGET_MOODBOARD_SVC}" 444
lock_file "${TARGET_GARAGE_COMPOSE}" 444
lock_file "${TARGET_GARAGE_CONFIG}" 444
lock_file "${TARGET_MEMOS_ENV_S3}" 444
lock_file "${TARGET_TWENTY_COMPOSE}" 444
lock_file "${TARGET_TWENTY_ENV}" 444
lock_file "${TARGET_TWENTY_SVC}" 444

# cron
CRON_LINE="$(cat "${CRON_LINE_STAGE}")"
CURRENT_CRON="$(mktemp)"
NEW_CRON="$(mktemp)"
trap 'rm -f "${CURRENT_CRON}" "${NEW_CRON}"' EXIT

crontab -l 2>/dev/null > "${CURRENT_CRON}" || true
grep -v "/root/sync-capsule.sh" "${CURRENT_CRON}" > "${NEW_CRON}" || true
printf "%s\n" "${CRON_LINE}" >> "${NEW_CRON}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would install cron line: ${CRON_LINE}"
else
  crontab "${NEW_CRON}"
fi

# systemd
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: systemctl daemon-reload"
  echo "[DRY-RUN] would run: systemctl enable --now garage.service"
  echo "[DRY-RUN] would run: systemctl enable --now memos-backup.timer"
  echo "[DRY-RUN] would run: systemctl enable --now memos-s3-backup.timer"
  echo "[DRY-RUN] would run: systemctl enable --now twenty.service"
  echo "[DRY-RUN] would run: systemctl enable --now memos.service"
  echo "[DRY-RUN] would run: systemctl enable --now vikunja.service"
  echo "[DRY-RUN] would run: systemctl enable --now moodboard.service"
else
  systemctl daemon-reload
  systemctl enable --now garage.service >/dev/null || true
  echo "[INFO] Waiting for Garage to be ready..."
  sleep 3
  systemctl enable --now memos-backup.timer >/dev/null
  systemctl enable --now memos-s3-backup.timer >/dev/null
  systemctl enable --now memos.service >/dev/null || true
  systemctl enable --now twenty.service >/dev/null || true
  systemctl enable --now vikunja.service >/dev/null || true
  systemctl enable --now moodboard.service >/dev/null || true
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY-RUN] would run: rclone listremotes"
else
  rclone listremotes >/dev/null
fi

echo "[INFO] apply-remote completed (dry_run=${DRY_RUN})"