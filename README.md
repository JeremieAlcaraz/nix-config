# 🏗️ nix-config

Configuration NixOS déclarative (flakes) pour une infrastructure Proxmox personnelle.

## 📋 Vue d'ensemble

Ce dépôt centralise la configuration de plusieurs VMs NixOS, des secrets via SOPS-Nix et des services auto‑hébergés. Objectif : reproductibilité, déploiement simple, documentation claire.

## 🖥️ Hôtes

| Hôte | Type | Rôle principal |
|------|------|---------------|
| **magnolia** 🌸 | NixOS | Builder/déploiement + cache binaire Nix (`nix-serve`) |
| **hawthorn** 🌿 | NixOS | Gateway web (Caddy + Cloudflare Tunnel) |
| **mimosa** 🌼 | NixOS | Site jeremiealcaraz.com (app + docs) |
| **dandelion** 🌾 | NixOS | Forge Git Gitea + PostgreSQL + runners |
| **whitelily** 🤍 | NixOS | Automations n8n + PostgreSQL |
| **rhizanthella** 🌺 | NixOS | Backend-as-a-Service `bknd` + PostgreSQL |
| **myosotis** 🟦 | NixOS | Observabilité (Grafana + Loki + VictoriaMetrics) |
| **marigold** 🌼 | macOS (nix-darwin) | Poste principal de dev/admin |

Noeuds Proxmox (inventaire infra): **muscari** (héberge `magnolia`, `mimosa`, `dandelion`, `hawthorn`) et **crocus** (héberge `whitelily`, `rhizanthella`, `myosotis`).

## 🗺️ Diagramme (architecture actuelle)

```mermaid
flowchart LR
    Internet((Internet))
    Cloudflare["Cloudflare"]
    Tailnet["Tailscale tailnet"]

    subgraph MUSCARI["muscari - Proxmox node"]
        Magnolia["magnolia<br/>Builder + Cache Nix"]
        Hawthorn["hawthorn<br/>Gateway Caddy + Tunnel"]
        Mimosa["mimosa<br/>Site web + docs"]
        Dandelion["dandelion<br/>Gitea + PostgreSQL"]
    end

    subgraph CROCUS["crocus - Proxmox node"]
        WhiteLily["whitelily<br/>n8n + PostgreSQL"]
        Rhizanthella["rhizanthella<br/>bknd + PostgreSQL"]
        Myosotis["myosotis<br/>Grafana + Loki + VictoriaMetrics"]
    end

    Marigold["marigold<br/>macOS nix-darwin"]

    Internet --> Cloudflare
    Cloudflare --> Hawthorn
    Hawthorn --> Mimosa
    Cloudflare --> WhiteLily

    Tailnet --- Magnolia
    Tailnet --- Hawthorn
    Tailnet --- Mimosa
    Tailnet --- Dandelion
    Tailnet --- WhiteLily
    Tailnet --- Rhizanthella
    Tailnet --- Myosotis
    Tailnet --- Marigold

    Magnolia -. "cache nix-serve:5000" .-> Hawthorn
    Magnolia -. "cache nix-serve:5000" .-> Mimosa
    Magnolia -. "cache nix-serve:5000" .-> Dandelion
    Magnolia -. "cache nix-serve:5000" .-> WhiteLily
    Magnolia -. "cache nix-serve:5000" .-> Rhizanthella
    Magnolia -. "cache nix-serve:5000" .-> Myosotis

    Hawthorn -. "logs + metrics" .-> Myosotis
    Mimosa -. "logs + metrics" .-> Myosotis
    Dandelion -. "logs + metrics" .-> Myosotis
    WhiteLily -. "logs + metrics" .-> Myosotis
    Rhizanthella -. "logs + metrics" .-> Myosotis
    Magnolia -. "logs + metrics" .-> Myosotis
```

## 🚀 Démarrage rapide

```bash
sudo ./scripts/install-nixos.sh          # menu interactif (cibles décrites dans scripts/install-hosts.tsv)
sudo ./scripts/install-nixos.sh --list   # affiche toutes les cibles connues (masquées incluses)
sudo ./scripts/install-nixos.sh mimosa-bootstrap
```

Les cibles visibles sont définies automatiquement à partir des dossiers `hosts/`. Les métadonnées (ordre, descriptions, alias, masquage de `marigold`, etc.) se trouvent dans `scripts/install-hosts.tsv` ; ajoutez-y une ligne pour ajouter un alias ou masquer une cible du menu sans toucher au script.

Mise a jour rapide du catalogue:
```bash
./scripts/update-install-hosts.py
./scripts/update-install-hosts.py --tailscale
```

## 💿 ISO personnalisée

```bash
cd iso/
nix build .#nixosConfigurations.iso-installer-ttyS0.config.system.build.isoImage
```

Guide complet : [docs/ISO-BUILDER.md](docs/ISO-BUILDER.md)

## 📖 Docs utiles

- [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) : création d'une VM
- [docs/DEPLOY.md](docs/DEPLOY.md) : déploiement
- [docs/SECRETS.md](docs/SECRETS.md) : workflow SOPS
- [docs/WHITELILY-N8N-SETUP.md](docs/WHITELILY-N8N-SETUP.md) : n8n

## 🔐 Secrets

SOPS‑Nix + Age, secrets chiffrés par hôte, jamais en clair.
