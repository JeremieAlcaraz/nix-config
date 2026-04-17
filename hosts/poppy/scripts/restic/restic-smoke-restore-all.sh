#!/usr/bin/env bash
# restic-smoke-restore-all.sh — full smoke battery for poppy backups/restores
# Runs backup+restore canary checks for: garage, memos, vikunja, moodboard(assets), twenty(volumes)
set -euo pipefail

export RESTIC_PASSWORD
RESTIC_PASSWORD="$(grep '^RESTIC_PASSWORD=' /root/.config/restic/env | tr -d "'" | cut -d= -f2)"

LOG="/var/log/restic-smoke-restore-all.log"
REPORT="/var/log/restic-smoke-restore-all-report-$(date +%Y%m%d-%H%M%S).md"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }
pass() { log "[PASS] $*"; }
fail() { log "[FAIL] $*"; exit 1; }
latest_snap() { restic snapshots --repo "$1" --compact | awk 'NR>2 && $1 ~ /^[0-9a-f]{8,}$/ {id=$1} END{print id}'; }
ensure_active() {
  local svc="$1"
  if ! systemctl is-active "${svc}" >/dev/null 2>&1; then
    log "[WARN] ${svc} inactive, trying to start"
    systemctl start "${svc}" || true
    sleep 5
  fi
  systemctl is-active "${svc}" >/dev/null 2>&1 || fail "${svc} inactive"
}

SNAP_GARAGE=""
SNAP_MEMOS=""
SNAP_VIKUNJA=""
SNAP_MOODBOARD=""
SNAP_TWENTY=""

log "=== START smoke battery ==="

# 1) Garage (S3 store)
ensure_active garage.service
bash /root/apps/restic/garage-restic-backup.sh >/tmp/smoke-garage-backup.log 2>&1 || fail "garage backup failed"
SNAP_GARAGE="$(latest_snap rclone:gdrive_capsule:garage)"; [[ -n "${SNAP_GARAGE}" ]] || fail "garage snapshot missing"
G_CANARY="/root/apps/garage/data/.restore-canary-garage-$(date +%s).txt"
echo "canary-garage" > "${G_CANARY}"
G_TMP="/tmp/smoke-restore-garage-$(date +%s)"; mkdir -p "${G_TMP}"
restic restore "${SNAP_GARAGE}" --repo rclone:gdrive_capsule:garage --target "${G_TMP}" >/tmp/smoke-garage-restore.log 2>&1 || fail "garage restore command failed"
G_SRC="$(find "${G_TMP}" -type d -path '*/root/apps/garage/data' | head -n1 || true)"; [[ -n "${G_SRC}" ]] || fail "garage restore path not found"
systemctl stop garage.service
if command -v rsync >/dev/null 2>&1; then rsync -a --delete "${G_SRC}/" /root/apps/garage/data/; else find /root/apps/garage/data -mindepth 1 -delete; cp -a "${G_SRC}/." /root/apps/garage/data/; fi
systemctl start garage.service
sleep 3
systemctl is-active garage.service >/dev/null || fail "garage failed to restart"
[[ ! -f "${G_CANARY}" ]] || fail "garage canary still present"
rm -rf "${G_TMP}"
pass "garage restore OK (snapshot ${SNAP_GARAGE})"

