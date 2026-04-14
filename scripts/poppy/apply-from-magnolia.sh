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

# ── App sources ─────────────────────────────────────────────
MEMOS_COMPOSE="${REPO_ROOT}/hosts/poppy/apps/memos/compose.yml"
VIKUNJA_COMPOSE="${REPO_ROOT}/hosts/poppy/apps/vikunja/compose.yml"
VIKUNJA_ENV_TPL="${REPO_ROOT}/hosts/poppy/apps/vikunja/.env.template"
MOODBOARD_COMPOSE="${REPO_ROOT}/hosts/poppy/apps/moodboard/compose.yml"
MOODBOARD_CONTAINERFILE="${REPO_ROOT}/hosts/poppy/apps/moodboard/Containerfile"
MOODBOARD_ENV_TPL="${REPO_ROOT}/hosts/poppy/apps/moodboard/.env.template"
GARAGE_COMPOSE="${REPO_ROOT}/hosts/poppy/apps/garage/compose.yml"
GARAGE_CONFIG_TPL="${REPO_ROOT}/hosts/poppy/apps/garage/garage-prod.toml.template"

# ── Script backups ─────────────────────────────────────────
MEMOS_BACKUP="${REPO_ROOT}/hosts/poppy/scripts/memos-backup.sh"
MEMOS_UPLOAD="${REPO_ROOT}/hosts/poppy/scripts/memos-upload-backups.sh"
VIKUNJA_BACKUP="${REPO_ROOT}/hosts/poppy/scripts/vikunja-backup.sh"
VIKUNJA_UPLOAD="${REPO_ROOT}/hosts/poppy/scripts/vikunja-upload-backups.sh"
MOODBOARD_BACKUP="${REPO_ROOT}/hosts/poppy/scripts/moodboard-backup.sh"

# ── Systemd backup ─────────────────────────────────────────
MEMOS_BACKUP_SVC="${REPO_ROOT}/hosts/poppy/systemd/memos-backup.service"
MEMOS_BACKUP_TMR="${REPO_ROOT}/hosts/poppy/systemd/memos-backup.timer"

# ── Systemd app units ──────────────────────────────────────
MEMOS_SVC="${REPO_ROOT}/hosts/poppy/systemd/memos.service"
VIKUNJA_SVC="${REPO_ROOT}/hosts/poppy/systemd/vikunja.service"
MOODBOARD_SVC="${REPO_ROOT}/hosts/poppy/systemd/moodboard.service"
GARAGE_SVC="${REPO_ROOT}/hosts/poppy/systemd/garage.service"

# ── Garage bootstrap ──────────────────────────────────────
GARAGE_BOOTSTRAP="${REPO_ROOT}/hosts/poppy/scripts/garage-bootstrap.sh"

for cmd in sops yq ssh scp python3; do
  command -v "${cmd}" >/dev/null 2>&1 || { echo "[ERROR] missing command: ${cmd}" >&2; exit 1; }
done

AGENTS_MD="${REPO_ROOT}/hosts/poppy/AGENTS.md"

for f in \
  "${SECRETS_FILE}" "${REMOTE_APPLY}" \
  "${MEMOS_COMPOSE}" "${VIKUNJA_COMPOSE}" "${VIKUNJA_ENV_TPL}" \
  "${MOODBOARD_COMPOSE}" "${MOODBOARD_CONTAINERFILE}" "${MOODBOARD_ENV_TPL}" \
  "${GARAGE_COMPOSE}" "${GARAGE_CONFIG_TPL}" \
  "${MEMOS_BACKUP}" "${MEMOS_UPLOAD}" "${VIKUNJA_BACKUP}" "${VIKUNJA_UPLOAD}" "${MOODBOARD_BACKUP}" \
  "${MEMOS_BACKUP_SVC}" "${MEMOS_BACKUP_TMR}" \
  "${MEMOS_SVC}" "${VIKUNJA_SVC}" "${MOODBOARD_SVC}" "${GARAGE_SVC}" "${GARAGE_BOOTSTRAP}" "${AGENTS_MD}"; do
  [[ -f "${f}" ]] || { echo "[ERROR] missing file ${f}" >&2; exit 1; }
done

umask 077
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

DECRYPTED="${TMP_DIR}/poppy.dec.yaml"
RCLONE_CONF="${TMP_DIR}/rclone.conf"
SYNC_SCRIPT="${TMP_DIR}/sync-capsule.sh"
CRON_LINE_FILE="${TMP_DIR}/cron-line.txt"
VIKUNJA_ENV="${TMP_DIR}/vikunja.env"
MOODBOARD_ENV="${TMP_DIR}/moodboard.env"
GARAGE_CONFIG="${TMP_DIR}/garage-prod.toml"

sops -d "${SECRETS_FILE}" > "${DECRYPTED}"

