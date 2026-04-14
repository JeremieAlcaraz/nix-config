#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS_FILE="${REPO_ROOT}/secrets/poppy.yaml"
VERIFY_SCRIPT="${REPO_ROOT}/hosts/poppy/scripts/verify-drive-target.sh"

command -v sops >/dev/null 2>&1 || { echo "[ERROR] missing sops" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "[ERROR] missing yq" >&2; exit 1; }
[[ -f "${SECRETS_FILE}" ]] || { echo "[ERROR] missing ${SECRETS_FILE}" >&2; exit 1; }
[[ -f "${VERIFY_SCRIPT}" ]] || { echo "[ERROR] missing ${VERIFY_SCRIPT}" >&2; exit 1; }

umask 077
TMP_DEC="$(mktemp)"
trap 'rm -f "${TMP_DEC}"' EXIT
sops -d "${SECRETS_FILE}" > "${TMP_DEC}"

SSH_HOST="$(yq -r '.poppy.ssh_host' "${TMP_DEC}")"
EXPECTED_ROOT_FOLDER_ID="$(yq -r '.rclone.gdrive_capsule.root_folder_id' "${TMP_DEC}")"

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
ssh "${SSH_HOST}" "EXPECTED_ROOT_FOLDER_ID='${EXPECTED_ROOT_FOLDER_ID}' bash -s" < "${VERIFY_SCRIPT}"
echo "[INFO] check completed"