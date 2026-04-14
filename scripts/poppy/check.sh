#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS_FILE="${REPO_ROOT}/secrets/poppy.yaml"
VERIFY_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/verify-drive-target.sh"

VIKUNJA_ENV_TPL="${REPO_ROOT}/hosts/poppy/apps/vikunja/.env.template"
MOODBOARD_ENV_TPL="${REPO_ROOT}/hosts/poppy/apps/moodboard/.env.template"
GARAGE_CONFIG_TPL="${REPO_ROOT}/hosts/poppy/apps/garage/garage-prod.toml.template"

command -v sops >/dev/null 2>&1 || { echo "[ERROR] missing sops" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "[ERROR] missing yq" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[ERROR] missing python3" >&2; exit 1; }
[[ -f "${SECRETS_FILE}" ]] || { echo "[ERROR] missing ${SECRETS_FILE}" >&2; exit 1; }
[[ -f "${VERIFY_SCRIPT}" ]] || { echo "[ERROR] missing ${VERIFY_SCRIPT}" >&2; exit 1; }
[[ -f "${VIKUNJA_ENV_TPL}" ]] || { echo "[ERROR] missing ${VIKUNJA_ENV_TPL}" >&2; exit 1; }
[[ -f "${GARAGE_CONFIG_TPL}" ]] || { echo "[ERROR] missing ${GARAGE_CONFIG_TPL}" >&2; exit 1; }

local_sha256() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${f}" | awk '{print $1}'
  else
    shasum -a 256 "${f}" | awk '{print $1}'
  fi
}

umask 077
TMP_DIR="$(mktemp -d)"
TMP_DEC="${TMP_DIR}/poppy.dec.yaml"
VIKUNJA_ENV_EXPECTED="${TMP_DIR}/vikunja.env"
MOODBOARD_ENV_EXPECTED="${TMP_DIR}/moodboard.env"
GARAGE_CONFIG_EXPECTED="${TMP_DIR}/garage-prod.toml"
trap 'rm -rf "${TMP_DIR}"' EXIT

sops -d "${SECRETS_FILE}" > "${TMP_DEC}"

SSH_HOST="$(yq -r '.poppy.ssh_host' "${TMP_DEC}")"
EXPECTED_ROOT_FOLDER_ID="$(yq -r '.rclone.gdrive_capsule.root_folder_id' "${TMP_DEC}")"

# Generate expected env files exactly like deploy script
VIKUNJA_JWT_SECRET="$(yq -r '.apps.vikunja.jwt_secret' "${TMP_DEC}")"
VIKUNJA_PUBLIC_URL="$(yq -r '.apps.vikunja.public_url' "${TMP_DEC}")"
GARAGE_BUCKET="$(yq -r '.apps.moodboard.garage_bucket' "${TMP_DEC}")"
GARAGE_ACCESS_KEY_ID="$(yq -r '.apps.moodboard.garage_access_key_id' "${TMP_DEC}")"
GARAGE_SECRET_ACCESS_KEY="$(yq -r '.apps.moodboard.garage_secret_access_key' "${TMP_DEC}")"
GEMINI_API_KEY="$(yq -r '.apps.moodboard.gemini_api_key' "${TMP_DEC}")"
GARAGE_RPC_SECRET="$(yq -r '.apps.garage.rpc_secret' "${TMP_DEC}")"
GARAGE_ADMIN_TOKEN="$(yq -r '.apps.garage.admin_token' "${TMP_DEC}")"
GARAGE_METRICS_TOKEN="$(yq -r '.apps.garage.metrics_token' "${TMP_DEC}")"

python3 - "${VIKUNJA_ENV_TPL}" "${VIKUNJA_JWT_SECRET}" "${VIKUNJA_PUBLIC_URL}" > "${VIKUNJA_ENV_EXPECTED}" <<'PY'
import sys
template = open(sys.argv[1]).read()
print(template.replace("{{VIKUNJA_JWT_SECRET}}", sys.argv[2]).replace("{{VIKUNJA_PUBLIC_URL}}", sys.argv[3]))
PY

python3 - "${MOODBOARD_ENV_TPL}" "${GARAGE_BUCKET}" "${GARAGE_ACCESS_KEY_ID}" "${GARAGE_SECRET_ACCESS_KEY}" "${GEMINI_API_KEY}" > "${MOODBOARD_ENV_EXPECTED}" <<'PY'
import sys
template = open(sys.argv[1]).read()
bucket, key_id, secret_key, gemini = sys.argv[2:]
result = template.replace("{{GARAGE_BUCKET}}", bucket)
result = result.replace("{{GARAGE_ACCESS_KEY_ID}}", key_id)
result = result.replace("{{GARAGE_SECRET_ACCESS_KEY}}", secret_key)
result = result.replace("{{GEMINI_API_KEY}}", gemini)
print(result)
PY

python3 - "${GARAGE_CONFIG_TPL}" "${GARAGE_RPC_SECRET}" "${GARAGE_ADMIN_TOKEN}" "${GARAGE_METRICS_TOKEN}" > "${GARAGE_CONFIG_EXPECTED}" <<'PY'
import sys
template = open(sys.argv[1]).read()
rpc, admin, metrics = sys.argv[2:]
result = template.replace("{{RPC_SECRET}}", rpc)
result = result.replace("{{ADMIN_TOKEN}}", admin)
result = result.replace("{{METRICS_TOKEN}}", metrics)
print(result)
PY