# ── Config de base ───────────────────────────────────────
SSH_HOST="$(yq -r '.poppy.ssh_host' "${DECRYPTED}")"
CLIENT_ID="$(yq -r '.rclone.gdrive.client_id' "${DECRYPTED}")"
CLIENT_SECRET="$(yq -r '.rclone.gdrive.client_secret' "${DECRYPTED}")"
GDRIVE_TOKEN="$(yq -r '.rclone.gdrive.token_json' "${DECRYPTED}")"
CAPSULE_TOKEN="$(yq -r '.rclone.gdrive_capsule.token_json' "${DECRYPTED}")"
ROOT_FOLDER_ID="$(yq -r '.rclone.gdrive_capsule.root_folder_id' "${DECRYPTED}")"
DEST_SUBPATH="$(yq -r '.sync.destination_subpath' "${DECRYPTED}")"
SCHEDULE_CRON="$(yq -r '.sync.schedule_cron' "${DECRYPTED}")"

# ── Secrets apps ─────────────────────────────────────────
VIKUNJA_JWT_SECRET="$(yq -r '.apps.vikunja.jwt_secret' "${DECRYPTED}")"
VIKUNJA_PUBLIC_URL="$(yq -r '.apps.vikunja.public_url' "${DECRYPTED}")"
GARAGE_BUCKET="$(yq -r '.apps.moodboard.garage_bucket' "${DECRYPTED}")"
GARAGE_ACCESS_KEY_ID="$(yq -r '.apps.moodboard.garage_access_key_id' "${DECRYPTED}")"
GARAGE_SECRET_ACCESS_KEY="$(yq -r '.apps.moodboard.garage_secret_access_key' "${DECRYPTED}")"
GEMINI_API_KEY="$(yq -r '.apps.moodboard.gemini_api_key' "${DECRYPTED}")"
GARAGE_RPC_SECRET="$(yq -r '.apps.garage.rpc_secret' "${DECRYPTED}")"
GARAGE_ADMIN_TOKEN="$(yq -r '.apps.garage.admin_token' "${DECRYPTED}")"
GARAGE_METRICS_TOKEN="$(yq -r '.apps.garage.metrics_token' "${DECRYPTED}")"

for v in SSH_HOST CLIENT_ID CLIENT_SECRET GDRIVE_TOKEN CAPSULE_TOKEN ROOT_FOLDER_ID DEST_SUBPATH SCHEDULE_CRON; do
  val="${!v}"
  [[ -n "${val}" && "${val}" != "null" ]] || { echo "[ERROR] missing value: ${v}" >&2; exit 1; }
done

# ── Génère rclone.conf ───────────────────────────────────
python3 - "${RCLONE_CONF}" "${CLIENT_ID}" "${CLIENT_SECRET}" "${GDRIVE_TOKEN}" "${CAPSULE_TOKEN}" "${ROOT_FOLDER_ID}" <<'PY'
import configparser, sys
from pathlib import Path
out = Path(sys.argv[1])
client_id, client_secret, gdrive_token, capsule_token, root_folder_id = sys.argv[2:]
cp = configparser.RawConfigParser()
cp["gdrive"] = {
    "type": "drive", "client_id": client_id, "client_secret": client_secret,
    "scope": "drive", "token": gdrive_token, "team_drive": "",
}
cp["gdrive_capsule"] = {
    "type": "drive", "scope": "drive", "token": capsule_token,
    "team_drive": "", "root_folder_id": root_folder_id,
}
with out.open("w") as f:
    cp.write(f)
PY

# ── Génère sync-capsule.sh ────────────────────────────────
cat > "${SYNC_SCRIPT}" <<EOF
#!/bin/bash
set -euo pipefail
echo "[\$(date)] Demarrage de la synchro vers Google Drive (folderID -> ${DEST_SUBPATH}/)..."
rclone sync /backup-disk "gdrive_capsule:${DEST_SUBPATH}" \\
  --transfers=4 --fast-list --progress --log-level INFO \\
  --log-file /var/log/rclone-sync.log
echo "[\$(date)] Synchro terminee."
EOF
chmod 700 "${SYNC_SCRIPT}"

printf "%s /root/sync-capsule.sh > /var/log/rclone-sync.log 2>&1\n" "${SCHEDULE_CRON}" > "${CRON_LINE_FILE}"

# ── Génère .env depuis templates ──────────────────────────
python3 - "${VIKUNJA_ENV_TPL}" "${VIKUNJA_JWT_SECRET}" "${VIKUNJA_PUBLIC_URL}" > "${VIKUNJA_ENV}" <<'PY2'
import sys
template = open(sys.argv[1]).read()
jwt = sys.argv[2]
url = sys.argv[3]
result = template.replace("{{VIKUNJA_JWT_SECRET}}", jwt)
result = result.replace("{{VIKUNJA_PUBLIC_URL}}", url)
print(result)
PY2

python3 - "${MOODBOARD_ENV_TPL}" "${GARAGE_BUCKET}" "${GARAGE_ACCESS_KEY_ID}" "${GARAGE_SECRET_ACCESS_KEY}" "${GEMINI_API_KEY}" > "${MOODBOARD_ENV}" <<'PY3'
import sys
template = open(sys.argv[1]).read()
bucket, key_id, secret_key, gemini = sys.argv[2:]
result = template.replace("{{GARAGE_BUCKET}}", bucket)
result = result.replace("{{GARAGE_ACCESS_KEY_ID}}", key_id)
result = result.replace("{{GARAGE_SECRET_ACCESS_KEY}}", secret_key)
result = result.replace("{{GEMINI_API_KEY}}", gemini)
print(result)
PY3

