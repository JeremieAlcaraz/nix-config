#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[2]
SECRETS_FILE = ROOT / "secrets/common.yaml"


def fail(msg: str, code: int = 1):
    print(f"ERROR: {msg}")
    sys.exit(code)


def load_secrets() -> dict[str, str]:
    try:
        raw = subprocess.check_output(["sops", "-d", str(SECRETS_FILE)], text=True)
    except Exception as e:
        fail(f"cannot decrypt {SECRETS_FILE}: {e}")

    vals: dict[str, str] = {}
    for line in raw.splitlines():
        m = re.match(r'^([A-Za-z0-9_]+):\s*"?(.*?)"?\s*$', line)
        if m:
            vals[m.group(1)] = m.group(2)

    for key in ["tailscale_oauth_client_id", "tailscale_oauth_client_secret", "tailscale_tailnet"]:
        if not vals.get(key):
            fail(f"missing key in {SECRETS_FILE}: {key}")

    return vals


def oauth_token(client_id: str, client_secret: str) -> str:
    payload = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "client_credentials",
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.tailscale.com/api/v2/oauth/token",
        data=payload,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            resp = json.loads(r.read().decode())
    except Exception as e:
        fail(f"oauth token request failed: {e}")

    tok = resp.get("access_token", "")
    if not tok:
        fail("oauth response has no access_token")
    return tok


def ensure_service(tailnet: str, token: str, service: str, port: int, comment: Optional[str]):
    svc = service if service.startswith("svc:") else f"svc:{service}"
    url = f"https://api.tailscale.com/api/v2/tailnet/{urllib.parse.quote(tailnet, safe='')}/services/{urllib.parse.quote(svc, safe=':')}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    # If service already exists, preserve addrs required by update API.
    existing = None
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}, method="GET"),
            timeout=20,
        ) as r:
            existing = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        if e.code != 404:
            msg = e.read().decode(errors="replace")
            fail(f"failed to read existing service {svc} HTTP {e.code}: {msg[:280]}")
    except Exception as e:
        fail(f"failed to read existing service {svc}: {e}")

    payload = {
        "name": svc,
        "ports": [f"tcp:{port}"],
    }
    if comment:
        payload["comment"] = comment
    if isinstance(existing, dict) and isinstance(existing.get("addrs"), list):
        payload["addrs"] = existing["addrs"]

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers=headers,
        method="PUT",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = json.loads(r.read().decode())
            print(f"Ensured service {svc} (HTTP {r.status})")
            print(f"- addrs: {', '.join(body.get('addrs', []))}")
            print(f"- ports: {', '.join(body.get('ports', []))}")
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")
        fail(f"failed to ensure service {svc} HTTP {e.code}: {msg[:280]}")
    except Exception as e:
        fail(f"failed to ensure service {svc}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Ensure Tailscale VIP service exists")
    parser.add_argument("service", help="service name (with or without svc: prefix)")
    parser.add_argument("port", type=int, help="service TCP port (usually 443)")
    parser.add_argument("--comment", help="optional service description")
    args = parser.parse_args()

    s = load_secrets()
    token = oauth_token(s["tailscale_oauth_client_id"], s["tailscale_oauth_client_secret"])
    ensure_service(s["tailscale_tailnet"], token, args.service, args.port, args.comment)


if __name__ == "__main__":
    main()
