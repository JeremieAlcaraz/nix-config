#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <host> <service> <port>" >&2
  exit 1
fi

HOST="$1"
SERVICE="$2"
PORT="$3"
SVC="svc:${SERVICE#svc:}"

echo "Configuring Tailscale service ${SVC} on ${HOST} -> 127.0.0.1:${PORT}"

# Run the resilient sequence on the target host:
# 1) pre-check local backend
# 2) drain+advertise to clear stale pending states
# 3) serve --service
# 4) if approval warning appears, retry drain+advertise+serve once
ssh "$HOST" bash -s -- "$PORT" "$SVC" "$HOST" <<'REMOTE'
set -euo pipefail

PORT="$1"
SVC="$2"
HOST_NAME="$3"

if ! curl -fsSI --max-time 5 "http://127.0.0.1:${PORT}" >/dev/null; then
  echo "ERROR: backend not reachable on ${HOST_NAME}:127.0.0.1:${PORT}" >&2
  exit 1
fi

tailscale serve drain "${SVC}" >/dev/null 2>&1 || true
tailscale serve advertise "${SVC}" >/dev/null 2>&1 || true

OUT="$(tailscale serve --yes --bg --service="${SVC}" --https=443 "http://127.0.0.1:${PORT}" 2>&1 || true)"
echo "${OUT}"

if echo "${OUT}" | grep -qi 'approval from an admin is required'; then
  tailscale serve drain "${SVC}" >/dev/null 2>&1 || true
  tailscale serve advertise "${SVC}" >/dev/null 2>&1 || true
  tailscale serve --yes --bg --service="${SVC}" --https=443 "http://127.0.0.1:${PORT}"
fi
REMOTE

echo "Service status on ${HOST}:"
ssh "$HOST" "tailscale serve status --json"
