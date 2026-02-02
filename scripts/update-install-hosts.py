#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path


def read_first_paragraph(path: Path) -> str:
    if not path.exists():
        return ""
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return ""
    lines = text.splitlines()
    paragraph_lines = []
    for line in lines:
        if not line.strip():
            break
        paragraph_lines.append(line.strip())
    paragraph = " ".join(paragraph_lines)
    paragraph = re.sub(r"\s+", " ", paragraph).strip()
    return paragraph


def truncate_words(text: str, limit: int) -> str:
    if not text:
        return ""
    words = text.split()
    return " ".join(words[:limit])


def load_existing_tsv(path: Path) -> tuple[list[str], dict[str, dict[str, str]]]:
    if not path.exists():
        return [], {}
    order: list[str] = []
    entries: dict[str, dict[str, str]] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        parts = raw.split("\t")
        parts += [""] * (6 - len(parts))
        host_id, target, label, description, hidden, tailscale_ip = parts[:6]
        order.append(host_id)
        entries[host_id] = {
            "id": host_id,
            "target": target,
            "label": label,
            "description": description,
            "hidden": hidden,
            "tailscale_ip": tailscale_ip,
        }
    return order, entries


def load_tailscale_map(enabled: bool) -> dict[str, str]:
    if not enabled:
        return {}
    try:
        result = subprocess.run(
            ["tailscale", "status", "--json"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("warning: tailscale status indisponible, IPs ignorées", file=sys.stderr)
        return {}

    data = json.loads(result.stdout)
    peers = data.get("Peer", {})
    self_info = data.get("Self", {})
    mapping: dict[str, str] = {}
    for peer in peers.values():
        host_name = peer.get("HostName", "")
        dns_name = peer.get("DNSName", "")
        tailscale_ips = peer.get("TailscaleIPs", [])
        if not tailscale_ips:
            continue
        ip = tailscale_ips[0]
        if host_name:
            mapping[host_name.lower()] = ip
        if dns_name:
            base = dns_name.split(".")[0].lower()
            mapping[base] = ip
    if self_info:
        host_name = self_info.get("HostName", "")
        dns_name = self_info.get("DNSName", "")
        tailscale_ips = self_info.get("TailscaleIPs", [])
        if tailscale_ips:
            ip = tailscale_ips[0]
            if host_name:
                mapping[host_name.lower()] = ip
            if dns_name:
                base = dns_name.split(".")[0].lower()
                mapping[base] = ip
    return mapping


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Met à jour scripts/install-hosts.tsv à partir des README des hôtes."
    )
    parser.add_argument("--tailscale", action="store_true", help="Inclure l'IP Tailscale si disponible")
    parser.add_argument("--dry-run", action="store_true", help="Affiche la sortie sans modifier le fichier")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    hosts_root = repo_root / "hosts"
    tsv_path = script_dir / "install-hosts.tsv"

    if not hosts_root.is_dir():
        print(f"error: dossier hosts introuvable: {hosts_root}", file=sys.stderr)
        return 1

    existing_order, existing_entries = load_existing_tsv(tsv_path)
    tailscale_map = load_tailscale_map(args.tailscale)

    host_dirs = sorted(
        [
            p
            for p in hosts_root.iterdir()
            if p.is_dir() and (p / "configuration.nix").exists()
        ],
        key=lambda p: p.name,
    )

    new_entries: dict[str, dict[str, str]] = {}
    for host_dir in host_dirs:
        host_id = host_dir.name
        readme_path = host_dir / "README.md"
        paragraph = read_first_paragraph(readme_path)
        description = truncate_words(paragraph, 30)

        previous = existing_entries.get(host_id, {})
        label = previous.get("label") or host_id.capitalize()
        target = previous.get("target") or host_id
        hidden = previous.get("hidden") or "false"
        tailscale_ip = previous.get("tailscale_ip") or ""

        mapped_ip = tailscale_map.get(host_id.lower())
        if mapped_ip:
            tailscale_ip = mapped_ip

        new_entries[host_id] = {
            "id": host_id,
            "target": target,
            "label": label,
            "description": description,
            "hidden": hidden,
            "tailscale_ip": tailscale_ip,
        }

    # Conserver les entrées existantes qui ne correspondent pas à un host (alias, masquage, etc.)
    for host_id, entry in existing_entries.items():
        if host_id not in new_entries:
            new_entries[host_id] = entry

    output_lines = []
    output_lines.append("# id\ttarget\tlabel\tdescription\thidden\ttailscale_ip")

    seen = set()
    for host_id in existing_order:
        entry = new_entries.get(host_id)
        if not entry:
            continue
        seen.add(host_id)
        output_lines.append(
            "\t".join(
                [
                    entry["id"],
                    entry["target"],
                    entry["label"],
                    entry["description"].replace("\t", " "),
                    entry["hidden"],
                    entry["tailscale_ip"],
                ]
            ).rstrip()
        )

    for host_id in sorted(new_entries.keys()):
        if host_id in seen:
            continue
        entry = new_entries[host_id]
        output_lines.append(
            "\t".join(
                [
                    entry["id"],
                    entry["target"],
                    entry["label"],
                    entry["description"].replace("\t", " "),
                    entry["hidden"],
                    entry["tailscale_ip"],
                ]
            ).rstrip()
        )

    output = "\n".join(output_lines).rstrip() + "\n"

    if args.dry_run:
        print(output)
        return 0

    tsv_path.write_text(output, encoding="utf-8")
    print(f"TSV mis à jour: {tsv_path}")

    if args.tailscale:
        try:
            status = subprocess.run(
                ["git", "status", "--porcelain", str(tsv_path)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        except (FileNotFoundError, subprocess.CalledProcessError):
            print("warning: git indisponible, commit/push ignorés", file=sys.stderr)
            return 0

        if status:
            try:
                subprocess.run(["git", "add", str(tsv_path)], check=True)
                subprocess.run(
                    ["git", "commit", "-m", "chore(install): update install-hosts.tsv"],
                    check=True,
                )
                subprocess.run(["git", "push"], check=True)
                print("Commit + push effectués.")
            except subprocess.CalledProcessError:
                print("warning: échec du commit/push", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
