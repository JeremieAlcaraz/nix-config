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

ROOT = Path(__file__).resolve().parents[2]
SECRETS_FILE = ROOT / "secrets/common.yaml"
SERVICES_FILE = ROOT / "ops/tailscale/services.json"


def fail(msg: str, code: int = 1):
    print(f"ERROR: {msg}")
    sys.exit(code)


def decrypt_common_secrets() -> dict[str, str]:
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


def get_oauth_token(client_id: str, client_secret: str) -> str:
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


def strip_hujson(text: str) -> str:
    # Remove // comments while preserving strings.
    out = []
    i = 0
    in_str = False
    while i < len(text):
        ch = text[i]
        if ch == '"' and (i == 0 or text[i - 1] != "\\"):
            in_str = not in_str
            out.append(ch)
            i += 1
            continue
        if not in_str and ch == "/" and i + 1 < len(text) and text[i + 1] == "/":
            i += 2
            while i < len(text) and text[i] not in "\r\n":
                i += 1
            continue
        out.append(ch)
        i += 1

    cleaned = "".join(out)
    # Remove trailing commas before } or ]
    prev = None
    while prev != cleaned:
        prev = cleaned
        cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return cleaned


def get_acl(tailnet: str, token: str) -> tuple[str, dict]:
    url = f"https://api.tailscale.com/api/v2/tailnet/{urllib.parse.quote(tailnet, safe='')}/acl"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
    except Exception as e:
        fail(f"failed to fetch ACL policy: {e}")

    try:
        parsed = json.loads(strip_hujson(raw))
    except Exception as e:
        fail(f"failed to parse ACL policy as HuJSON: {e}")

    return raw, parsed


def normalize_service_name(name: str) -> str:
    return name if name.startswith("svc:") else f"svc:{name}"


def sync_policy(acl: dict, services: list[dict]) -> tuple[dict, list[str]]:
    changes: list[str] = []

    auto = acl.setdefault("autoApprovers", {})
    auto_services = auto.setdefault("services", {})

    grants = acl.setdefault("grants", [])

    for service in services:
        svc = normalize_service_name(service["name"])
        tag = service.get("autoApproveTag", "tag:newmachine")

        current_tags = auto_services.get(svc)
        if not isinstance(current_tags, list):
            auto_services[svc] = [tag]
            changes.append(f"autoApprovers.services[{svc}] = [{tag}]")
        elif tag not in current_tags:
            current_tags.append(tag)
            changes.append(f"autoApprovers.services[{svc}] add {tag}")

        has_grant = False
        for grant in grants:
            if not isinstance(grant, dict):
                continue
            dst = grant.get("dst", [])
            if isinstance(dst, list) and svc in dst:
                has_grant = True
                break

        if not has_grant:
            grants.append(
                {
                    "src": ["autogroup:members"],
                    "dst": [svc],
                    "ip": ["443"],
                }
            )
            changes.append(f"grants add autogroup:members -> {svc}:443")

    return acl, changes


def put_acl(tailnet: str, token: str, acl: dict):
    url = f"https://api.tailscale.com/api/v2/tailnet/{urllib.parse.quote(tailnet, safe='')}/acl"
    body = json.dumps(acl, indent=2).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            _ = r.read().decode(errors="replace")
            print(f"Applied ACL policy (HTTP {r.status})")
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")
        fail(f"failed to apply ACL policy HTTP {e.code}: {msg[:300]}")
    except Exception as e:
        fail(f"failed to apply ACL policy: {e}")


def main():
    parser = argparse.ArgumentParser(description="Sync Tailscale autoApprovers/services policy from ops/tailscale/services.json")
    parser.add_argument("--apply", action="store_true", help="Apply changes to tailnet ACL policy")
    parser.add_argument("--service", help="Sync only one service name (without svc: prefix)")
    args = parser.parse_args()

    if not SERVICES_FILE.exists():
        fail(f"missing services file: {SERVICES_FILE}")

    cfg = json.loads(SERVICES_FILE.read_text())
    services = cfg.get("services", [])
    if args.service:
        services = [s for s in services if s.get("name") == args.service]
        if not services:
            fail(f"service '{args.service}' not found in {SERVICES_FILE}")

    secrets = decrypt_common_secrets()
    token = get_oauth_token(secrets["tailscale_oauth_client_id"], secrets["tailscale_oauth_client_secret"])
    _, acl = get_acl(secrets["tailscale_tailnet"], token)

    next_acl, changes = sync_policy(acl, services)

    if not changes:
        print("No policy changes needed.")
        return

    print("Planned policy changes:")
    for c in changes:
        print(f"- {c}")

    if args.apply:
        put_acl(secrets["tailscale_tailnet"], token, next_acl)
    else:
        print("Dry-run only. Re-run with --apply to push ACL policy.")


if __name__ == "__main__":
    main()
