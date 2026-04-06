#!/usr/bin/env python3
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import urllib.error

SECRET_FILE = "secrets/common.yaml"


def fail(msg: str, code: int = 1):
    print(f"ERROR: {msg}")
    sys.exit(code)


# Load secrets from sops
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

# OAuth token
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
        oauth = json.loads(r.read().decode())
except Exception as e:
    fail(f"oauth token request failed: {e}")

access_token = oauth.get("access_token", "")
if not access_token:
    fail("oauth response has no access_token")

print("OAuth token: OK")

acl_url = f"https://api.tailscale.com/api/v2/tailnet/{urllib.parse.quote(tailnet, safe='')}/acl"
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
}

# GET current ACL (Tailscale returns HuJSON, not strict JSON)
try:
    with urllib.request.urlopen(
        urllib.request.Request(acl_url, headers=headers, method="GET"), timeout=30
    ) as r:
        acl_raw = r.read().decode()
        print(f"ACL read: HTTP {r.status}")
except Exception as e:
    fail(f"ACL read failed: {e}")

# POST back exactly the same ACL text (no-op write test)
body = acl_raw.encode()
put_req = urllib.request.Request(acl_url, data=body, headers=headers, method="POST")

try:
    with urllib.request.urlopen(put_req, timeout=30) as r2:
        _ = r2.read().decode(errors="replace")
        print(f"ACL write(no-op): HTTP {r2.status}")
except urllib.error.HTTPError as e:
    resp = e.read().decode(errors="replace")
    fail(f"ACL write(no-op) failed HTTP {e.code}: {resp[:240]}", code=2)
except Exception as e:
    fail(f"ACL write(no-op) failed: {e}", code=2)

print("SUCCESS: OAuth client can READ+WRITE ACL policy")