# 2) Memos
ensure_active memos.service
bash /root/apps/restic/memos-restic-backup.sh >/tmp/smoke-memos-backup.log 2>&1 || fail "memos backup failed"
SNAP_MEMOS="$(latest_snap rclone:gdrive_capsule:memos)"; [[ -n "${SNAP_MEMOS}" ]] || fail "memos snapshot missing"
M_CANARY="/root/apps/memos/data/.restore-canary-memos-$(date +%s).txt"
echo "canary-memos" > "${M_CANARY}"
M_TMP="/tmp/smoke-restore-memos-$(date +%s)"; mkdir -p "${M_TMP}"
restic restore "${SNAP_MEMOS}" --repo rclone:gdrive_capsule:memos --target "${M_TMP}" >/tmp/smoke-memos-restore.log 2>&1 || fail "memos restore command failed"
M_SRC="$(find "${M_TMP}" -type d -path '*/root/apps/memos/data' | head -n1 || true)"; [[ -n "${M_SRC}" ]] || fail "memos restore path not found"
systemctl stop memos.service
if command -v rsync >/dev/null 2>&1; then rsync -a --delete "${M_SRC}/" /root/apps/memos/data/; else find /root/apps/memos/data -mindepth 1 -delete; cp -a "${M_SRC}/." /root/apps/memos/data/; fi
systemctl start memos.service
sleep 4
systemctl is-active memos.service >/dev/null || fail "memos failed to restart"
[[ ! -f "${M_CANARY}" ]] || fail "memos canary still present"
rm -rf "${M_TMP}"
pass "memos restore OK (snapshot ${SNAP_MEMOS})"

# 3) Vikunja
ensure_active vikunja.service
bash /root/apps/restic/vikunja-restic-backup.sh >/tmp/smoke-vikunja-backup.log 2>&1 || fail "vikunja backup failed"
SNAP_VIKUNJA="$(latest_snap rclone:gdrive_capsule:vikunja)"; [[ -n "${SNAP_VIKUNJA}" ]] || fail "vikunja snapshot missing"
V_CANARY="/root/apps/vikunja/data/.restore-canary-vikunja-$(date +%s).txt"
echo "canary-vikunja" > "${V_CANARY}"
V_TMP="/tmp/smoke-restore-vikunja-$(date +%s)"; mkdir -p "${V_TMP}"
restic restore "${SNAP_VIKUNJA}" --repo rclone:gdrive_capsule:vikunja --target "${V_TMP}" >/tmp/smoke-vikunja-restore.log 2>&1 || fail "vikunja restore command failed"
V_SRC="$(find "${V_TMP}" -type d -path '*/root/apps/vikunja/data' | head -n1 || true)"; [[ -n "${V_SRC}" ]] || fail "vikunja restore path not found"
systemctl stop vikunja.service
if command -v rsync >/dev/null 2>&1; then rsync -a --delete "${V_SRC}/" /root/apps/vikunja/data/; else find /root/apps/vikunja/data -mindepth 1 -delete; cp -a "${V_SRC}/." /root/apps/vikunja/data/; fi
systemctl start vikunja.service
sleep 4
systemctl is-active vikunja.service >/dev/null || fail "vikunja failed to restart"
[[ ! -f "${V_CANARY}" ]] || fail "vikunja canary still present"
rm -rf "${V_TMP}"
pass "vikunja restore OK (snapshot ${SNAP_VIKUNJA})"

# 4) Moodboard (assets-only to avoid immutable managed files)
ensure_active moodboard.service
bash /root/apps/restic/moodboard-restic-backup.sh >/tmp/smoke-moodboard-backup.log 2>&1 || fail "moodboard backup failed"
SNAP_MOODBOARD="$(latest_snap rclone:gdrive_capsule:moodboard)"; [[ -n "${SNAP_MOODBOARD}" ]] || fail "moodboard snapshot missing"
MB_CANARY="/root/apps/moodboard/assets/.restore-canary-moodboard-assets-$(date +%s).txt"
echo "canary-moodboard-assets" > "${MB_CANARY}"
MB_TMP="/tmp/smoke-restore-moodboard-$(date +%s)"; mkdir -p "${MB_TMP}"
restic restore "${SNAP_MOODBOARD}" --repo rclone:gdrive_capsule:moodboard --target "${MB_TMP}" >/tmp/smoke-moodboard-restore.log 2>&1 || fail "moodboard restore command failed"
MB_SRC="$(find "${MB_TMP}" -type d -path '*/root/apps/moodboard/assets' | head -n1 || true)"; [[ -n "${MB_SRC}" ]] || fail "moodboard assets restore path not found"
rsync -a --delete "${MB_SRC}/" /root/apps/moodboard/assets/
[[ ! -f "${MB_CANARY}" ]] || fail "moodboard assets canary still present"
systemctl is-active moodboard.service >/dev/null || fail "moodboard not active after restore"
pass "moodboard assets restore OK (snapshot ${SNAP_MOODBOARD})"
rm -rf "${MB_TMP}"

