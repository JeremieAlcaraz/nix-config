# 📚 Documentation nix-config

Bienvenue dans la documentation complète de ce repository NixOS.

## 🚀 Par où commencer ?

- **Premier déploiement** → [GETTING-STARTED.md](./GETTING-STARTED.md)
- **Déploiement complet** → [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Gestion des secrets** → [SECRETS.md](./SECRETS.md)

## 📖 Guides disponibles

### [MARIGOLD-PACKAGES.md](./MARIGOLD-PACKAGES.md)
**Ajouter un package sur Marigold (darwin)**

Guide court et pratique pour :
- Ajouter un CLI/TUI via Home Manager
- Ajouter une app GUI via Homebrew
- Ranger les configs dans `modules/dotfiles`

**Idéal pour** : Ajouter proprement des outils sur macOS

---

### [GETTING-STARTED.md](./GETTING-STARTED.md)
**Guide de démarrage rapide (10 minutes)**

Pour déployer rapidement votre première VM NixOS :
- Installation express avec script automatique
- Configuration minimale requise
- Premiers pas avec NixOS

**Idéal pour** : Débuter rapidement sans se noyer dans les détails

---

### [DEPLOYMENT.md](./DEPLOYMENT.md)
**Guide de déploiement complet**

Tout ce qu'il faut savoir sur le déploiement et la gestion de VMs NixOS :

#### Sections principales :
1. **Concepts & Philosophie**
   - Architecture du repository
   - Principes NixOS (labels standardisés, configuration déclarative)
   - Workflow recommandé

2. **Installation**
   - Installation fresh (depuis zéro)
   - Clonage de VM (recommandé)
   - Création de nouveaux hosts

3. **Déploiement de changements**
   - Workflow git + nixos-rebuild
   - Tests et rollbacks
   - Troubleshooting

4. **Services**
   - **n8n (whitelily)** : Guide production complet
     - Architecture NixOS + Podman + PostgreSQL + Caddy
     - Installation automatisée
     - Configuration GitHub Token pour auto-updates
     - Maintenance et monitoring
     - Backup et restauration

5. **Advanced**
   - Build d'ISO custom avec console série
   - Utilisation dans Proxmox/NoVNC

**Idéal pour** : Comprendre en profondeur le déploiement et gérer des services

---

### [SECRETS.md](./SECRETS.md)
**Guide de gestion des secrets avec sops-nix**

Gestion sécurisée des secrets (mots de passe, tokens, clés API) :

#### Sections principales :
1. **Quick Start** : Approche clé partagée (simple, idéal pour homelab)
2. **Configuration par host** : Clés individuelles par VM (production)
3. **Mots de passe sécurisés** : hashedPasswordFile + sops
4. **Troubleshooting** : Résolution des problèmes courants

**Idéal pour** : Sécuriser vos configurations sans exposer de secrets dans git

---

## 🏗️ Structure du repository

```
nix-config/
├── flake.nix              # Point d'entrée Nix Flakes
├── hosts/                 # Configurations par host
│   ├── magnolia/          # Infrastructure Proxmox
│   ├── mimosa/            # Serveur web
│   └── whitelily/         # n8n production
├── modules/               # Modules NixOS réutilisables
├── secrets/               # Secrets chiffrés avec sops
├── scripts/               # Scripts d'installation et maintenance
└── docs/                  # Documentation (vous êtes ici)
```

## 🎯 Workflows courants

### Déployer une nouvelle VM
```bash
# Méthode rapide (recommandée)
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh <hostname>
```

Voir [GETTING-STARTED.md](./GETTING-STARTED.md) pour les détails.

### Modifier une configuration existante
```bash
# 1. Sur votre Mac : éditer et pousser
vim hosts/mimosa/configuration.nix
git commit -am "Update mimosa config"
git push

# 2. Sur la VM : pull et rebuild
ssh jeremie@mimosa
cd /etc/nixos && git pull
sudo nixos-rebuild switch --flake .#mimosa
```

Voir [DEPLOYMENT.md](./DEPLOYMENT.md) pour le workflow complet.

### Gérer un secret
```bash
# Éditer un secret chiffré
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt
sops secrets/mimosa.yaml

# Commit et déployer
git add secrets/mimosa.yaml
git commit -m "🔒 Update secrets"
git push

ssh jeremie@mimosa "cd /etc/nixos && git pull && sudo nixos-rebuild switch --flake .#mimosa"
```

Voir [SECRETS.md](./SECRETS.md) pour la gestion complète.

## 🔑 Connexion aux VMs

### Par défaut sur toutes les VMs
- **Utilisateur** : `jeremie`
- **Mot de passe initial** : `nixos` (à changer après le premier boot)
- **SSH** : Authentification par clé publique uniquement
- **Sudo** : Pas de mot de passe requis (groupe `wheel`)

### Clé SSH autorisée
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
```

## 🆘 Besoin d'aide ?

| Problème | Solution |
|----------|----------|
| Première installation | [GETTING-STARTED.md](./GETTING-STARTED.md) |
| Erreur de déploiement | [DEPLOYMENT.md](./DEPLOYMENT.md) - Section Troubleshooting |
| Secret ne se déchiffre pas | [SECRETS.md](./SECRETS.md) - Section Troubleshooting |
| Service n8n ne démarre pas | [DEPLOYMENT.md](./DEPLOYMENT.md) - Section Services > n8n > Troubleshooting |

## 🤝 Contribution

Ce repository est personnel mais ouvert. N'hésitez pas à ouvrir une issue pour signaler des problèmes dans la documentation.

## 📜 License

MIT License - Libre d'utilisation et modification