echo "[INFO] Remote checks on ${SSH_HOST}"
ssh "${SSH_HOST}" "proxmox-backup-manager datastore list >/dev/null && echo '[OK] datastore list'"
ssh "${SSH_HOST}" "crontab -l | grep '/root/sync-capsule.sh' >/dev/null && echo '[OK] cron line present'"
ssh "${SSH_HOST}" "systemctl is-enabled memos.service >/dev/null && echo '[OK] memos.service enabled'"
ssh "${SSH_HOST}" "systemctl is-enabled vikunja.service >/dev/null && echo '[OK] vikunja.service enabled'"
ssh "${SSH_HOST}" "systemctl is-enabled moodboard.service >/dev/null && echo '[OK] moodboard.service enabled'"
ssh "${SSH_HOST}" "podman ps --format '{{.Names}}' | grep -q '^vikunja$' && echo '[OK] vikunja podman running' || echo '[WARN] vikunja not in podman'"
ssh "${SSH_HOST}" "podman ps --format '{{.Names}}' | grep -q '^memos$' && echo '[OK] memos podman running' || echo '[WARN] memos not in podman'"
ssh "${SSH_HOST}" "podman ps --format '{{.Names}}' | grep -q '^moodboard-app$' && echo '[OK] moodboard podman running' || echo '[WARN] moodboard not in podman'"
ssh "${SSH_HOST}" "curl -fsS http://127.0.0.1:9100/metrics >/dev/null && echo '[OK] node exporter endpoint local'"
ssh "${SSH_HOST}" "systemctl is-enabled memos-backup.timer >/dev/null && echo '[OK] memos-backup.timer enabled'"
ssh "${SSH_HOST}" "systemctl is-active memos-backup.timer >/dev/null && echo '[OK] memos-backup.timer active'"
ssh "${SSH_HOST}" "systemctl is-enabled garage.service >/dev/null && echo '[OK] garage.service enabled'"
ssh "${SSH_HOST}" "podman ps --format '{{.Names}}' | grep -q '^garage$' && echo '[OK] garage podman running' || echo '[WARN] garage not in podman'"
# Check memos S3 storage status
MEMOS_STORAGE_TYPE=$(ssh "${SSH_HOST}" "sqlite3 /root/apps/memos/data/memos_prod.db 'SELECT json_extract(value,'\''$.storageType'\'''') FROM system_setting WHERE name = '\''STORAGE'\'';' 2>/dev/null || echo ''")
if [[ "${MEMOS_STORAGE_TYPE}" == "S3" ]]; then
  echo "[OK] memos storage type: S3"
else
  echo "[WARN] memos storage type: ${MEMOS_STORAGE_TYPE:-unknown}"
fi
ssh "${SSH_HOST}" "EXPECTED_ROOT_FOLDER_ID='${EXPECTED_ROOT_FOLDER_ID}' bash -s" < "${VERIFY_SCRIPT}"

echo "[INFO] Drift check (SoT vs remote files)"
DRIFT=0

DRIFT_MAP=(
  "${REPO_ROOT}/hosts/poppy/apps/memos/compose.yml|/root/apps/memos/compose.yml"
  "${REPO_ROOT}/hosts/poppy/apps/vikunja/compose.yml|/root/apps/vikunja/compose.yml"
  "${REPO_ROOT}/hosts/poppy/apps/moodboard/compose.yml|/root/apps/moodboard/compose.yml"
  "${REPO_ROOT}/hosts/poppy/apps/moodboard/Containerfile|/root/apps/moodboard/Containerfile"
  "${VIKUNJA_ENV_EXPECTED}|/root/apps/vikunja/.env"
  "${MOODBOARD_ENV_EXPECTED}|/root/apps/moodboard/.env"
  "${MOODBOARD_ENV_EXPECTED}|/root/apps/moodboard/.env.prod"
  "${REPO_ROOT}/hosts/poppy/apps/garage/compose.yml|/root/apps/garage/compose.yml"
  "${GARAGE_CONFIG_EXPECTED}|/root/apps/garage/garage-prod.toml"
  "${REPO_ROOT}/hosts/poppy/systemd/memos.service|/etc/systemd/system/memos.service"
  "${REPO_ROOT}/hosts/poppy/systemd/vikunja.service|/etc/systemd/system/vikunja.service"
  "${REPO_ROOT}/hosts/poppy/systemd/moodboard.service|/etc/systemd/system/moodboard.service"
  "${REPO_ROOT}/hosts/poppy/systemd/garage.service|/etc/systemd/system/garage.service"
)

for pair in "${DRIFT_MAP[@]}"; do
  IFS='|' read -r local_file remote_file <<< "${pair}"

  if [[ ! -f "${local_file}" ]]; then
    echo "[DRIFT] local missing: ${local_file}"
    DRIFT=1
    continue
  fi

  expected_hash="$(local_sha256 "${local_file}")"
  remote_hash="$(ssh "${SSH_HOST}" "if [ -f '${remote_file}' ]; then sha256sum '${remote_file}' | cut -d' ' -f1; else echo MISSING; fi")"

  if [[ "${remote_hash}" == "MISSING" ]]; then
    echo "[DRIFT] remote missing: ${remote_file}"
    DRIFT=1
    continue
  fi

  if [[ "${expected_hash}" == "${remote_hash}" ]]; then
    echo "[OK] drift ${remote_file}"
  else
    echo "[DRIFT] ${remote_file}"
    echo "        expected=${expected_hash}"
    echo "        remote  =${remote_hash}"
    DRIFT=1
  fi
done

if [[ "${DRIFT}" -ne 0 ]]; then
  echo "[ERROR] Drift detected. Re-apply with: just poppy-apply"
  exit 2
fi

echo "[INFO] check completed"