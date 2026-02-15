#!/usr/bin/env bash
set -euo pipefail

RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive_capsule}"
RCLONE_SUBPATH="${RCLONE_SUBPATH:-proxmox}"
EXPECTED_ROOT_FOLDER_ID="${EXPECTED_ROOT_FOLDER_ID:-1q9urpon7tZUSdeO1UfW3kIM8feURFIYe}"

echo "[INFO] Remote cible: ${RCLONE_REMOTE}"
echo "[INFO] Sous-dossier cible: ${RCLONE_SUBPATH}"
echo "[INFO] root_folder_id attendu: ${EXPECTED_ROOT_FOLDER_ID}"

if ! command -v rclone >/dev/null 2>&1; then
  echo "[ERROR] rclone introuvable dans le PATH."
  exit 1
fi

if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
  echo "[ERROR] Remote ${RCLONE_REMOTE}: introuvable."
  exit 1
fi

cfg_line="$(rclone config show "${RCLONE_REMOTE}" 2>/dev/null | grep '^root_folder_id = ' || true)"
actual_id="${cfg_line#root_folder_id = }"
if [[ -z "${actual_id}" ]]; then
  echo "[WARN] Aucun root_folder_id configure pour ${RCLONE_REMOTE}."
else
  echo "[INFO] root_folder_id configure: ${actual_id}"
fi

if [[ -n "${actual_id}" && "${actual_id}" != "${EXPECTED_ROOT_FOLDER_ID}" ]]; then
  echo "[ERROR] root_folder_id inattendu."
  exit 2
fi

echo "[INFO] Dossiers au niveau racine du root_folder_id:"
rclone lsf --dirs-only "${RCLONE_REMOTE}:" | sed -n '1,200p'

if rclone lsf --dirs-only "${RCLONE_REMOTE}:" | grep -q "^${RCLONE_SUBPATH}/$"; then
  echo "[OK] Dossier ${RCLONE_SUBPATH}/ present."
else
  echo "[WARN] Dossier ${RCLONE_SUBPATH}/ absent."
fi

echo "[INFO] Verification terminee (read-only)."
