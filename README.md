# 🏗️ nix-config

Configuration NixOS personnelle basée sur les flakes pour la gestion d'infrastructure Proxmox.

## 📋 Vue d'ensemble

Ce repository contient ma configuration NixOS déclarative pour gérer plusieurs hôtes virtuels sur Proxmox. Il s'agit d'un projet en développement (pour mise en production) qui met l'accent sur la sécurité, la reproductibilité et les bonnes pratiques modernes de NixOS.

### Caractéristiques principales

- 🔐 **Gestion sécurisée des secrets** avec SOPS-Nix (chiffrement Age)
- 🚀 **Architecture basée sur les flakes** pour une reproductibilité totale
- 🔑 **Authentification SSH par clés uniquement** (pas de mots de passe)
- 📦 **Multi-hôtes** avec configuration centralisée
- 🏠 **Home Manager** pour la gestion déclarative de l'environnement utilisateur
- 🔄 **Infrastructure as Code** avec historique Git complet
- 🐳 **Containerisation** avec Podman pour les services (n8n)
- 💿 **ISO minimale personnalisée** avec support console série pour Proxmox/NoVNC
- 📚 **Documentation détaillée** en français

## 🖥️ Hôtes configurés

| Hôte | Type | Description |
|------|------|-------------|
| **magnolia** 🌸 | Hyperviseur | Infrastructure Proxmox avec console série, QEMU Guest Agent, SSH par clés et Fish shell. Auto-navigation vers /etc/nixos lors de la connexion SSH. |
| **mimosa** 🌼 | Serveur Web | Serveur web complet avec j12zdotcom, Caddy, Cloudflare Tunnel, ports 80/443 automatiques et Fish shell. Auto-navigation vers /etc/nixos lors de la connexion SSH. |
| **whitelily** 🤍 | Automation | Service d'orchestration n8n avec Podman, PostgreSQL 16, Cloudflare Tunnel, backups automatiques et Fish shell. Architecture production-ready avec auto-navigation vers /etc/nixos. |
| **demo** 🎬 | Démonstration | Hôte de démonstration minimal avec Fish shell pour tests et expérimentations. Auto-navigation vers /etc/nixos lors de la connexion SSH. |

### 🏠 Gestion de l'environnement utilisateur avec Home Manager

Tous les hôtes utilisent **Home Manager** pour gérer de manière déclarative l'environnement utilisateur :

- **Shell unifié** : Fish shell déployé sur tous les hôtes pour une expérience cohérente
- **Auto-navigation SSH** : Changement automatique vers `/etc/nixos` lors de la connexion SSH
- **Messages personnalisés** : Banner de bienvenue adapté par hôte dans Fish shellInit
- **Prompt moderne** : Starship configuré pour tous les hôtes
- **Éditeur** : Vim comme éditeur par défaut

Configuration centralisée dans `home/jeremie.nix` avec logique conditionnelle par hostname. L'ancienne configuration ZSH est conservée en commentaire pour réutilisation future.

### ✨ WhiteLily - Architecture production-ready

**WhiteLily** est le dernier ajout au projet et représente une architecture complète pour un service n8n en production :

**Stack technique** :
- 🐳 **Podman** : Containerisation sans daemon (OCI compliant)
- 🗄️ **PostgreSQL 16** : Base de données robuste avec optimisations
- 🔄 **n8n** : Plateforme d'orchestration épinglée pour stabilité
- 🌐 **Caddy** : Reverse proxy avec compression automatique
- 🔒 **Cloudflare Tunnel** : Exposition sécurisée sans ports publics ouverts

**Fonctionnalités** :
- ✅ Zero-trust security (aucun port ouvert sur le firewall)
- ✅ Backups automatiques quotidiens (base de données + données n8n)
- ✅ Healthchecks toutes les 5 minutes
- ✅ Logs rotatifs automatiques
- ✅ TLS automatique via Cloudflare
- ✅ Configuration 100% déclarative et reproductible