# ── Génère garage-prod.toml depuis template ───────────────
python3 - "${GARAGE_CONFIG_TPL}" "${GARAGE_RPC_SECRET}" "${GARAGE_ADMIN_TOKEN}" "${GARAGE_METRICS_TOKEN}" > "${GARAGE_CONFIG}" <<'PY4'
import sys
template = open(sys.argv[1]).read()
rpc, admin, metrics = sys.argv[2:]
result = template.replace("{{RPC_SECRET}}", rpc)
result = result.replace("{{ADMIN_TOKEN}}", admin)
result = result.replace("{{METRICS_TOKEN}}", metrics)
print(result)
PY4

REMOTE_STAGE="/var/lib/poppy-deploy"
ssh "${SSH_HOST}" "mkdir -p '${REMOTE_STAGE}' && chmod 700 '${REMOTE_STAGE}'"

echo "[INFO] Copying files to ${SSH_HOST}:${REMOTE_STAGE}/"
scp -q "${RCLONE_CONF}" "${SSH_HOST}:${REMOTE_STAGE}/rclone.conf"
scp -q "${SYNC_SCRIPT}" "${SSH_HOST}:${REMOTE_STAGE}/sync-capsule.sh"
scp -q "${CRON_LINE_FILE}" "${SSH_HOST}:${REMOTE_STAGE}/cron-line.txt"
scp -q "${REMOTE_APPLY}" "${SSH_HOST}:${REMOTE_STAGE}/apply-remote.sh"

# Backup scripts
scp -q "${MEMOS_BACKUP}" "${SSH_HOST}:${REMOTE_STAGE}/memos-backup.sh"
scp -q "${MEMOS_UPLOAD}" "${SSH_HOST}:${REMOTE_STAGE}/memos-upload-backups.sh"
scp -q "${VIKUNJA_BACKUP}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja-backup.sh"
scp -q "${VIKUNJA_UPLOAD}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja-upload-backups.sh"
scp -q "${MOODBOARD_BACKUP}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard-backup.sh"

# Systemd backup units
scp -q "${MEMOS_BACKUP_SVC}" "${SSH_HOST}:${REMOTE_STAGE}/memos-backup.service"
scp -q "${MEMOS_BACKUP_TMR}" "${SSH_HOST}:${REMOTE_STAGE}/memos-backup.timer"

# App compose + env
scp -q "${MEMOS_COMPOSE}" "${SSH_HOST}:${REMOTE_STAGE}/memos-compose.yml"
scp -q "${VIKUNJA_COMPOSE}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja-compose.yml"
scp -q "${VIKUNJA_ENV}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja.env"
scp -q "${MOODBOARD_COMPOSE}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard-compose.yml"
scp -q "${MOODBOARD_CONTAINERFILE}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard-Containerfile"
scp -q "${MOODBOARD_ENV}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard.env"
scp -q "${GARAGE_COMPOSE}" "${SSH_HOST}:${REMOTE_STAGE}/garage-compose.yml"
scp -q "${GARAGE_CONFIG}" "${SSH_HOST}:${REMOTE_STAGE}/garage-prod.toml"

# App systemd units
scp -q "${MEMOS_SVC}" "${SSH_HOST}:${REMOTE_STAGE}/memos.service"
scp -q "${VIKUNJA_SVC}" "${SSH_HOST}:${REMOTE_STAGE}/vikunja.service"
scp -q "${MOODBOARD_SVC}" "${SSH_HOST}:${REMOTE_STAGE}/moodboard.service"
scp -q "${GARAGE_SVC}" "${SSH_HOST}:${REMOTE_STAGE}/garage.service"

# Garage bootstrap script
scp -q "${GARAGE_BOOTSTRAP}" "${SSH_HOST}:${REMOTE_STAGE}/garage-bootstrap.sh"

# AGENTS.md -> /root/ (permanent, doc for anyone SSHing)
scp -q "${REPO_ROOT}/hosts/poppy/AGENTS.md" "${SSH_HOST}:/root/AGENTS.md"

if [[ "${MODE}" == "dry-run" ]]; then
  ssh "${SSH_HOST}" "chmod 700 '${REMOTE_STAGE}/apply-remote.sh' && STAGE_DIR='${REMOTE_STAGE}' '${REMOTE_STAGE}/apply-remote.sh' --dry-run"
else
  ssh "${SSH_HOST}" "chmod 700 '${REMOTE_STAGE}/apply-remote.sh' && STAGE_DIR='${REMOTE_STAGE}' '${REMOTE_STAGE}/apply-remote.sh'"
fi

echo "[INFO] ${MODE} completed for ${SSH_HOST}"