# 5) Twenty (DB + server volumes)
ensure_active twenty.service
DB_PATH="$(podman volume inspect twenty_twenty-db-data --format '{{.Mountpoint}}' 2>/dev/null || true)"
SRV_PATH="$(podman volume inspect twenty_twenty-server-data --format '{{.Mountpoint}}' 2>/dev/null || true)"
[[ -n "${DB_PATH}" && -n "${SRV_PATH}" ]] || fail "twenty volume mountpoints not found"
bash /root/apps/restic/twenty-restic-backup.sh >/tmp/smoke-twenty-backup.log 2>&1 || fail "twenty backup failed"
SNAP_TWENTY="$(latest_snap rclone:gdrive_capsule:twenty)"; [[ -n "${SNAP_TWENTY}" ]] || fail "twenty snapshot missing"
TDB_CANARY="${DB_PATH}/.restore-canary-twenty-db-$(date +%s).txt"
TSRV_CANARY="${SRV_PATH}/.restore-canary-twenty-srv-$(date +%s).txt"
echo "canary-twenty-db" > "${TDB_CANARY}"
echo "canary-twenty-srv" > "${TSRV_CANARY}"
T_TMP="/tmp/smoke-restore-twenty-$(date +%s)"; mkdir -p "${T_TMP}"
restic restore "${SNAP_TWENTY}" --repo rclone:gdrive_capsule:twenty --target "${T_TMP}" >/tmp/smoke-twenty-restore.log 2>&1 || fail "twenty restore command failed"
TDB_SRC="$(find "${T_TMP}" -type d -path '*twenty_twenty-db-data/_data' | head -n1 || true)"
TSRV_SRC="$(find "${T_TMP}" -type d -path '*twenty_twenty-server-data/_data' | head -n1 || true)"
[[ -n "${TDB_SRC}" && -n "${TSRV_SRC}" ]] || fail "twenty restore paths not found"
systemctl stop twenty.service
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${TDB_SRC}/" "${DB_PATH}/"
  rsync -a --delete "${TSRV_SRC}/" "${SRV_PATH}/"
else
  find "${DB_PATH}" -mindepth 1 -delete
  find "${SRV_PATH}" -mindepth 1 -delete
  cp -a "${TDB_SRC}/." "${DB_PATH}/"
  cp -a "${TSRV_SRC}/." "${SRV_PATH}/"
fi
systemctl start twenty.service
sleep 8
systemctl is-active twenty.service >/dev/null || fail "twenty failed to restart"
[[ ! -f "${TDB_CANARY}" ]] || fail "twenty DB canary still present"
[[ ! -f "${TSRV_CANARY}" ]] || fail "twenty server canary still present"
rm -rf "${T_TMP}"
pass "twenty restore OK (snapshot ${SNAP_TWENTY})"

for s in garage memos vikunja moodboard twenty; do
  systemctl is-active "${s}.service" >/dev/null || fail "${s}.service not active at end"
done

cat > "${REPORT}" <<EOF
# Smoke restore report

Date: $(date -Iseconds)

## Result
- Status: ✅ PASS

## Snapshots used
- garage: ${SNAP_GARAGE}
- memos: ${SNAP_MEMOS}
- vikunja: ${SNAP_VIKUNJA}
- moodboard: ${SNAP_MOODBOARD}
- twenty: ${SNAP_TWENTY}

## Services final state
$(for s in garage memos vikunja moodboard twenty; do echo "- ${s}: $(systemctl is-active ${s}.service)"; done)
EOF

log "[PASS] All smoke tests passed"
log "Report: ${REPORT}"
log "=== END smoke battery ==="
echo "REPORT=${REPORT}"