**Documentation complète** : [docs/WHITELILY-N8N-SETUP.md](docs/WHITELILY-N8N-SETUP.md)

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
sudo nixos-rebuild switch --flake .#whitelily       # Automation n8n
sudo nixos-rebuild switch --flake .#demo            # VM de démonstration
```

**Note** : Pour whitelily, consultez le guide complet [docs/WHITELILY-N8N-SETUP.md](docs/WHITELILY-N8N-SETUP.md) qui détaille la configuration des secrets SOPS et du Cloudflare Tunnel.

## 📁 Structure du repository

```
nix-config/
├── flake.nix                    # Définition principale du flake
├── flake.lock                   # Versions verrouillées des dépendances
├── .sops.yaml                   # Configuration SOPS globale
├── hosts/                       # Configurations par hôte
│   ├── magnolia/                # Infrastructure Proxmox
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── mimosa/                  # Serveur web
│   │   ├── configuration.nix    # Configuration système de base
│   │   ├── webserver.nix        # Configuration serveur web
│   │   └── hardware-configuration.nix
│   ├── whitelily/               # Automation n8n
│   │   ├── configuration.nix    # Configuration système
│   │   ├── n8n.nix              # Configuration n8n + Podman
│   │   └── hardware-configuration.nix
│   └── demo/                    # VM de démonstration
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── home/                        # Configuration utilisateur Home Manager
│   └── jeremie.nix              # Environnement utilisateur (shells, vim, starship)
├── scripts/                     # Scripts d'installation et gestion
│   ├── install-nixos.sh         # Installation automatisée
│   └── activate-webserver.sh    # Activation du serveur web post-installation
├── iso/                         # Configuration ISO personnalisée
│   ├── flake.nix                # Builder ISO minimale avec TTY série
│   └── custom-installer.nix     # Configuration de l'installateur
├── secrets/                     # Gestion des secrets chiffrés
│   ├── README.md
│   └── *.yaml                   # Fichiers de secrets chiffrés par hôte
└── docs/                        # Documentation complète
    ├── BOOTSTRAP.md             # Guide d'initialisation des VMs
    ├── SECRETS.md               # Gestion des secrets avec SOPS
    ├── QUICKSTART-SOPS.md       # Démarrage rapide SOPS
    ├── SECURE-PASSWORDS.md      # Guide de gestion sécurisée des mots de passe
    ├── DEPLOY.md                # Guide de déploiement
    ├── ISO-BUILDER.md           # Guide de construction d'ISO personnalisée
    └── WHITELILY-N8N-SETUP.md   # Installation complète de whitelily (n8n)
```

## 📖 Documentation

Pour plus d'informations, consultez la documentation dans le dossier `docs/` :

### 🚀 Démarrage
- **[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)** - Guide complet pour initialiser une nouvelle VM
- **[docs/DEPLOY.md](docs/DEPLOY.md)** - Guide de déploiement des configurations
- **[docs/ISO-BUILDER.md](docs/ISO-BUILDER.md)** - Builder une ISO NixOS personnalisée pour Proxmox

### 🔐 Sécurité
- **[docs/SECRETS.md](docs/SECRETS.md)** - Gestion et rotation des clés de chiffrement
- **[docs/QUICKSTART-SOPS.md](docs/QUICKSTART-SOPS.md)** - Démarrage rapide avec SOPS
- **[docs/SECURE-PASSWORDS.md](docs/SECURE-PASSWORDS.md)** - Guide de gestion sécurisée des mots de passe

### 🖥️ Hôtes spécifiques
- **[docs/WHITELILY-N8N-SETUP.md](docs/WHITELILY-N8N-SETUP.md)** - Installation complète de whitelily (n8n)

## 🔐 Gestion des secrets

Ce projet utilise [SOPS-Nix](https://github.com/Mic92/sops-nix) pour chiffrer les secrets sensibles :

- Chiffrement basé sur Age (moderne et simple)
- Clés de chiffrement par hôte (basées sur les clés SSH des hôtes)
- Secrets déchiffrés automatiquement au déploiement
- Jamais de secrets en clair dans Git

Voir [docs/SECRETS.md](docs/SECRETS.md) pour le guide complet.

## 🛠️ Technologies utilisées

### Infrastructure et système
- **NixOS 24.11** - Système d'exploitation déclaratif et reproductible
- **Nix Flakes** - Gestion moderne des dépendances
- **Home Manager** - Gestion déclarative de l'environnement utilisateur
- **Proxmox** - Hyperviseur de virtualisation
- **QEMU Guest Agent** - Intégration VM/Hôte

### Sécurité
- **SOPS-Nix** - Gestion sécurisée des secrets (chiffrement Age)
- **SSH Keys** - Authentification par clés uniquement
- **Tailscale** - VPN mesh pour accès sécurisé
- **Cloudflare Tunnel** - Exposition sécurisée sans ports ouverts

### Services et applications
- **Podman** - Containerisation OCI (alternative à Docker)
- **n8n** - Plateforme d'orchestration et workflows
- **PostgreSQL 16** - Base de données relationnelle
- **Caddy** - Reverse proxy moderne avec HTTP/2
- **Cloudflared** - Client Cloudflare Tunnel

### Outils de développement
- **Git** - Contrôle de version et infrastructure as code
- **Fish + Starship** - Shell moderne et friendly déployé sur tous les hôtes
- **Vim** - Éditeur de texte par défaut

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
