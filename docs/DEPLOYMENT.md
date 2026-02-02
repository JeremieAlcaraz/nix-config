# 📘 Guide de Déploiement NixOS

Guide complet pour créer, déployer et gérer des VMs NixOS de manière **100% reproductible**.

## 📋 Table des matières

1. [Concepts & Philosophie](#concepts--philosophie)
2. [Installation](#installation)
   - [Fresh Install (depuis zéro)](#fresh-install-depuis-zéro)
   - [Clonage de VM (recommandé)](#clonage-de-vm-recommandé)
   - [Créer un nouvel host](#créer-un-nouvel-host)
3. [Déploiement de changements](#déploiement-de-changements)
4. [Services](#services)
   - [n8n (whitelily)](#n8n-whitelily)
5. [Advanced](#advanced)
   - [Build ISO custom](#build-iso-custom)
6. [Troubleshooting](#troubleshooting)

---

# Concepts & Philosophie

## 🎯 Principes de base

Ce repository utilise une approche **standardisée** pour toutes les VMs :
- **Labels de disque fixes** : `nixos-root` (partition racine) et `ESP` (partition boot)
- **Configuration déclarative** : Tout est dans le code, rien n'est manuel
- **Clonage facile** : Les VMs peuvent être clonées sans modification
- **Flakes** : Gestion moderne des dépendances Nix

## 🔐 Philosophie de sécurité

### Gestion des mots de passe

En NixOS, on utilise **`initialPassword`** pour le bootstrap :
- ✅ Définit un mot de passe **uniquement lors de la première création**
- ✅ N'est **jamais réécrit** lors des déploiements suivants
- ✅ Permet de bootstrap la VM avant d'activer `wheelNeedsPassword = false`
- ✅ Évite le problème de la poule et l'œuf

**Workflow :**
1. Premier boot : `initialPassword = "nixos"` permet la connexion initiale
2. Après bootstrap : SSH avec clé publique + sudo sans mot de passe
3. Le mot de passe initial reste actif (pour dépannage si besoin)

Pour une sécurité maximale en production, voir [SECRETS.md](./SECRETS.md) pour utiliser `hashedPasswordFile` + sops.

## 🏗️ Architecture du repository

```
nix-config/
├── flake.nix              # Point d'entrée Nix Flakes
├── hosts/                 # Configurations par host
│   ├── magnolia/          # Infrastructure Proxmox
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── mimosa/            # Serveur web
│   └── whitelily/         # n8n production
├── modules/               # Modules NixOS réutilisables
├── secrets/               # Secrets chiffrés avec sops
│   ├── magnolia.yaml.example
│   ├── mimosa.yaml.example
│   └── whitelily.yaml.example
├── scripts/               # Scripts d'installation et maintenance
│   └── install-nixos.sh   # Installation automatique
└── docs/                  # Documentation
```

## 📏 Standards de configuration

### Labels de disque standardisés

**TOUTES les VMs de ce repo utilisent les mêmes labels** :
- `/dev/disk/by-label/nixos-root` → Partition racine (ext4)
- `/dev/disk/by-label/ESP` → Partition boot (FAT32)

✅ **Avantage** : Les VMs peuvent être clonées sans modifier `hardware-configuration.nix`
❌ **Ne jamais** utiliser d'autres labels (comme `nixos` ou `boot`)

### Hostname vs Configuration

Le **hostname de la VM** doit correspondre au **nom dans flake.nix** :

| Hostname dans Proxmox | Commande nixos-rebuild | Fichier config |
|----------------------|------------------------|----------------|
| `magnolia` | `--flake .#magnolia` | `hosts/magnolia/` |
| `mimosa` | `--flake .#mimosa` | `hosts/mimosa/` |
| `whitelily` | `--flake .#whitelily` | `hosts/whitelily/` |

---

# Installation

## Fresh Install (depuis zéro)

### Prérequis

- VM créée dans Proxmox avec au minimum :
  - 2 CPU, 2 Go RAM, 32 Go de disque
  - Boot UEFI activé
  - ISO NixOS bootée

### Installation automatique avec le script

```bash
# 1. Depuis l'ISO NixOS, télécharger le script
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh

# 2. Lancer l'installation (remplacer HOST par magnolia, mimosa, etc.)
sudo ./install.sh <hostname>
```

Le script va :
1. ✅ Partitionner le disque avec les labels standards
2. ✅ Formater en ext4 + FAT32
3. ✅ Cloner ce repository
4. ✅ Installer NixOS avec la config de l'host choisi
5. ✅ Tout nettoyer

### Après l'installation

```bash
# 1. Retirer l'ISO dans Proxmox (Hardware > CD/DVD > Remove)
# 2. Redémarrer
reboot

# 3. Trouver l'IP de la VM
ip a

# 4. Se connecter depuis votre Mac/PC
ssh jeremie@<IP_DE_LA_VM>
```

**Mot de passe initial** : `nixos` (changez-le immédiatement avec `passwd`)

---

## Clonage de VM (recommandé)

**C'est le workflow le plus rapide et le plus fiable !**

### Étape 1 : Cloner la VM dans Proxmox

1. Dans Proxmox, faites un clic droit sur une VM existante (ex: `magnolia`)
2. Cliquez sur **"Clone"**
3. Choisissez :
   - **Mode** : Full Clone (clone complet)
   - **Nom** : Le nouveau nom (ex: `mimosa`)
   - **VM ID** : Un ID libre

### Étape 2 : Démarrer et reconfigurer

```bash
# 1. Démarrer la VM clonée dans Proxmox

# 2. Se connecter en SSH (utilisez l'IP de la nouvelle VM)
ssh jeremie@<IP_NOUVELLE_VM>

# 3. Aller dans /etc/nixos (le repo est déjà là !)
cd /etc/nixos

# 4. Pull les dernières modifications
git pull

# 5. Appliquer la nouvelle configuration
sudo nixos-rebuild switch --flake .#<nouveau-hostname>

# 6. Redémarrer pour que le hostname soit appliqué
sudo reboot
```

### Étape 3 : Vérification

```bash
# Se reconnecter
ssh jeremie@<IP_NOUVELLE_VM>

# Vérifier le hostname
hostnamectl
# Devrait afficher : Static hostname: <nouveau-hostname>

# Vérifier la config
cat /etc/nixos/hosts/<nouveau-hostname>/configuration.nix | grep hostName
```

### ⚠️ Important : Régénérer les clés SSH

Lorsque tu clones une VM dans Proxmox, les clés SSH de l'hôte sont également clonées.
**C'est un problème de sécurité !**

**Solution** : Après avoir cloné, régénérer les clés :

```bash
# 1. Console Proxmox, boot la VM clonée, connecte-toi en root

# 2. Supprimer les anciennes clés SSH de l'hôte
sudo rm /etc/ssh/ssh_host_*

# 3. Régénérer les clés SSH
sudo ssh-keygen -A

# 4. Redéployer pour que sops-nix utilise les nouvelles clés
cd /etc/nixos
sudo nixos-rebuild switch --flake .#<nouveau-hostname>

# 5. Récupérer la nouvelle clé age pour sops (si nécessaire)
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"
```

Ensuite, mettre à jour `.sops.yaml` avec la nouvelle clé publique age et re-chiffrer les secrets.

---

## Créer un nouvel host

### 1. Créer la structure de base

```bash
# Créer le dossier
mkdir -p hosts/mon-nouveau-host

# Copier les fichiers depuis un host existant
cp hosts/mimosa/configuration.nix hosts/mon-nouveau-host/
cp hosts/mimosa/hardware-configuration.nix hosts/mon-nouveau-host/
```

### 2. Modifier la configuration

```bash
# Éditer configuration.nix
vim hosts/mon-nouveau-host/configuration.nix

# Changer au minimum :
networking.hostName = "mon-nouveau-host";
```

### 3. Ajouter dans flake.nix

```nix
nixosConfigurations = {
  # ... configurations existantes ...

  mon-nouveau-host = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ./hosts/mon-nouveau-host/configuration.nix
      # Ajoutez les modules nécessaires (sops-nix, etc.)
    ];
  };
};
```

### 4. Déployer

```bash
# Méthode 1 : Installation depuis zéro
sudo ./scripts/install-nixos.sh mon-nouveau-host

# Méthode 2 : Depuis une VM clonée
sudo nixos-rebuild switch --flake .#mon-nouveau-host
```

---

# Déploiement de changements

## Workflow git + nixos-rebuild

Une fois la VM installée/clonée, voici comment déployer des modifications :

### Depuis votre Mac/PC (développement)

```bash
# 1. Faire vos modifications dans le repo local
cd ~/nix-config
vim hosts/mimosa/configuration.nix

# 2. Commit et push
git add .
git commit -m "Update mimosa config"
git push
```

### Depuis la VM (déploiement)

**Pour les nœuds follower (whitelily, mimosa, etc.)** :

```bash
# 1. Se connecter à la VM
ssh jeremie@<IP_DE_LA_VM>

# 2. Mise à jour forcée (écrase les modifications locales)
cd /etc/nixos
gu  # Alias pour: git fetch --all; and git reset --hard origin/main

# 3. Tester la config avant de l'appliquer (optionnel)
sudo nixos-rebuild test --flake .#<hostname>

# 4. Appliquer définitivement
sudo nixos-rebuild switch --flake .#<hostname>
```

**Pour le nœud de développement (magnolia uniquement)** :

```bash
# 1. Se connecter à la VM
ssh jeremie@<IP_DE_LA_VM>

# 2. Pull les changements (avec gestion des conflits)
cd /etc/nixos
git pull

# 3. Tester la config avant de l'appliquer (optionnel)
sudo nixos-rebuild test --flake .#<hostname>

# 4. Appliquer définitivement
sudo nixos-rebuild switch --flake .#<hostname>
```

**Note** : La plupart des changements sont appliqués immédiatement. Seuls quelques paramètres (comme le hostname) nécessitent un redémarrage.

## Tests et rollbacks

NixOS garde automatiquement les générations précédentes :

```bash
# Lister les générations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback à la génération précédente
sudo nixos-rebuild switch --rollback

# Rollback à une génération spécifique (ex: 42)
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation 42
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

# Services

## n8n (whitelily)

Guide complet pour déployer **whitelily**, une VM NixOS dédiée à n8n avec une architecture production-ready.

### 🏗️ Architecture

- **OS** : NixOS 24.11 (configuration 100% déclarative)
- **Container** : Podman (OCI containers)
- **Application** : n8n (version épinglée pour stabilité)
- **Base de données** : PostgreSQL 16
- **Reverse proxy** : Caddy (HTTP/2, compression automatique)
- **Exposition** : Cloudflare Tunnel (zero trust, aucun port public ouvert)
- **Secrets** : sops-nix avec clé age partagée
- **Backups** : Automatiques quotidiens (DB + données)

### ✨ Fonctionnalités

- ✅ Zéro port public ouvert (firewall actif)
- ✅ TLS automatique via Cloudflare
- ✅ Authentification basique n8n
- ✅ Chiffrement des credentials n8n
- ✅ PostgreSQL avec optimisations
- ✅ Backups automatiques quotidiens
- ✅ Healthchecks toutes les 5 minutes
- ✅ Logs rotatifs automatiques
- ✅ Configuration reproductible à 100%

### 🚀 Installation rapide (1 étape, 15 min)

#### Prérequis

- ✅ Serveur Proxmox avec ISO NixOS 24.11
- ✅ Compte Cloudflare avec domaine
- ✅ Clé age partagée (voir [SECRETS.md](./SECRETS.md))

#### Installation automatique

**1. Sur Proxmox** : Créer une VM nommée `whitelily`
   - 2 CPU, 4GB RAM, 32GB disque
   - Boot sur ISO NixOS 24.11

**2. Dans la console VM** :
```bash
# Télécharger et lancer le script all-in-one
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh whitelily
```

**3. Suivre l'assistant interactif** :

Le script va te demander :
- Branche git (défaut: `main`)
- Confirmation effacement disque
- Mot de passe SSH pour `jeremie`
- Nom d'utilisateur n8n (défaut: `admin`)
- Domaine (ex: `n8n.votredomaine.com`)
- Token Cloudflare Tunnel (la chaîne qui commence par "eyJ...")

Le script fait ensuite **TOUT automatiquement** :
- ✅ Partitionne et formate le disque
- ✅ Génère `hardware-configuration.nix`
- ✅ Clone la configuration
- ✅ Génère tous les secrets n8n (mot de passe, encryption key, JWT secret)
- ✅ Chiffre les secrets avec sops
- ✅ Installe NixOS
- ✅ Éteint la VM

**4. Sur Proxmox** : Détacher l'ISO et redémarrer
```bash
qm set <VMID> --ide2 none
qm start <VMID>
```

**C'est terminé ! 🎉**

Accéder à n8n : `https://n8n.votredomaine.com`

Les credentials ont été affichées pendant l'installation.

### 📝 Note importante

Le script affiche **toutes les credentials générées** avant de continuer :
- Domaine n8n
- Utilisateur n8n
- Mot de passe n8n
- Clé de chiffrement n8n (à sauvegarder dans 1Password/Bitwarden !)

**Sauvegardez ces informations** avant que le script ne continue.

### 🔧 Configuration GitHub Token (Auto-updates)

Pour activer les mises à jour automatiques de n8n via GitHub Actions :

#### 1. Créer un Personal Access Token GitHub

1. Aller sur : **https://github.com/settings/tokens/new**
2. Configurer :
   - **Note** : `n8n auto-update workflow`
   - **Expiration** : `No expiration` ou `1 year`
   - **Scopes** : Cocher uniquement `repo` (Full control)
3. Cliquer **Generate token**
4. **⚠️ COPIER IMMÉDIATEMENT** le token (commence par `ghp_...`)

#### 2. Ajouter le token dans sops

```bash
# Sur votre Mac
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/whitelily.yaml

# Ajouter ou modifier :
# github:
#   token: "ghp_votre_token_ici"

# Sauvegarder et quitter
```

#### 3. Ajouter le token dans GitHub Secrets

1. Aller dans votre repository sur GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Cliquer **New repository secret**
4. Créer :
   - **Name** : `N8N_UPDATE_TOKEN`
   - **Secret** : Coller le token (commence par `ghp_...`)
5. Cliquer **Add secret**

#### 4. Workflow d'auto-update

Une fois configuré, le workflow GitHub Actions :
1. ✅ Vérifie quotidiennement Docker Hub pour `n8n:next`
2. ✅ Détecte les nouvelles versions
3. ✅ Crée automatiquement une branche `update/n8n-next-XXX`
4. ✅ Crée une Pull Request avec les changements
5. ✅ Vous reviewez et mergez manuellement

#### Troubleshooting GitHub Token

**Erreur `403 Forbidden` ou `Resource not accessible`**

Causes possibles :
1. Token expiré → Vérifier sur https://github.com/settings/tokens
2. Permissions insuffisantes → Vérifier que `repo` est coché
3. Token non configuré dans GitHub Secrets → Vérifier dans Settings → Secrets
4. Token révoqué → Créer un nouveau token

**Tester la validité du token :**
```bash
curl -H "Authorization: token ghp_votre_token" https://api.github.com/user

# Si erreur 401 : token invalide ou révoqué
# Si erreur 403 : permissions insuffisantes
# Si succès (200) : le token fonctionne
```

### 🔄 Maintenance

#### Vérifier l'état des services

```bash
# Statut n8n
sudo systemctl status podman-n8n

# Statut PostgreSQL
sudo systemctl status postgresql

# Statut Cloudflare Tunnel
sudo systemctl status cloudflared-tunnel-n8n

# Statut Caddy
sudo systemctl status caddy
```

#### Consulter les logs

```bash
# Logs n8n
sudo journalctl -u podman-n8n -f

# Logs PostgreSQL
sudo journalctl -u postgresql -f

# Logs Cloudflare
sudo journalctl -u cloudflared-tunnel-n8n -f

# Logs Caddy
sudo journalctl -u caddy -f
```

#### Redémarrer les services

```bash
# Redémarrer n8n
sudo systemctl restart podman-n8n

# Redémarrer PostgreSQL
sudo systemctl restart postgresql

# Redémarrer Cloudflare Tunnel
sudo systemctl restart cloudflared-tunnel-n8n

# Redémarrer Caddy
sudo systemctl restart caddy
```

#### Mettre à jour n8n manuellement

```bash
# Éditer la configuration
vim /etc/nixos/hosts/whitelily/configuration.nix

# Changer la version
# image = "docker.io/n8nio/n8n:1.XX.X";

# Redéployer
sudo nixos-rebuild switch --flake /etc/nixos#whitelily
```

### 💾 Backup et restauration

#### Backups automatiques

Les backups PostgreSQL sont automatiques et quotidiens :
- **Localisation** : `/var/backup/postgresql/`
- **Format** : `n8n_backup_YYYY-MM-DD_HH-MM-SS.sql`
- **Rétention** : 7 jours (configurable)

#### Backup manuel

```bash
# Backup PostgreSQL
sudo -u postgres pg_dump n8n > /tmp/n8n_backup_$(date +%Y-%m-%d).sql

# Backup données n8n (workflows, credentials)
sudo podman exec n8n-container n8n export:workflow --all --output=/tmp/n8n_workflows.json
```

#### Restauration

```bash
# Restaurer PostgreSQL
sudo systemctl stop podman-n8n
sudo -u postgres psql -d n8n < /var/backup/postgresql/n8n_backup_YYYY-MM-DD.sql
sudo systemctl start podman-n8n

# Restaurer workflows
sudo podman exec n8n-container n8n import:workflow --input=/tmp/n8n_workflows.json
```

### 🐛 Troubleshooting n8n

#### n8n ne démarre pas

**Vérifier les logs :**
```bash
sudo journalctl -u podman-n8n -n 100
```

**Causes fréquentes :**
1. PostgreSQL pas démarré → `sudo systemctl start postgresql`
2. Secret non déchiffré → Vérifier `/run/secrets/` et [SECRETS.md](./SECRETS.md)
3. Port déjà utilisé → `sudo ss -tlnp | grep 5678`

#### n8n injoignable via Cloudflare

**Vérifier Cloudflare Tunnel :**
```bash
sudo journalctl -u cloudflared-tunnel-n8n -f
```

**Vérifier Caddy :**
```bash
sudo systemctl status caddy
curl -I http://localhost:5678
```

**Causes fréquentes :**
1. Token Cloudflare invalide → Vérifier dans secrets/whitelily.yaml
2. Tunnel non actif sur Cloudflare Dashboard → Vérifier sur https://one.dash.cloudflare.com
3. DNS pas configuré → Vérifier les CNAME dans Cloudflare DNS

#### PostgreSQL connection refused

**Vérifier PostgreSQL :**
```bash
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"
```

**Recréer la base :**
```bash
sudo systemctl stop podman-n8n
sudo -u postgres psql -c "DROP DATABASE IF EXISTS n8n;"
sudo -u postgres psql -c "CREATE DATABASE n8n OWNER n8n;"
sudo systemctl start podman-n8n
```

#### Credentials n8n ne fonctionnent pas

**Réinitialiser le mot de passe :**

1. Générer un nouveau hash :
```bash
python3 -c "import crypt; print(crypt.crypt('NouveauMotDePasse', crypt.mksalt(crypt.METHOD_SHA512)))"
```

2. Éditer le secret :
```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/whitelily.yaml
# Modifier n8n.password
```

3. Redéployer :
```bash
ssh root@whitelily "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#whitelily"
```

---

# Advanced

## Build ISO custom

Guide pour générer une ISO NixOS personnalisée avec support de la console série (ttyS0), optimisée pour Proxmox avec NoVNC.

### 🎯 Problème résolu

L'ISO NixOS standard en mode graphique sous Proxmox/NoVNC :
- ❌ Affiche une console graphique "muette"
- ❌ Pas de TTY actif utilisable
- ❌ Outils comme `xterm` ne fonctionnent pas

**Solution** : ISO custom avec console série active dès le boot.

### ✨ Caractéristiques de l'ISO custom

- ✅ Console série active automatiquement (ttyS0 à 115200 baud)
- ✅ Autologin en tant qu'utilisateur `nixos`
- ✅ Environnement X11 minimal (xterm + twm)
- ✅ ZSH + Starship
- ✅ Outils de base : vim, git, curl, wget, htop, tree
- ✅ SSH activé
- ✅ Réseau DHCP automatique

### 🏗️ Construction de l'ISO

#### Prérequis

- NixOS avec flakes activés (version 23.05+)
- 5 GB espace disque minimum
- Accès internet

#### Depuis une VM NixOS

```bash
# 1. Cloner le repo
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config/iso

# 2. Builder l'ISO (10-30 minutes)
nix build .#nixosConfigurations.iso-installer-ttyS0.config.system.build.isoImage

# 3. L'ISO est dans result/iso/
ls -lh result/iso/*.iso
```

#### Copier l'ISO vers Proxmox

```bash
# Option 1 : Via SCP
scp result/iso/*.iso root@proxmox:/var/lib/vz/template/iso/

# Option 2 : Via l'interface web Proxmox
# Datacenter > Storage > local > ISO Images > Upload
```

### 🚀 Utilisation de l'ISO

#### Créer une VM avec l'ISO custom

1. Dans Proxmox : **Create VM**
2. Sélectionner l'ISO custom dans la liste
3. Configurer la VM (2 CPU, 2GB RAM minimum)
4. Démarrer la VM

#### Accéder à la console

**Via NoVNC (interface web) :**
1. Sélectionner la VM
2. Cliquer **Console**
3. Le TTY série est actif automatiquement

**Via console série :**
```bash
# Depuis le shell Proxmox
qm terminal <VMID>
```

#### Utiliser l'ISO

```bash
# Démarrer l'interface graphique
startx

# Installer NixOS normalement
sudo nixos-install
```

### 🎨 Personnalisation

Le fichier `iso/flake.nix` est entièrement modulable.

**Ajouter des packages :**
```nix
environment.systemPackages = with pkgs; [
  tmux
  neovim
  ranger
];
```

**Changer le shell :**
```nix
users.users.nixos = {
  shell = pkgs.bash;  # ou pkgs.fish, pkgs.zsh
};
```

**Rebuild après modification :**
```bash
nix build .#nixosConfigurations.iso-installer-ttyS0.config.system.build.isoImage
```

### 🔬 Détails techniques

**Paramètres de boot :**
```nix
boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
```

- `console=ttyS0,115200n8` : Premier port série à 115200 bauds
- `console=tty1` : Garde aussi la console VGA active

**Comparaison ISO standard vs custom :**

| Aspect | ISO standard | ISO personnalisée |
|--------|-------------|-------------------|
| Console série | ❌ Désactivée | ✅ Active dès le boot |
| TTY dans NoVNC | ⚠️ Nécessite menu GRUB | ✅ Automatique |
| Autologin | ❌ Login manuel | ✅ User `nixos` auto |
| Shell | Bash basique | ZSH + Starship |
| Interface graphique | Aucune | xterm + twm |
| Taille ISO | ~800 MB | ~950 MB |

---

# Troubleshooting

## Erreurs de déploiement

### Erreur "Can't lookup blockdev" au boot

**Cause** : Les labels de disque ne correspondent pas.

**Solution** :
```bash
# Vérifier les labels
lsblk -f

# Vérifier hardware-configuration.nix utilise bien nixos-root et ESP

# Si besoin, reformater avec les bons labels
sudo mkfs.ext4 -L nixos-root /dev/sda2
sudo mkfs.vfat -F32 -n ESP /dev/sda1
```

### La VM a toujours le hostname "nixos"

**Cause** : Le hostname n'a pas été appliqué ou redémarrage nécessaire.

**Solution** :
```bash
# Vérifier la config
grep hostName /etc/nixos/hosts/*/configuration.nix

# Vérifier la commande nixos-rebuild
# Mauvais : nixos-rebuild switch --flake .#
# Bon : nixos-rebuild switch --flake .#mimosa

# Redémarrer
sudo reboot
```

### Git pull échoue dans /etc/nixos

**Cause** : Modifications locales ou branche différente.

**Solution pour nœuds follower (whitelily, etc.)** :

Les nœuds follower ne doivent jamais modifier la configuration localement. Utilisez la mise à jour forcée :

```bash
cd /etc/nixos
gu  # Alias pour: git fetch --all; and git reset --hard origin/main
```

Cela écrase toutes les modifications locales et synchronise avec le serveur, sans jamais demander de résoudre des conflits.

**Solution pour développement (magnolia uniquement)** :
```bash
cd /etc/nixos
git status
git stash  # sauvegarder les modifs locales
git pull
git stash pop  # restaurer les modifs
```

## Erreurs réseau

### SSH refuse la connexion

**Solutions** :
```bash
# Vérifier le service SSH
sudo systemctl status sshd

# Vérifier le port
sudo ss -tlnp | grep 22

# Vérifier le firewall
sudo iptables -L -n | grep 22
```

### Pas d'accès réseau (DHCP)

**Solutions** :
```bash
# Vérifier les interfaces
ip addr

# Redémarrer NetworkManager
sudo systemctl restart NetworkManager

# Debug DHCP
sudo dhclient -v
```

## Erreurs de build

### Build Nix échoue avec "out of disk space"

**Solution** :
```bash
# Nettoyer le store Nix
nix-collect-garbage -d

# Vérifier l'espace libre
df -h /nix
```

### Flake evaluation fails

**Solutions** :
```bash
# Mettre à jour les inputs
nix flake update

# Vérifier la syntaxe
nix flake check

# Rebuild avec plus de verbosité
sudo nixos-rebuild switch --flake .#<hostname> --show-trace
```

## Changement de hostname

Le hostname est appliqué **au boot**. Après un `nixos-rebuild switch` avec un nouveau hostname :

```bash
# Option 1 : Appliquer immédiatement (temporaire)
sudo hostnamectl set-hostname nouveau-nom

# Option 2 : Redémarrer (permanent)
sudo reboot
```

## Connexion perdue après deploy

Si vous perdez la connexion SSH après un déploiement :

1. Accéder via la console Proxmox (pas SSH)
2. Vérifier les logs : `sudo journalctl -xe`
3. Rollback si nécessaire : `sudo nixos-rebuild switch --rollback`
4. Vérifier la config réseau et SSH

---

## 🔑 Informations de connexion

### Par défaut sur toutes les VMs

- **Utilisateur** : `jeremie`
- **Mot de passe initial** : `nixos` (changez-le avec `passwd`)
- **SSH** : Authentification par clé publique uniquement
- **Sudo** : Pas de mot de passe requis pour le groupe `wheel`

### Clé SSH autorisée

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
```

---

## 📚 Ressources complémentaires

- [GETTING-STARTED.md](./GETTING-STARTED.md) - Quick start
- [SECRETS.md](./SECRETS.md) - Gestion des secrets avec sops-nix
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS Wiki](https://nixos.wiki/)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
