# 🏗️ nix-config

Configuration NixOS déclarative (flakes) pour une infrastructure Proxmox personnelle.

## 📋 Vue d'ensemble

Ce dépôt centralise la configuration de plusieurs VMs NixOS, des secrets via SOPS-Nix et des services auto‑hébergés. Objectif : reproductibilité, déploiement simple, documentation claire.

## 🖥️ Hôtes

| Hôte | Type | Rôle principal |
|------|------|---------------|
| **magnolia** 🌸 | Hyperviseur | Proxmox + base système |
| **mimosa** 🌼 | Site web | jeremiealcaraz.com (Caddy + Cloudflare Tunnel) |
| **whitelily** 🤍 | Automation | n8n + PostgreSQL + backups |
| **dandelion** 🌾 | Git | Gitea + PostgreSQL |
| **rhizanthella** 🌺 | BaaS | bknd + PostgreSQL |
| **minimal** 🔧 | Demo | VM minimaliste |

## 🗺️ Diagramme (VMs & interactions)

```mermaid
flowchart TD
    Internet((Internet))
    Proxmox["magnolia<br/>Proxmox"]

    subgraph VMs["VMs NixOS"]
        Mimosa["mimosa<br/>Caddy + Cloudflare Tunnel"]
        WhiteLily["whitelily<br/>n8n + PostgreSQL"]
        Dandelion["dandelion<br/>Gitea + PostgreSQL"]
        Rhizanthella["rhizanthella<br/>bknd + PostgreSQL"]
        Minimal["minimal<br/>VM demo"]
    end

    Tailscale["Tailscale mesh"]
    Cloudflare["Cloudflare Tunnel"]

    Proxmox --> Mimosa
    Proxmox --> WhiteLily
    Proxmox --> Dandelion
    Proxmox --> Rhizanthella
    Proxmox --> Minimal

    Internet --> Cloudflare --> Mimosa
    Tailscale --> WhiteLily
    Tailscale --> Dandelion
    Tailscale --> Rhizanthella
```

## 🚀 Démarrage rapide

```bash
sudo ./scripts/install-nixos.sh [magnolia|mimosa-bootstrap|whitelily|dandelion|rhizanthella|minimal]
```

```bash
sudo nixos-rebuild switch --flake .#magnolia
sudo nixos-rebuild switch --flake .#mimosa
sudo nixos-rebuild switch --flake .#whitelily
sudo nixos-rebuild switch --flake .#dandelion
sudo nixos-rebuild switch --flake .#rhizanthella
sudo nixos-rebuild switch --flake .#minimal
```

## 💿 ISO personnalisée

```bash
cd iso/
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage
```

Guide complet : [docs/ISO-BUILDER.md](docs/ISO-BUILDER.md)

## 📖 Docs utiles

- [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) : création d'une VM
- [docs/DEPLOY.md](docs/DEPLOY.md) : déploiement
- [docs/SECRETS.md](docs/SECRETS.md) : workflow SOPS
- [docs/WHITELILY-N8N-SETUP.md](docs/WHITELILY-N8N-SETUP.md) : n8n

## 🔐 Secrets

SOPS‑Nix + Age, secrets chiffrés par hôte, jamais en clair.
