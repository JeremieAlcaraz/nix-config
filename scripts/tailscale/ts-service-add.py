#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SERVICES_FILE = ROOT / "ops/tailscale/services.json"
POLICY_SYNC = ROOT / "scripts/tailscale/ts-policy-sync.py"
SERVE_HOST = ROOT / "scripts/tailscale/ts-serve-on-host.sh"
SERVICE_ENSURE = ROOT / "scripts/tailscale/ts-service-ensure.py"


def run(cmd: list[str]):
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def load_services() -> dict:
    if not SERVICES_FILE.exists():
        return {"services": []}
    return json.loads(SERVICES_FILE.read_text())


def save_services(payload: dict):
    SERVICES_FILE.parent.mkdir(parents=True, exist_ok=True)
    SERVICES_FILE.write_text(json.dumps(payload, indent=2) + "\n")


def upsert_service(payload: dict, name: str, host: str, port: int, tag: str) -> bool:
    services = payload.setdefault("services", [])
    changed = False
    for svc in services:
        if svc.get("name") == name:
            desired = {
                "name": name,
                "host": host,
                "port": port,
                "autoApproveTag": tag,
            }
            if svc != desired:
                svc.clear()
                svc.update(desired)
                changed = True
            return changed

    services.append(
        {
            "name": name,
            "host": host,
            "port": port,
            "autoApproveTag": tag,
        }
    )
    return True


def main():
    parser = argparse.ArgumentParser(description="Add/update a Tailscale service and publish it")
    parser.add_argument("service", help="service name, without svc: prefix")
    parser.add_argument("host", help="SSH host where tailscale serve should run")
    parser.add_argument("port", type=int, help="local port on host")
    parser.add_argument("--tag", default="tag:newmachine", help="auto-approver tag")
    parser.add_argument("--no-apply", action="store_true", help="do not push ACL policy")
    args = parser.parse_args()

    service = args.service.replace("svc:", "")

    payload = load_services()
    changed = upsert_service(payload, service, args.host, args.port, args.tag)
    if changed:
        save_services(payload)
        print(f"Updated {SERVICES_FILE} with service '{service}'")
    else:
        print(f"Service '{service}' already up to date in {SERVICES_FILE}")

    cmd = [str(POLICY_SYNC), "--service", service]
    if not args.no_apply:
        cmd.append("--apply")
    run(cmd)

    ensure_cmd = [str(SERVICE_ENSURE), service, "443"]
    run(ensure_cmd)

    run([str(SERVE_HOST), args.host, service, str(args.port)])

    print("Done.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"ERROR: command failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
