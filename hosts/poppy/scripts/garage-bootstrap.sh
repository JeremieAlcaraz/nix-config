#!/usr/bin/env bash
# garage-bootstrap.sh — create buckets and keys for all apps
# Run once after Garage is up. Safe to re-run (checks before creating).
set -euo pipefail

GARAGE_CLI="podman exec garage /garage"
S3_ENDPOINT="http://localhost:3900"

# ── Moodboard bucket + key ───────────────────────────────────
echo "[INFO] Ensuring moodboard bucket..."
EXISTING=$(${GARAGE_CLI} bucket list 2>/dev/null | grep -c "moodboard-dev" || true)
if [[ "${EXISTING}" -eq 0 ]]; then
  ${GARAGE_CLI} bucket create moodboard-dev
  echo "[OK] bucket moodboard-dev created"
else
  echo "[OK] bucket moodboard-dev already exists"
fi

# ── Memos bucket + key ───────────────────────────────────────
echo "[INFO] Ensuring memos bucket..."
EXISTING=$(${GARAGE_CLI} bucket list 2>/dev/null | grep -c "^memos$" || true)
if [[ "${EXISTING}" -eq 0 ]]; then
  ${GARAGE_CLI} bucket create memos
  echo "[OK] bucket memos created"
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

# ── Grant permissions ────────────────────────────────────────
echo "[INFO] Granting key permissions on buckets..."
${GARAGE_CLI} bucket allow --read --write --owner memos --key memos-app 2>/dev/null || echo "[WARN] could not grant memos permissions (may already exist)"
${GARAGE_CLI} bucket allow --read --write --owner moodboard-dev --key moodboard-dev-app 2>/dev/null || echo "[WARN] could not grant moodboard permissions (may already exist)"

echo "[INFO] Garage bootstrap complete"
echo ""
echo "Bucket list:"
${GARAGE_CLI} bucket list 2>/dev/null || true
echo ""
echo "Key list:"
${GARAGE_CLI} key list 2>/dev/null || true
