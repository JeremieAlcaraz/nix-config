# 🤍 Guide d'installation - Whitelily (n8n)

Guide simplifié pour déployer **whitelily**, une VM NixOS dédiée à n8n avec une architecture production-ready.

**⏱️ Temps d'installation : ~15 minutes**

## 📋 Table des matières

1. [Architecture et fonctionnalités](#architecture-et-fonctionnalités)
2. [Installation rapide (3 étapes)](#installation-rapide-3-étapes)
3. [Installation détaillée](#installation-détaillée)
4. [Maintenance et opérations](#maintenance-et-opérations)
5. [Troubleshooting](#troubleshooting)
6. [Backup et restauration](#backup-et-restauration)

---

## Architecture et fonctionnalités

### 🏗️ Stack technique

- **OS** : NixOS 24.11 (configuration 100% déclarative)
- **Container** : Podman (OCI containers)
- **Application** : n8n (version épinglée pour stabilité)
- **Base de données** : PostgreSQL 16 (robuste, backups faciles)
- **Reverse proxy** : Caddy (moderne, HTTP/2, compression automatique)
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

---

## Installation rapide (1 étape !)

### Prérequis

- ✅ Serveur Proxmox avec ISO NixOS 24.11
- ✅ Compte Cloudflare avec domaine
- ✅ *Optionnel* : Clé age partagée dans `/var/lib/sops-nix/key.txt` sur l'ISO (pour chiffrer les secrets)

### Étape unique : Lancer le script d'installation (15 min)

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
- Domaine (ex: `n8nv2.jeremiealcaraz.com`)
- Token Cloudflare Tunnel (la chaîne qui commence par "eyJ...")

Le script fait ensuite **TOUT automatiquement** :
- ✅ Partitionne et formate le disque
- ✅ Génère `hardware-configuration.nix`
- ✅ Clone la configuration
- ✅ Génère tous les secrets n8n
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

**Sauvegarde ces informations** avant que le script ne continue.

---

## Installation détaillée

Cette section détaille chaque étape pour ceux qui veulent comprendre le processus.

### Prérequis détaillés

#### 🖥️ Infrastructure

- [ ] Accès à un serveur Proxmox
- [ ] ISO NixOS 24.11 téléchargé et disponible sur Proxmox
- [ ] Réseau DHCP configuré
- [ ] Accès SSH depuis ton Mac

#### 🌐 Cloudflare

- [ ] Compte Cloudflare avec domaine configuré
- [ ] Accès à Zero Trust (Cloudflare Tunnel)
- [ ] Domaine ou sous-domaine dédié (ex: `n8nv2.jeremiealcaraz.com`)

#### 💻 Outils locaux (Mac)

```bash
# Vérifier que tu as bien :
which sops age ssh openssl mkpasswd
```

Si manquant, installer :
```bash
brew install sops age
```

#### 🔑 Clé age partagée

Tu dois avoir ta clé age partagée disponible :
- **Mac** : `~/.config/sops/age/nixos-shared-key.txt`
- Cette clé sera copiée sur la VM whitelily

---

## Étape 1 : Créer la VM Proxmox

### 1.1 Configuration VM recommandée

```
Nom           : whitelily
OS            : NixOS 24.11
CPU           : 2 cores
RAM           : 4 GB
Disque        : 32 GB (thin provisioning)
Réseau        : Bridge (DHCP)
BIOS          : OVMF (UEFI)
Boot          : ISO NixOS 24.11
```

### 1.2 Création via l'interface Proxmox

1. Cliquer sur **Create VM**
2. Remplir les paramètres ci-dessus
3. Monter l'ISO NixOS
4. Activer **QEMU Guest Agent** dans Options
5. Démarrer la VM

### 1.3 Console série (optionnel mais recommandé)

Activer la console série pour un accès facile :
```bash
# Dans Proxmox shell
qm set <VMID> -serial0 socket
```

---

## Étape 2 : Installation de NixOS

### 2.1 Boot sur l'ISO

La VM démarre automatiquement sur l'ISO NixOS. Tu arrives sur un shell root.

### 2.2 Partitionnement du disque

**Important** : Ajuste `/dev/sda` selon ton setup (peut être `/dev/vda` sur certains systèmes).

```bash
# Identifier le disque
lsblk

# Partitionner (UEFI/GPT)
parted /dev/sda -- mklabel gpt

# Partition boot (512 MB)
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on

# Partition root (reste de l'espace)
parted /dev/sda -- mkpart primary 512MiB 100%

# Formater
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

# Monter
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### 2.3 Génération de la configuration

```bash
# Générer la config hardware
nixos-generate-config --root /mnt

# Vérifier
ls -la /mnt/etc/nixos/
# Tu devrais voir : configuration.nix et hardware-configuration.nix
```

### 2.4 Installation minimale temporaire

On va d'abord installer un NixOS minimal pour pouvoir SSH et finaliser la config.

```bash
# Éditer la configuration temporaire
nano /mnt/etc/nixos/configuration.nix
```

Configuration minimale :

```nix
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "whitelily";
  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";  # Temporaire !
  };

  users.users.root.password = "nixos";  # Temporaire !

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ git vim curl wget ];

  system.stateVersion = "24.11";
}
```

### 2.5 Installation

```bash
nixos-install

# Attendre que l'installation se termine...
# Puis redémarrer

reboot
```

### 2.6 Premier démarrage

1. Retirer l'ISO dans Proxmox (Unmount CD)
2. La VM redémarre sur le disque
3. Trouver l'IP de la VM :

```bash
# Depuis Proxmox shell
qm guest cmd <VMID> network-get-interfaces
```

Ou depuis la console VM :
```bash
ip addr show
```

### 2.7 Première connexion SSH

```bash
# Depuis ton Mac
ssh root@<IP_VM>
# Password: nixos
```

---

## Étape 3 : Configuration initiale

### 3.1 Cloner ton repo de configuration

```bash
# Sur la VM whitelily (connecté en root)
cd /root
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config

# Vérifier que la branche est bonne
git status
git pull origin claude/nixos-n8n-whitelily-setup-011CV3zqGdzZrKV6bxkVZx1v
```

### 3.2 Copier le hardware-configuration.nix

```bash
# Copier la config hardware générée vers le repo
cp /etc/nixos/hardware-configuration.nix \
   /root/nix-config/hosts/whitelily/hardware-configuration.nix

# Vérifier
cat /root/nix-config/hosts/whitelily/hardware-configuration.nix
```

### 3.3 Installer la clé age sops

```bash
# Créer le répertoire
mkdir -p /var/lib/sops-nix

# Depuis TON MAC, copier la clé :
scp ~/.config/sops/age/nixos-shared-key.txt \
    root@<IP_VM>:/var/lib/sops-nix/key.txt

# De retour sur la VM, vérifier les permissions
chmod 600 /var/lib/sops-nix/key.txt
chown root:root /var/lib/sops-nix/key.txt
```

---

## Étape 4 : Configuration Cloudflare Tunnel

### 4.1 Créer le tunnel dans Cloudflare

1. Aller sur https://one.dash.cloudflare.com/
2. Navigation : **Zero Trust** → **Access** → **Tunnels**
3. Cliquer sur **Create a tunnel**
4. Choisir **Cloudflared**
5. Nom du tunnel : `n8n-whitelily`
6. Cliquer sur **Save tunnel**

### 4.2 Configurer la route publique

1. Dans l'onglet **Public Hostname**, cliquer sur **Add a public hostname**
2. Configuration :
   - **Subdomain** : `n8n` (ou ce que tu veux)
   - **Domain** : `jeremiealcaraz.com` (ton domaine)
   - **Path** : (laisser vide)
   - **Type** : `HTTP`
   - **URL** : `localhost:80`
3. Cliquer sur **Save hostname**

### 4.3 Récupérer le token du tunnel

1. Dans l'interface du tunnel Cloudflare
2. Copier le **TOKEN** (la longue chaîne qui commence par "eyJ...")

Format attendu :
```
eyJhIjoiOWRmZTI4NzQ1N2ZiYjhhNTQ3NmViYjQwMjUyMzlmOGEiLCJ0IjoiMDRlZTgyMDAtZjAwNC00YWVkLTk0NWEtMzE0ZWY0NzUyNmJlIiwicyI6IlpXWmpPVEkwWm1VdE5XTXhZUzAwWlRjM0xXRTROemN0WlRNellXTXdNbUUxT1RBMCJ9
```

**Important** : Garde ce token sous la main, tu en auras besoin à l'étape suivante.

### 4.4 Vérifier le domaine dans n8n.nix

```bash
# Sur la VM whitelily
nano /root/nix-config/hosts/whitelily/n8n.nix

# Ligne 5, vérifier que le domaine est correct :
# domain = "n8nv2.jeremiealcaraz.com";  # ← Ton sous-domaine configuré
```

Ajuster si nécessaire pour correspondre à ce que tu as configuré dans Cloudflare.

---

## Étape 5 : Génération et configuration des secrets

### 5.1 Générer les secrets requis

**Sur ton Mac** (pas sur la VM) :

```bash
cd ~/path/to/nix-config

# 1. Clé de chiffrement n8n (CRITIQUE - À sauvegarder dans 1Password/Bitwarden !)
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)"

# 2. Mot de passe basic auth n8n
echo "N8N_BASIC_PASS=$(openssl rand -base64 24)"

# 3. Mot de passe DB PostgreSQL
echo "DB_PASSWORD=$(openssl rand -base64 32)"

# 4. Hash du mot de passe utilisateur jeremie
mkpasswd -m sha-512
# Entrer le mot de passe que tu veux utiliser pour te connecter
```

**⚠️ CRITIQUE** : Sauvegarde la `N8N_ENCRYPTION_KEY` dans un gestionnaire de mots de passe ! Si tu la perds, tu perds TOUTES tes credentials n8n.

### 5.2 Créer le fichier de secrets

```bash
# Sur ton Mac
cd ~/path/to/nix-config
cp secrets/whitelily.yaml.example secrets/whitelily.yaml

# Éditer avec sops (chiffrement automatique)
sops secrets/whitelily.yaml
```

Remplir tous les champs :

```yaml
jeremie-password-hash: $6$...hash généré avec mkpasswd...

n8n:
  encryption_key: "clé générée avec openssl rand -hex 32"
  basic_user: "admin"  # ou ce que tu veux
  basic_pass: "mot de passe généré avec openssl rand -base64 24"
  db_password: "mot de passe généré avec openssl rand -base64 32"

cloudflared:
  token: "ton-token-cloudflare-qui-commence-par-eyJ..."
```

Sauvegarder et quitter (`:wq` dans vim).

### 5.3 Vérifier que c'est bien chiffré

```bash
# Sur ton Mac
cat secrets/whitelily.yaml | grep "sops:"

# Si tu vois du contenu chiffré avec "sops:", c'est bon !
# Tu devrais voir quelque chose comme :
# sops:
#   kms: []
#   gcp_kms: []
#   ...
```

### 5.4 Committer les secrets chiffrés

```bash
# Sur ton Mac
git add -f secrets/whitelily.yaml
git commit -m "🔒 Add encrypted secrets for whitelily"
git push origin claude/nixos-n8n-whitelily-setup-011CV3zqGdzZrKV6bxkVZx1v
```

---

## Étape 6 : Déploiement final

### 6.1 Pull des derniers changements sur la VM

```bash
# Sur la VM whitelily (connecté en root)
cd /root/nix-config
git pull origin claude/nixos-n8n-whitelily-setup-011CV3zqGdzZrKV6bxkVZx1v
```

### 6.2 Build et activation de la configuration

```bash
# Sur la VM whitelily
cd /root/nix-config

# Build de la configuration whitelily
nixos-rebuild switch --flake .#whitelily

# Cette commande va :
# - Télécharger tous les packages nécessaires
# - Configurer PostgreSQL
# - Télécharger l'image Docker n8n
# - Configurer Caddy
# - Configurer Cloudflare Tunnel
# - Activer tous les services
#
# Cela peut prendre 5-10 minutes la première fois
```

### 6.3 Redémarrage (optionnel mais recommandé)

```bash
reboot
```

Attendre que la VM redémarre, puis reconnecter en SSH :

```bash
# Depuis ton Mac
ssh jeremie@<IP_VM>
# Utiliser le mot de passe que tu as configuré dans les secrets
```

**Note** : Tu ne peux plus te connecter en root ! Utilise l'utilisateur `jeremie` avec sudo.

---

## Étape 7 : Vérifications et tests

### 7.1 Vérifier les services

```bash
# Sur la VM whitelily (connecté en jeremie)

# 1. PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -c "\l" | grep n8n

# 2. Container n8n
sudo podman ps
# Tu devrais voir un container "n8n" avec status "Up" et "healthy"

# 3. Caddy
sudo systemctl status caddy
curl -I http://127.0.0.1:80
# Tu devrais recevoir une réponse de Caddy

# 4. Cloudflare Tunnel
sudo systemctl status cloudflared-tunnel
journalctl -u cloudflared-tunnel -f
# Tu devrais voir : "Connection ... registered"
```

### 7.2 Test de healthcheck n8n

```bash
# Sur la VM
curl http://127.0.0.1:5678/healthz

# Réponse attendue :
# {"status":"ok"}
```

### 7.3 Vérifier les backups

```bash
# Sur la VM
ls -lah /var/backup/postgresql/
ls -lah /var/backup/n8n/

# Pour forcer un backup manuel :
sudo systemctl start postgresqlBackup
sudo systemctl start backup-n8n-data

# Vérifier que les backups sont créés
ls -lah /var/backup/postgresql/
ls -lah /var/backup/n8n/
```

### 7.4 Test de l'accès externe (via Cloudflare)

**Depuis ton navigateur** (sur ton Mac ou autre) :

1. Ouvrir https://n8nv2.jeremiealcaraz.com (ton domaine configuré)
2. Tu devrais voir une page de login avec authentification basique :
   - **Username** : ce que tu as mis dans `n8n/basic_user`
   - **Password** : ce que tu as mis dans `n8n/basic_pass`
3. Après authentification, tu arrives sur l'interface n8n

**Si ça ne marche pas**, voir la section Troubleshooting ci-dessous.

### 7.5 Vérifier les logs

```bash
# Logs n8n (container)
sudo podman logs n8n --tail 50

# Logs Caddy
sudo journalctl -u caddy -n 50

# Logs Cloudflare Tunnel
sudo journalctl -u cloudflared-tunnel -n 50

# Logs PostgreSQL
sudo journalctl -u postgresql -n 50
```

---

## Maintenance et opérations

### 🤖 Mises à jour automatiques de n8n (tag `next`)

**whitelily utilise maintenant le tag `next` de n8n** pour bénéficier des dernières fonctionnalités beta. Un workflow GitHub Actions vérifie quotidiennement les nouvelles versions et crée automatiquement des Pull Requests.

#### Fonctionnement

1. **Workflow quotidien** : Tous les jours à 2h du matin (UTC), le workflow `.github/workflows/update-n8n-next.yml` s'exécute
2. **Vérification Docker Hub** : Le workflow interroge l'API Docker Hub pour obtenir le digest SHA256 du tag `next`
3. **Comparaison** : Compare avec le digest actuellement déployé dans `n8n.nix`
4. **Création de PR** : Si une nouvelle version est détectée, une Pull Request est automatiquement créée
5. **Notification** : Vous recevez une notification GitHub de la nouvelle PR
6. **Review & Merge** : Vous reviewez les changements et mergez la PR
7. **Déploiement** : Vous déployez manuellement sur whitelily

#### Prérequis (Configuration initiale)

Cette configuration est déjà faite si vous avez utilisé le script `manage-secrets.sh` pour générer les secrets. Sinon :

**1. Créer un token GitHub** (une seule fois)

Documentation complète : [docs/GITHUB-TOKEN-SETUP.md](GITHUB-TOKEN-SETUP.md)

Résumé rapide :
- Aller sur https://github.com/settings/tokens/new
- Note : `n8n auto-update workflow`
- Scope : ✅ `repo` (Full control)
- Générer le token (commence par `ghp_...`)

**2. Ajouter le token dans sops**

```bash
# Sur ton Mac
cd ~/path/to/nix-config
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops secrets/whitelily.yaml

# Ajouter ou vérifier la section github:
# github:
#   token: "ghp_votre_token_ici"
```

**3. Ajouter le token dans GitHub Secrets**

- Aller dans Settings → Secrets and variables → Actions
- New repository secret
  - Name : `N8N_UPDATE_TOKEN`
  - Value : [coller le token GitHub]
- Add secret

#### Utilisation quotidienne

**Automatique** :
- Le workflow tourne tous les jours
- Vous recevez une notification si une nouvelle version est disponible
- Rien à faire de votre côté !

**Manuel** (test ou déclenchement immédiat) :
1. Aller dans Actions → "Update n8n next version"
2. Cliquer sur "Run workflow"
3. Sélectionner la branche `main`
4. Run workflow

#### Après la création d'une PR

Lorsqu'une nouvelle version est détectée, vous recevez une PR automatique :

**1. Review de la PR** :
```bash
# La PR contient :
# - Le digest SHA256 de l'ancienne version
# - Le digest SHA256 de la nouvelle version
# - Liens vers les release notes n8n
# - Instructions de déploiement
```

**2. Merger la PR** :
- Vérifier les release notes : https://github.com/n8n-io/n8n/releases
- Vérifier qu'il n'y a pas de breaking changes
- Merger la PR sur GitHub

**3. Déployer sur whitelily** :
```bash
# SSH vers whitelily
ssh jeremie@whitelily

# Pull de la configuration
cd /root/nix-config
sudo git pull

# Rebuild (télécharge et redémarre le nouveau container)
sudo nixos-rebuild switch --flake .#whitelily

# Vérifier que n8n fonctionne
sudo podman ps
sudo podman logs n8n --tail 20
curl http://127.0.0.1:5678/healthz
```

**4. Vérifier l'interface web** :
- Aller sur https://votre-domaine.com
- Vérifier que n8n fonctionne correctement
- Vérifier que vos workflows existants fonctionnent toujours

#### Avantages du tag `next`

✅ **Fonctionnalités beta** : Accès anticipé aux nouvelles fonctionnalités
✅ **Mises à jour fréquentes** : Corrections de bugs plus rapides
✅ **Digest SHA256** : Garantie d'intégrité de l'image
✅ **Pull Requests** : Traçabilité complète des mises à jour
✅ **Contrôle total** : Vous décidez quand déployer

⚠️ **Considérations** :
- Le tag `next` peut contenir des fonctionnalités instables
- Testez vos workflows critiques après chaque mise à jour
- Consultez toujours les release notes avant de merger

#### Dépannage du workflow

**Le workflow ne crée pas de PR** :
```bash
# Vérifier les logs du workflow
# GitHub → Actions → Update n8n next version → Dernière exécution

# Causes possibles :
# 1. Aucune nouvelle version disponible (normal)
# 2. Token GitHub expiré ou invalide
# 3. Permissions insuffisantes

# Vérifier que le secret existe
# Settings → Secrets and variables → Actions → N8N_UPDATE_TOKEN
```

**Erreur 403 ou permissions** :
- Vérifier que le token a le scope `repo` complet
- Re-créer le token si nécessaire (voir docs/GITHUB-TOKEN-SETUP.md)
- Mettre à jour le secret dans GitHub

**Le workflow est en erreur** :
- Consulter les logs dans Actions
- Vérifier la syntaxe du workflow YAML
- Tester manuellement avec "Run workflow"

#### Revenir à une version stable

Si vous préférez une version stable plutôt que `next` :

```bash
# 1. Sur ton Mac, éditer n8n.nix
nano hosts/whitelily/n8n.nix

# 2. Ligne 126, remplacer par une version stable :
# image = "docker.io/n8nio/n8n:1.75.0";  # Version stable

# 3. Désactiver le workflow (optionnel)
# Renommer .github/workflows/update-n8n-next.yml en .disabled

# 4. Committer et déployer
git add hosts/whitelily/n8n.nix
git commit -m "⬇️ Switch n8n to stable version 1.75.0"
git push

# 5. Sur whitelily
cd /root/nix-config
sudo git pull
sudo nixos-rebuild switch --flake .#whitelily
```

### 🔄 Mise à jour manuelle de n8n

Si vous désactivez l'automatisation, vous pouvez toujours mettre à jour manuellement :

```bash
# 1. Sur ton Mac, éditer le fichier n8n.nix
nano hosts/whitelily/n8n.nix

# 2. Ligne 126, changer la version :
# image = "docker.io/n8nio/n8n:next@sha256:nouvelle-version";
# ou
# image = "docker.io/n8nio/n8n:1.75.0";  # Version stable

# 3. Committer et pousser
git add hosts/whitelily/n8n.nix
git commit -m "⬆️ Update n8n to 1.75.0"
git push

# 4. Sur la VM whitelily
cd /root/nix-config
git pull
sudo nixos-rebuild switch --flake .#whitelily

# Le nouveau container sera téléchargé et redémarré automatiquement
```

### 🔍 Monitoring quotidien

Services à surveiller :

```bash
# Quick check de tous les services
sudo systemctl status postgresql caddy cloudflared-tunnel
sudo podman ps

# Vérifier l'espace disque
df -h

# Vérifier les backups récents
ls -lth /var/backup/postgresql/ | head
ls -lth /var/backup/n8n/ | head
```

### 📊 Vérifier l'utilisation des ressources

```bash
# CPU et RAM
htop

# Utilisation PostgreSQL
sudo -u postgres psql n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"

# Utilisation container n8n
sudo podman stats n8n --no-stream
```

### 🧹 Nettoyage

```bash
# Nettoyer les anciennes générations NixOS (garder les 5 dernières)
sudo nix-collect-garbage --delete-older-than 30d

# Nettoyer les anciennes images Podman
sudo podman image prune -a

# Optimiser le store Nix
sudo nix-store --optimise
```

### 🔐 Rotation des secrets

Pour changer un secret (exemple : mot de passe n8n) :

```bash
# 1. Sur ton Mac
cd ~/path/to/nix-config
sops secrets/whitelily.yaml
# Éditer la valeur, sauvegarder

# 2. Committer et pousser
git add secrets/whitelily.yaml
git commit -m "🔐 Rotate n8n password"
git push

# 3. Sur la VM
cd /root/nix-config
git pull
sudo nixos-rebuild switch --flake .#whitelily

# Les services sont automatiquement redémarrés avec les nouveaux secrets
```

---

## Troubleshooting

### ❌ Problème : n8n ne démarre pas

**Diagnostic** :

```bash
sudo podman ps -a
sudo podman logs n8n --tail 100
```

**Solutions possibles** :

1. **Secret `N8N_ENCRYPTION_KEY` manquant ou invalide** :
   ```bash
   cat /run/secrets/n8n.env
   # Vérifier que N8N_ENCRYPTION_KEY est présent
   ```

2. **Problème de connexion PostgreSQL** :
   ```bash
   sudo systemctl status postgresql
   sudo -u postgres psql -c "\du" | grep n8n
   ```

3. **Regénérer le fichier d'environnement** :
   ```bash
   sudo systemctl restart n8n-envfile
   sudo systemctl restart podman-n8n
   ```

### ❌ Problème : Cloudflare Tunnel ne se connecte pas

**Diagnostic** :

```bash
sudo journalctl -u cloudflared-tunnel -n 100
```

**Solutions possibles** :

1. **Token invalide** :
   ```bash
   # Vérifier que le secret est bien déchiffré
   sudo journalctl -u cloudflared-tunnel -n 50
   # Chercher des erreurs liées au token
   ```

2. **Relancer le tunnel** :
   ```bash
   sudo systemctl restart cloudflared-tunnel
   ```

3. **Vérifier la configuration Cloudflare** :
   - Aller sur https://one.dash.cloudflare.com/
   - Access → Tunnels → n8n-whitelily
   - Vérifier que le status est "Healthy"

### ❌ Problème : Erreur 502 Bad Gateway

**Diagnostic** :

```bash
# Vérifier que n8n répond en local
curl http://127.0.0.1:5678/healthz

# Vérifier Caddy
sudo journalctl -u caddy -n 50
```

**Solutions** :

1. **n8n n'est pas démarré** :
   ```bash
   sudo podman start n8n
   ```

2. **Caddy ne peut pas joindre n8n** :
   ```bash
   # Vérifier la config Caddy
   sudo caddy fmt --overwrite /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

### ❌ Problème : Webhooks ne fonctionnent pas

**Diagnostic** :

Vérifier que `WEBHOOK_URL` est correctement configuré :

```bash
sudo podman exec n8n env | grep WEBHOOK
```

Devrait afficher :
```
WEBHOOK_URL=https://n8nv2.jeremiealcaraz.com/
```

**Solution** :

Si incorrect, vérifier `hosts/whitelily/n8n.nix` ligne 5 (variable `domain`).

### ❌ Problème : PostgreSQL n'accepte pas les connexions

**Diagnostic** :

```bash
sudo -u postgres psql -c "SHOW listen_addresses;"
```

**Solution** :

```bash
# Vérifier que PostgreSQL écoute sur localhost
sudo systemctl restart postgresql
```

### 🔍 Logs généraux pour debug

```bash
# Voir tous les logs système récents
sudo journalctl -xe

# Logs d'un service spécifique
sudo journalctl -u <service-name> -f

# Logs depuis boot
sudo journalctl -b
```

---

## Backup et restauration

### 💾 Backups automatiques

Les backups sont automatiquement créés tous les jours :

- **PostgreSQL** : `/var/backup/postgresql/n8n.sql.gz`
- **Données n8n** : `/var/backup/n8n/n8n-YYYY-MM-DD_HH-MM-SS.tar.gz`

Rétention : 7 jours

### 📤 Exporter les backups vers un stockage externe

**Exemple avec Restic** (vers Backblaze B2) :

```bash
# 1. Installer restic (déjà installé sur whitelily)
# 2. Configurer le repo
export RESTIC_REPOSITORY="b2:bucket-name:/whitelily-backups"
export RESTIC_PASSWORD="ton-mot-de-passe-restic"
export B2_ACCOUNT_ID="ton-account-id"
export B2_ACCOUNT_KEY="ton-account-key"

# Initialiser le repo (une seule fois)
restic init

# Backup manuel
restic backup /var/backup/

# Lister les backups
restic snapshots

# Automatiser avec un timer systemd (à ajouter dans n8n.nix si besoin)
```

### 🔄 Restauration complète

**1. Restaurer PostgreSQL** :

```bash
# Arrêter n8n
sudo systemctl stop podman-n8n

# Restaurer la DB
sudo -u postgres psql -d n8n -f /var/backup/postgresql/n8n.sql

# Ou depuis un backup gzippé
gunzip -c /var/backup/postgresql/n8n.sql.gz | sudo -u postgres psql -d n8n

# Redémarrer n8n
sudo systemctl start podman-n8n
```

**2. Restaurer les données n8n** :

```bash
# Arrêter n8n
sudo systemctl stop podman-n8n

# Sauvegarder l'existant (par précaution)
sudo mv /var/lib/n8n /var/lib/n8n.old

# Restaurer
sudo tar -xzf /var/backup/n8n/n8n-2024-01-15_03-00-00.tar.gz -C /var/lib/

# Redémarrer
sudo systemctl start podman-n8n
```

### 🚨 Plan de disaster recovery

En cas de perte complète de la VM :

1. **Créer une nouvelle VM whitelily** (suivre Étapes 1-3)
2. **Restaurer les secrets** :
   ```bash
   # Copier la clé age depuis ton Mac
   scp ~/.config/sops/age/nixos-shared-key.txt root@<IP>:/var/lib/sops-nix/key.txt
   ```
3. **Déployer la configuration** (Étape 6)
4. **Restaurer les backups** (ci-dessus)
5. **Vérifier** (Étape 7)

**Temps estimé** : 30-45 minutes

---

## 🎉 Félicitations !

Tu as maintenant une instance n8n production-ready, sécurisée et 100% déclarative sur NixOS !

### 📚 Ressources supplémentaires

- [Documentation n8n](https://docs.n8n.io/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

### 🤝 Support

En cas de problème, vérifier :
1. Les logs (voir section Troubleshooting)
2. La configuration dans le repo
3. Les secrets (bien déchiffrés)
4. Le status Cloudflare Tunnel

**Bon automatisme avec n8n ! 🚀**
