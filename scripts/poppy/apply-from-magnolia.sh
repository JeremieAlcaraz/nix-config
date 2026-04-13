#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-apply}"
if [[ "${MODE}" != "apply" && "${MODE}" != "dry-run" ]]; then
  echo "Usage: $0 [apply|dry-run]" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS_FILE="${REPO_ROOT}/secrets/poppy.yaml"
REMOTE_APPLY="${REPO_ROOT}/hosts/poppy/bootstrap/apply-remote.sh"
MEMOS_BACKUP_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/memos-backup.sh"
VIKUNJA_BACKUP_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/vikunja-backup.sh"
VIKUNJA_UPLOAD_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/vikunja-upload-backups.sh"
MOODBOARD_BACKUP_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/moodboard-backup.sh"

for cmd in sops yq ssh scp; do
  command -v "${cmd}" >/dev/null 2>&1 || { echo "[ERROR] missing command: ${cmd}" >&2; exit 1; }
done

[[ -f "${SECRETS_FILE}" ]] || { echo "[ERROR] missing ${SECRETS_FILE}" >&2; exit 1; }
[[ -x "${REMOTE_APPLY}" ]] || { echo "[ERROR] missing executable ${REMOTE_APPLY}" >&2; exit 1; }
for f in "${MEMOS_BACKUP_SCRIPT}" "${VIKUNJA_BACKUP_SCRIPT}" "${VIKUNJA_UPLOAD_SCRIPT}" "${MOODBOARD_BACKUP_SCRIPT}"; do
  [[ -f "${f}" ]] || { echo "[ERROR] missing file ${f}" >&2; exit 1; }
done

umask 077
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

DECRYPTED="${TMP_DIR}/poppy.dec.yaml"
RCLONE_CONF="${TMP_DIR}/rclone.conf"
SYNC_SCRIPT="${TMP_DIR}/sync-capsule.sh"
CRON_LINE_FILE="${TMP_DIR}/cron-line.txt"

sops -d "${SECRETS_FILE}" > "${DECRYPTED}"

SSH_HOST="$(yq -r '.poppy.ssh_host' "${DECRYPTED}")"
CLIENT_ID="$(yq -r '.rclone.gdrive.client_id' "${DECRYPTED}")"
CLIENT_SECRET="$(yq -r '.rclone.gdrive.client_secret' "${DECRYPTED}")"
GDRIVE_TOKEN="$(yq -r '.rclone.gdrive.token_json' "${DECRYPTED}")"
CAPSULE_TOKEN="$(yq -r '.rclone.gdrive_capsule.token_json' "${DECRYPTED}")"
ROOT_FOLDER_ID="$(yq -r '.rclone.gdrive_capsule.root_folder_id' "${DECRYPTED}")"
DEST_SUBPATH="$(yq -r '.sync.destination_subpath' "${DECRYPTED}")"
SCHEDULE_CRON="$(yq -r '.sync.schedule_cron' "${DECRYPTED}")"

for v in SSH_HOST CLIENT_ID CLIENT_SECRET GDRIVE_TOKEN CAPSULE_TOKEN ROOT_FOLDER_ID DEST_SUBPATH SCHEDULE_CRON; do
  [[ -n "${!v}" && "${!v}" != "null" ]] || { echo "[ERROR] missing value: ${v}" >&2; exit 1; }
done

python3 - "${RCLONE_CONF}" "${CLIENT_ID}" "${CLIENT_SECRET}" "${GDRIVE_TOKEN}" "${CAPSULE_TOKEN}" "${ROOT_FOLDER_ID}" <<'PY'
import configparser, sys
from pathlib import Path
out = Path(sys.argv[1])
client_id, client_secret, gdrive_token, capsule_token, root_folder_id = sys.argv[2:]
cp = configparser.RawConfigParser()
cp["gdrive"] = {
    "type": "drive",
    "client_id": client_id,
    "client_secret": client_secret,
    "scope": "drive",
    "token": gdrive_token,
    "team_drive": "",
}
cp["gdrive_capsule"] = {
    "type": "drive",
    "scope": "drive",
    "token": capsule_token,
    "team_drive": "",
    "root_folder_id": root_folder_id,
}
with out.open("w") as f:
    cp.write(f)
PY

cat > "${SYNC_SCRIPT}" <<EOF
#!/bin/bash
set -euo pipefail

echo "[\$(date)] Demarrage de la synchro vers Google Drive (folderID -> ${DEST_SUBPATH}/)..."

rclone sync /backup-disk "gdrive_capsule:${DEST_SUBPATH}" \\
  --transfers=4 \\
  --fast-list \\
  --progress \\
  --log-level INFO \\
  --log-file /var/log/rclone-sync.log

echo "[\$(date)] Synchro terminee."
EOF
chmod 700 "${SYNC_SCRIPT}"

printf "%s /root/sync-capsule.sh > /var/log/rclone-sync.log 2>&1\n" "${SCHEDULE_CRON}" > "${CRON_LINE_FILE}"

REMOTE_STAGE="/tmp/poppy-bootstrap"
ssh "${SSH_HOST}" "mkdir -p '${REMOTE_STAGE}' && chmod 700 '${REMOTE_STAGE}'"
scp -q "${RCLONE_CONF}" "${SSH_HOST}:${REMOTE_STAGE}/rclone.conf"
scp -q "${SYNC_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/sync-capsule.sh"
scp -q "${CRON_LINE_FILE}" "${SSH_HOST}:${REMOTE_STAGE}/cron-line.txt"
scp -q "${REMOTE_APPLY}" "${SSH_HOST}:${REMOTE_STAGE}/apply-remote.sh"
scp -q "${MEMOS_BACKUP_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/memos-backup.sh"
scp -q "${VIKUNJA_BACKUP_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja-backup.sh"
scp -q "${VIKUNJA_UPLOAD_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja-upload-backups.sh"
scp -q "${MOODBOARD_BACKUP_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard-backup.sh"

if [[ "${MODE}" == "dry-run" ]]; then
  ssh "${SSH_HOST}" "chmod 700 '${REMOTE_STAGE}/apply-remote.sh' && STAGE_DIR='${REMOTE_STAGE}' '${REMOTE_STAGE}/apply-remote.sh' --dry-run"
else
  ssh "${SSH_HOST}" "chmod 700 '${REMOTE_STAGE}/apply-remote.sh' && STAGE_DIR='${REMOTE_STAGE}' '${REMOTE_STAGE}/apply-remote.sh'"
fi

echo "[INFO] ${MODE} completed for ${SSH_HOST}"
