#!/usr/bin/env bash
# garage-bootstrap.sh — create buckets and keys for all apps
# Run once after Garage is up. Safe to re-run (checks before creating).
set -euo pipefail

GARAGE_CLI="podman exec garage /garage"
S3_ENDPOINT="http://localhost:3900"

# ── Memos bucket + key ───────────────────────────────────────
echo "[INFO] Ensuring memos bucket..."
EXISTING=$(${GARAGE_CLI} bucket list 2>/dev/null | grep -c "^memos$" || true)
if [[ "${EXISTING}" -eq 0 ]]; then
  ${GARAGE_CLI} bucket create memos || true
  echo "[OK] bucket memos created (or already exists)"
else
  echo "[OK] bucket memos already exists"
fi

echo "[INFO] Ensuring memos-app key..."
KEY_EXISTS=$(${GARAGE_CLI} key list 2>/dev/null | grep -c "memos-app" || true)
if [[ "${KEY_EXISTS}" -eq 0 ]]; then
  ${GARAGE_CLI} key create memos-app 2>&1 | tee /dev/stderr
  echo ""
  echo "[ACTION REQUIRED] Copy the Access Key ID and Secret Access Key above"
  echo "                  and add them to secrets/poppy.yaml (SOPS) under:"
  echo "                  apps.memos.garage_access_key_id"
  echo "                  apps.memos.garage_secret_access_key"
  echo ""
else
  echo "[OK] key memos-app already exists"
  ${GARAGE_CLI} key info memos-app 2>/dev/null | grep -E "^(Key|Secret)" || true
fi

# ── Twenty bucket + key ──────────────────────────────────────
echo "[INFO] Ensuring twenty bucket..."
EXISTING=$(${GARAGE_CLI} bucket list 2>/dev/null | grep -c "^twenty$" || true)
if [[ "${EXISTING}" -eq 0 ]]; then
  ${GARAGE_CLI} bucket create twenty || true
  echo "[OK] bucket twenty created (or already exists)"
else
  echo "[OK] bucket twenty already exists"
fi

echo "[INFO] Ensuring twenty-app key..."
KEY_EXISTS=$(${GARAGE_CLI} key list 2>/dev/null | grep -c "twenty-app" || true)
if [[ "${KEY_EXISTS}" -eq 0 ]]; then
  ${GARAGE_CLI} key create twenty-app 2>&1 | tee /dev/stderr
  echo ""
  echo "[ACTION REQUIRED] Copy the Access Key ID and Secret Access Key above"
  echo "                  and add them to secrets/poppy.yaml (SOPS) under:"
  echo "                  apps.twenty.garage_access_key_id"
  echo "                  apps.twenty.garage_secret_access_key"
  echo ""
else
  echo "[OK] key twenty-app already exists"
  ${GARAGE_CLI} key info twenty-app 2>/dev/null | grep -E "^(Key|Secret)" || true
fi

# ── Grant permissions ────────────────────────────────────────
echo "[INFO] Granting key permissions on buckets..."
${GARAGE_CLI} bucket allow --read --write --owner memos --key memos-app 2>/dev/null || echo "[WARN] could not grant memos permissions"
${GARAGE_CLI} bucket allow --read --write --owner moodboard-dev --key moodboard-dev-app 2>/dev/null || echo "[WARN] could not grant moodboard permissions"
${GARAGE_CLI} bucket allow --read --write --owner twenty --key twenty-app 2>/dev/null || echo "[WARN] could not grant twenty permissions"

echo "[INFO] Garage bootstrap complete"
echo ""
echo "Bucket list:"
${GARAGE_CLI} bucket list 2>/dev/null || true
echo ""
echo "Key list:"
${GARAGE_CLI} key list 2>/dev/null || true
