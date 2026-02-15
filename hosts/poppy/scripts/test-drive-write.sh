#!/usr/bin/env bash
set -euo pipefail

RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive_capsule}"
RCLONE_SUBPATH="${RCLONE_SUBPATH:-proxmox}"
TEST_PREFIX="${TEST_PREFIX:-_codex-drive-target-test}"

if ! command -v rclone >/dev/null 2>&1; then
  echo "[ERROR] rclone introuvable dans le PATH."
  exit 1
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
name="${TEST_PREFIX}-${ts}.txt"
tmp_file="/tmp/${name}"
dest="${RCLONE_REMOTE}:${RCLONE_SUBPATH}/${name}"

echo "test marker from $(hostname) at ${ts}" > "${tmp_file}"

echo "[INFO] Upload test marker -> ${dest}"
rclone copyto "${tmp_file}" "${dest}" --log-level INFO

echo "[INFO] Verification de presence dans ${RCLONE_REMOTE}:${RCLONE_SUBPATH}/"
rclone lsf "${RCLONE_REMOTE}:${RCLONE_SUBPATH}" | grep "${name}"

echo "[OK] Test d'ecriture valide: ${name}"
