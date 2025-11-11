# 🏗️ nix-config

Configuration NixOS personnelle basée sur les flakes pour la gestion d'infrastructure Proxmox.

## 📋 Vue d'ensemble

Ce repository contient ma configuration NixOS déclarative pour gérer plusieurs hôtes virtuels sur Proxmox. Il s'agit d'un projet d'apprentissage ("Learnix") qui met l'accent sur la sécurité, la reproductibilité et les bonnes pratiques modernes de NixOS.

### Caractéristiques principales

- 🔐 **Gestion sécurisée des secrets** avec SOPS-Nix (chiffrement Age)
- 🚀 **Architecture basée sur les flakes** pour une reproductibilité totale
- 🔑 **Authentification SSH par clés uniquement** (pas de mots de passe)
- 📦 **Multi-hôtes** avec configuration centralisée
- 🔄 **Infrastructure as Code** avec historique Git complet
- 💿 **ISO minimale personnalisée** avec support console série pour Proxmox/NoVNC
- 📚 **Documentation détaillée** en français

## 🖥️ Hôtes configurés

### `magnolia` 🌸
Hôte hyperviseur Proxmox avec configuration minimale (anciennement `proxmox`).

**Caractéristiques :**
- Console série pour accès Proxmox
- QEMU Guest Agent
- SSH avec authentification par clés
- Outils de base : vim, git, curl, wget, htop, tmux

### `mimosa` 🌼
Serveur web avec fonctionnalités avancées (anciennement `jeremie-web`).

**Deux configurations disponibles :**

#### `mimosa-minimal` (Installation initiale)
Configuration système de base sans le serveur web, utilisée pendant l'installation pour éviter les problèmes réseau liés aux téléchargements npm.

**Caractéristiques :**
- Configuration système minimale
- Tailscale VPN
- Configuration Git
- Sudo sans mot de passe
- QEMU Guest Agent

#### `mimosa` (Production)
Configuration complète incluant le serveur web j12zdotcom.

**Caractéristiques supplémentaires :**
- Site web j12zdotcom (Astro + pnpm)
- Caddy (reverse proxy)
- Cloudflare Tunnel
- Ports 80, 443 ouverts automatiquement

## 💿 ISO personnalisée

Une ISO NixOS minimale optimisée pour Proxmox/NoVNC avec :

- ✅ **Console série (ttyS0)** activée automatiquement
- ✅ **Environnement X11 minimal** (xterm + twm)
- ✅ **ZSH + Starship** pour un shell moderne
- ✅ **Autologin** (utilisateur `nixos`)
- ✅ **SSH et réseau DHCP** préconfigurés

**Builder l'ISO :**
```bash
cd iso/
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage
# L'ISO se trouve dans : result/iso/nixos-minimal-ttyS0.iso
```

📖 **Guide complet :** [docs/ISO-BUILDER.md](docs/ISO-BUILDER.md)

## 🚀 Démarrage rapide

### Prérequis

- NixOS avec support des flakes activé
- Clés SSH configurées
- (Pour SOPS) Clés Age générées

### Installation automatisée

Le projet inclut un script d'installation automatisé pour faciliter le déploiement :

```bash
# Depuis l'ISO NixOS ou un environnement d'installation
sudo ./scripts/install-nixos.sh [magnolia|mimosa]
```

**Pour mimosa**, deux modes d'installation sont disponibles :

1. **Installation complète** (mode 1) - Télécharge et active immédiatement le serveur web
2. **Installation minimale** (mode 2) - Installation système uniquement, serveur web activable après

Pour activer le serveur web après une installation minimale :

```bash
# Après le premier boot
ssh jeremie@<IP>
cd /etc/nixos/scripts
sudo ./activate-webserver.sh
```

### Déploiement manuel

```bash
# Cloner le repository
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config

# Construire et activer la configuration pour un hôte
sudo nixos-rebuild switch --flake .#magnolia        # Infrastructure Proxmox
sudo nixos-rebuild switch --flake .#mimosa-minimal  # Serveur web (minimal)
sudo nixos-rebuild switch --flake .#mimosa          # Serveur web (complet)
```

## 📁 Structure du repository

```
nix-config/
├── flake.nix                    # Définition principale du flake
├── flake.lock                   # Versions verrouillées des dépendances
├── hosts/                       # Configurations par hôte
│   ├── magnolia/                # Infrastructure Proxmox (ex-proxmox)
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── mimosa/                  # Serveur web (ex-jeremie-web)
│       ├── configuration.nix    # Configuration système de base
│       ├── webserver.nix        # Configuration serveur web (mimosa uniquement)
│       └── hardware-configuration.nix
├── scripts/                     # Scripts d'installation et gestion
│   ├── install-nixos.sh         # Installation automatisée
│   └── activate-webserver.sh    # Activation du serveur web post-installation
├── iso/                         # Configuration ISO personnalisée
│   └── flake.nix                # Builder ISO minimale avec TTY série
├── secrets/                     # Gestion des secrets chiffrés
│   ├── README.md
│   ├── .sops.yaml
│   └── *.yaml                   # Fichiers de secrets chiffrés
└── docs/                        # Documentation complète
    ├── BOOTSTRAP.md             # Guide d'initialisation des VMs
    ├── SECRETS.md               # Gestion des secrets avec SOPS
    └── ISO-BUILDER.md           # Guide de construction d'ISO personnalisée
```

## 📖 Documentation

Pour plus d'informations, consultez la documentation dans le dossier `docs/` :

- **[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)** - Guide complet pour initialiser une nouvelle VM
- **[docs/SECRETS.md](docs/SECRETS.md)** - Gestion et rotation des clés de chiffrement
- **[docs/ISO-BUILDER.md](docs/ISO-BUILDER.md)** - Builder une ISO NixOS personnalisée pour Proxmox

## 🔐 Gestion des secrets

Ce projet utilise [SOPS-Nix](https://github.com/Mic92/sops-nix) pour chiffrer les secrets sensibles :

- Chiffrement basé sur Age (moderne et simple)
- Clés de chiffrement par hôte (basées sur les clés SSH des hôtes)
- Secrets déchiffrés automatiquement au déploiement
- Jamais de secrets en clair dans Git

Voir [docs/SECRETS.md](docs/SECRETS.md) pour le guide complet.

## 🛠️ Technologies utilisées

- **NixOS** - Système d'exploitation déclaratif et reproductible
- **Nix Flakes** - Gestion moderne des dépendances
- **SOPS-Nix** - Gestion sécurisée des secrets
- **Tailscale** - VPN mesh pour accès sécurisé
- **Proxmox** - Hyperviseur de virtualisation
- **Git** - Contrôle de version et infrastructure as code

## 📝 Conventions

Ce projet suit les conventions suivantes :

- **Commits** : Utilisation des gitmojis pour les messages de commit
- **Documentation** : En français, détaillée et pédagogique
- **Sécurité** : Authentification par clés SSH uniquement, secrets chiffrés
- **Reproductibilité** : Configuration entièrement déclarative

## 🤝 Contribution

Ce repository est un projet personnel d'apprentissage, mais les suggestions et contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## 📄 Licence

Ce projet est personnel et à usage pédagogique. Libre d'utilisation pour inspiration.

---

**Note** : Ce projet est en évolution constante dans le cadre de mon apprentissage de NixOS et de la gestion d'infrastructure déclarative.
