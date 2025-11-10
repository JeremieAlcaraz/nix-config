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

### `proxmox`
Hôte hyperviseur Proxmox avec configuration minimale.

**Caractéristiques :**
- Console série pour accès Proxmox
- QEMU Guest Agent
- SSH avec authentification par clés
- Outils de base : vim, git, curl, wget, htop, tmux

### `jeremie-web`
Serveur web avec fonctionnalités avancées.

**Caractéristiques :**
- Tailscale VPN pour accès sécurisé
- Configuration Git globale
- Sudo sans mot de passe
- QEMU Guest Agent

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

### Déploiement

```bash
# Cloner le repository
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config

# Construire et activer la configuration pour un hôte
sudo nixos-rebuild switch --flake .#proxmox
# ou
sudo nixos-rebuild switch --flake .#jeremie-web
```

## 📁 Structure du repository

```
nix-config/
├── flake.nix                    # Définition principale du flake
├── flake.lock                   # Versions verrouillées des dépendances
├── hosts/                       # Configurations par hôte
│   ├── proxmox/
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── jeremie-web/
│       ├── configuration.nix
│       └── hardware-configuration.nix
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
