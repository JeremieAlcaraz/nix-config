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
ssh "$HOST" "tailscale serve --yes --bg --service=${SVC} --https=443 http://127.0.0.1:${PORT}"
ssh "$HOST" "tailscale serve advertise ${SVC} || true"

echo "Service status on ${HOST}:"
ssh "$HOST" "tailscale serve status --json"
