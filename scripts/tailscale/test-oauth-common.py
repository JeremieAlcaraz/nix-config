#!/usr/bin/env python3
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request

SECRET_FILE = "secrets/common.yaml"


def fail(msg: str, code: int = 1):
    print(f"ERROR: {msg}")
    sys.exit(code)


try:
    decrypted = subprocess.check_output(["sops", "-d", SECRET_FILE], text=True)
except Exception as e:
    fail(f"cannot decrypt {SECRET_FILE}: {e}")

vals = {}
for line in decrypted.splitlines():
    m = re.match(r'^([A-Za-z0-9_]+):\s*"?(.*?)"?\s*$', line)
    if m:
        vals[m.group(1)] = m.group(2)

for key in ["tailscale_oauth_client_id", "tailscale_oauth_client_secret", "tailscale_tailnet"]:
    if not vals.get(key):
        fail(f"missing key in {SECRET_FILE}: {key}")

client_id = vals["tailscale_oauth_client_id"]
client_secret = vals["tailscale_oauth_client_secret"]
tailnet = vals["tailscale_tailnet"]

print("Secrets loaded:")
print(f"- tailscale_oauth_client_id: OK")
print(f"- tailscale_oauth_client_secret: OK")
print(f"- tailscale_tailnet: {tailnet}")

# 1) OAuth token
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
        oauth_body = r.read().decode()
        oauth_status = r.status
except Exception as e:
    fail(f"oauth token request failed: {e}")

oauth = json.loads(oauth_body)
access_token = oauth.get("access_token", "")
if not access_token:
    fail(f"oauth response has no access_token: {oauth}")

print(f"OAuth OK (HTTP {oauth_status}), token received")

# 2) Validate tailnet + policy scope by reading ACL policy
acl_url = f"https://api.tailscale.com/api/v2/tailnet/{urllib.parse.quote(tailnet, safe='')}/acl"
req_acl = urllib.request.Request(
    acl_url,
    headers={"Authorization": f"Bearer {access_token}"},
    method="GET",
)

try:
    with urllib.request.urlopen(req_acl, timeout=20) as r2:
        _ = r2.read()
        print(f"ACL read OK (HTTP {r2.status})")
except urllib.error.HTTPError as e:
    body = e.read().decode(errors="replace")
    fail(f"ACL read failed HTTP {e.code}: {body[:240]}")
except Exception as e:
    fail(f"ACL read failed: {e}")

print("SUCCESS: OAuth creds and tailnet are valid for ACL read")
