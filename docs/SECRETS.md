# 🔐 Gestion des Secrets avec sops-nix

Guide complet pour gérer de manière sécurisée les secrets (mots de passe, tokens, clés API) avec **sops-nix**.

## 📋 Table des matières

1. [Introduction](#introduction)
2. [Quick Start - Clé partagée](#quick-start---clé-partagée)
3. [Configuration par host](#configuration-par-host)
4. [Mots de passe sécurisés](#mots-de-passe-sécurisés)
5. [Workflow quotidien](#workflow-quotidien)
6. [Troubleshooting](#troubleshooting)

---

# Introduction

## 🎯 Pourquoi sops-nix ?

**Le problème** : Comment stocker des secrets dans un repository git public ?

**Mauvaises approches** :
```nix
# ❌ Mot de passe en clair
users.users.jeremie.password = "monmotdepasse";

# ⚠️ Hash visible (mieux, mais pas parfait)
users.users.jeremie.hashedPassword = "$6$vwZmaAkvi9Sjgv60$...";
```

**✅ La solution : sops-nix**

Les secrets sont :
- Chiffrés avec **age** (cryptographie moderne)
- Committés dans git (sécurisés)
- Déchiffrés automatiquement au déploiement
- Accessibles uniquement par les hosts autorisés

## 🏗️ Architecture sops-nix

```
┌─────────────────────┐
│  Votre Mac/PC       │
│  ┌───────────────┐  │
│  │ Clé age       │  │ → Peut éditer les secrets
│  │ (privée)      │  │
│  └───────────────┘  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  Git Repository     │
│  ┌───────────────┐  │
│  │ secrets/      │  │ → Secrets chiffrés (safe)
│  │  mimosa.yaml  │  │
│  │  magnolia.yaml│  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ .sops.yaml    │  │ → Qui peut déchiffrer quoi
│  └───────────────┘  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  VM mimosa          │
│  ┌───────────────┐  │
│  │ Clé age       │  │ → Peut déchiffrer mimosa.yaml
│  │ (privée)      │  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ /run/secrets/ │  │ → Secrets déchiffrés
│  └───────────────┘  │
└─────────────────────┘
```

## 📦 Deux approches

| Approche | Avantages | Inconvénients | Cas d'usage |
|----------|-----------|---------------|-------------|
| **Clé partagée** | ✅ Simple<br>✅ Une seule clé<br>✅ Édition depuis Mac | ⚠️ Moins sécurisé | Homelab, dev/test |
| **Clé par host** | ✅ Sécurité maximale<br>✅ Isolation par VM | ⚠️ Plus complexe<br>⚠️ Édition depuis chaque VM | Production |

---

# Quick Start - Clé partagée

**Configuration utilisée** : Une clé age partagée pour toutes les VMs.

**Parfait pour** : Homelab personnel, environnement de dev/test.

## 📋 Prérequis

Installation des outils :

```bash
# Sur Mac
brew install sops age

# Sur NixOS
nix-shell -p sops age
```

## 🔑 Étape 1 : Générer la clé age partagée

**Une seule fois** sur votre Mac :

```bash
# Créer le dossier
mkdir -p ~/.config/sops/age

# Générer la clé partagée
age-keygen -o ~/.config/sops/age/key.txt

# Afficher la clé publique
grep "public key:" ~/.config/sops/age/key.txt
# Sortie : age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANT** : Sauvegardez cette clé privée dans un endroit sûr (1Password, Bitwarden, etc.) !

## 📝 Étape 2 : Configurer .sops.yaml

Le fichier `.sops.yaml` définit qui peut déchiffrer quoi.

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/mimosa\.yaml$
    key_groups:
      - age:
          - &shared age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Votre clé publique

  - path_regex: secrets/magnolia\.yaml$
    key_groups:
      - age:
          - &shared age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Même clé

  - path_regex: secrets/whitelily\.yaml$
    key_groups:
      - age:
          - &shared age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Même clé
```

Remplacez `age1xxx...` par votre vraie clé publique.

## 🔒 Étape 3 : Créer et chiffrer les secrets

### Pour mimosa

```bash
# 1. Copier le template
cp secrets/mimosa.yaml.example secrets/mimosa.yaml

# 2. Configurer sops pour utiliser votre clé
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt

# 3. Éditer et chiffrer avec sops
sops secrets/mimosa.yaml
```

Un éditeur s'ouvre (nano ou vim). Le fichier contient :

```yaml
jeremie-password-hash: $6$rounds=656000$... # Hash par défaut (mot de passe: "nixos")
```

**Pour changer le mot de passe** :

```bash
# Générer un nouveau hash
python3 -c "import crypt; print(crypt.crypt('VotreMotDePasse', crypt.mksalt(crypt.METHOD_SHA512)))"

# Copier le hash et le remplacer dans l'éditeur sops
# Sauvegarder et quitter (Ctrl+X, Y, Enter dans nano)
```

### Vérifier le chiffrement

```bash
# Le fichier doit contenir "sops:" et "mac:"
cat secrets/mimosa.yaml | grep "sops:"

# Vous devez voir du contenu chiffré
# Si c'est le cas : ✅ succès !
```

### Committer les secrets chiffrés

```bash
# Ajouter explicitement (car .gitignore bloque les .yaml par sécurité)
git add -f secrets/mimosa.yaml

# Vérifier qu'il est bien chiffré avant de committer !
cat secrets/mimosa.yaml | grep "sops:"

# Committer
git commit -m "🔒 Add encrypted secrets for mimosa"
git push
```

## 📤 Étape 4 : Copier la clé privée sur les VMs

**IMPORTANT** : Cette étape doit être faite AVANT le premier build de chaque VM.

### Option A : Via ISO Live (avant installation)

```bash
# Sur votre Mac, pendant l'installation de la VM
ssh nixos@<ip-de-la-vm>
sudo mkdir -p /mnt/var/lib/sops-nix
sudo chmod 755 /mnt/var/lib/sops-nix

# Depuis votre Mac
cat ~/.config/sops/age/key.txt | ssh nixos@<ip-de-la-vm> "sudo tee /mnt/var/lib/sops-nix/key.txt"
ssh nixos@<ip-de-la-vm> "sudo chmod 600 /mnt/var/lib/sops-nix/key.txt"
```

Puis continuez avec l'installation normale.

### Option B : Après installation

Si la VM est déjà installée :

```bash
# Pour mimosa
cat ~/.config/sops/age/key.txt | ssh root@mimosa "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@mimosa "chmod 600 /var/lib/sops-nix/key.txt"

# Pour magnolia
cat ~/.config/sops/age/key.txt | ssh root@magnolia "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@magnolia "chmod 600 /var/lib/sops-nix/key.txt"
```

## 🚀 Étape 5 : Déployer

```bash
# Sur la VM
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#mimosa
```

Les secrets sont automatiquement déchiffrés et disponibles dans `/run/secrets/`.

## 💡 Alias pratiques

Ajoutez dans votre `~/.zshrc` ou `~/.bashrc` sur votre Mac :

```bash
# sops avec la bonne clé
alias sops-edit='SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt sops'

# Éditer les secrets rapidement
alias sops-mimosa='sops-edit ~/path/to/nix-config/secrets/mimosa.yaml'
alias sops-magnolia='sops-edit ~/path/to/nix-config/secrets/magnolia.yaml'
```

Utilisation :
```bash
sops-mimosa  # Édite directement mimosa.yaml
```

---

# Configuration par host

**Configuration utilisée** : Chaque VM a sa propre clé age.

**Parfait pour** : Production, sécurité maximale.

## 🏗️ Architecture

```
VM mimosa     → Clé age mimosa     → Déchiffre mimosa.yaml uniquement
VM magnolia   → Clé age magnolia   → Déchiffre magnolia.yaml uniquement
VM whitelily  → Clé age whitelily  → Déchiffre whitelily.yaml uniquement
```

## 🔑 Étape 1 : Déployer l'hôte une première fois

Avant de configurer les secrets, déployez l'hôte pour générer ses clés SSH :

```bash
sudo nixos-rebuild switch --flake .#mimosa
```

À ce stade, le déploiement peut échouer car le fichier de secrets n'existe pas encore. C'est normal.

## 🔐 Étape 2 : Récupérer la clé publique age de l'hôte

Depuis l'hôte mimosa, récupérez la clé publique age :

```bash
# Option 1: Via SSH depuis votre machine locale
ssh root@mimosa "cat /var/lib/sops-nix/key.pub"

# Option 2: Convertir la clé SSH de l'hôte
ssh root@mimosa "cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age

# Option 3: Directement sur l'hôte
ssh root@mimosa
cat /var/lib/sops-nix/key.pub
```

La clé ressemble à : `age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 📝 Étape 3 : Mettre à jour .sops.yaml

Éditez `.sops.yaml` et remplacez les clés placeholder par les vraies clés publiques :

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/mimosa\.yaml$
    key_groups:
      - age:
          - &mimosa age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Clé réelle de mimosa
          - &admin age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy  # Votre clé perso (optionnel)

  - path_regex: secrets/magnolia\.yaml$
    key_groups:
      - age:
          - &magnolia age1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz  # Clé réelle de magnolia
          - &admin age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy  # Votre clé perso (optionnel)
```

**Optionnel mais recommandé** : Ajoutez votre propre clé age pour pouvoir éditer les secrets depuis votre Mac :

```bash
# Générer votre clé personnelle
age-keygen -o ~/.config/sops/age/key.txt

# Afficher la clé publique
grep "public key:" ~/.config/sops/age/key.txt
```

## 🔒 Étape 4 : Créer et chiffrer les secrets

```bash
# 1. Copier le template
cp secrets/mimosa.yaml.example secrets/mimosa.yaml

# 2. Éditer avec sops (chiffre automatiquement)
sops secrets/mimosa.yaml
```

Dans l'éditeur sops, ajoutez vos secrets :

```yaml
jeremie-password-hash: $6$...
cloudflare-tunnel-token: eyJhIjoiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX...
```

Sauvegardez et quittez (`:wq` dans vim).

## ✅ Étape 5 : Vérifier et committer

```bash
# Vérifier que le fichier est chiffré
cat secrets/mimosa.yaml
# Devrait contenir "sops:" et des données chiffrées

# Vérifier qu'on peut le déchiffrer
sops -d secrets/mimosa.yaml

# Committer le fichier chiffré
git add -f secrets/mimosa.yaml
git commit -m "🔒 Add encrypted secrets for mimosa"
git push
```

## 🚀 Étape 6 : Déployer

```bash
# Sur la VM directement
sudo nixos-rebuild switch --flake .#mimosa

# Ou via déploiement distant
sudo nixos-rebuild switch --flake .#mimosa --target-host root@mimosa
```

sops-nix déchiffrera automatiquement les secrets au démarrage.

## 🔄 Rotation des clés

Si vous devez changer la clé d'un hôte (par exemple après une réinstallation) :

1. Récupérez la nouvelle clé publique age
2. Mettez à jour `.sops.yaml`
3. Re-chiffrez les secrets :

```bash
sops updatekeys secrets/mimosa.yaml
```

---

# Mots de passe sécurisés

Guide pour gérer les mots de passe des utilisateurs avec **sops-nix** et `hashedPasswordFile`.

## 🎯 Comparaison des approches

### ❌ `initialPassword` ou `password`

```nix
users.users.jeremie = {
  initialPassword = "nixos";  # ❌ Mot de passe EN CLAIR dans le repo public !
};
```

**Problèmes** :
- Mot de passe visible par tout le monde sur GitHub
- Risque de sécurité majeur si oublié de le changer
- Pas professionnel pour un environnement de production

### ⚠️ `hashedPassword`

```nix
users.users.jeremie = {
  hashedPassword = "$6$vwZmaAkvi9Sjgv60$...";  # ⚠️ Hash visible dans le repo
};
```

**Avantages** :
- Impossible de retrouver le mot de passe depuis le hash
- Acceptable pour du développement/test

**Inconvénient** :
- Le hash est quand même visible dans le repo public
- Si quelqu'un a accès au hash ET à la VM, il peut tenter du brute-force

### ✅ `hashedPasswordFile` + sops-nix

```nix
sops.secrets.jeremie-password-hash = {
  neededForUsers = true;
};

users.users.jeremie = {
  hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};
```

**Avantages** :
- ✅ Hash chiffré dans le repo (personne ne peut le voir)
- ✅ Seul l'hôte peut déchiffrer le secret
- ✅ Sécurité maximale pour la production
- ✅ Compatible avec sops-nix

## 🚀 Configuration

### Configuration NixOS

```nix
# Dans hosts/mimosa/configuration.nix

{ config, pkgs, ... }:

{
  # Importer sops-nix
  imports = [
    <sops-nix/modules/sops>
  ];

  # Configuration sops
  sops = {
    defaultSopsFile = ../../secrets/mimosa.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
    };
    secrets = {
      jeremie-password-hash = {
        neededForUsers = true;  # IMPORTANT : Déchiffrer avant la création des users
      };
    };
  };

  # Utilisateur avec mot de passe sécurisé
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;  # Utilise le secret
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
    ];
  };

  # Sudo sans mot de passe (sécurisé car SSH par clé uniquement)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
```

### Créer le fichier de secrets

```bash
# 1. Générer un hash de mot de passe sécurisé
python3 -c "import crypt; print(crypt.crypt('VotreMotDePasseSecurise', crypt.mksalt(crypt.METHOD_SHA512)))"

# 2. Créer le fichier secrets
cp secrets/mimosa.yaml.example secrets/mimosa.yaml

# 3. Éditer avec sops
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml
```

Dans l'éditeur, ajoutez :

```yaml
jeremie-password-hash: $6$rounds=656000$... # Le hash généré
```

Sauvegardez et quittez.

### Committer et déployer

```bash
# Vérifier le chiffrement
cat secrets/mimosa.yaml | grep "sops:"

# Committer
git add -f secrets/mimosa.yaml
git commit -m "🔒 Add encrypted password hash for jeremie"
git push

# Déployer sur la VM
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## 🔑 Changer un mot de passe

```bash
# 1. Générer un nouveau hash
python3 -c "import crypt; print(crypt.crypt('NouveauMotDePasse', crypt.mksalt(crypt.METHOD_SHA512)))"

# 2. Éditer le secret
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml
# Remplacer la valeur de jeremie-password-hash

# 3. Committer et redéployer
git add secrets/mimosa.yaml
git commit -m "🔒 Update password hash for jeremie"
git push

ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## 🔄 Bootstrap avec mot de passe temporaire

Pour le **premier déploiement**, les secrets ne sont pas encore disponibles. Options :

### Option A : initialPassword temporaire

Modifier temporairement pour le premier boot :

```nix
users.users.jeremie = {
  isNormalUser = true;
  createHome = true;
  home = "/home/jeremie";
  extraGroups = [ "wheel" ];
  # Temporaire pour le premier boot
  initialPassword = "nixos";
  # Commentez temporairement :
  # hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};

# Commentez aussi temporairement la section sops
# sops = { ... };
```

Après le premier boot :
1. Copier la clé age sur la VM (voir Quick Start)
2. Activer la configuration sops
3. Redéployer

### Option B : hashedPassword temporaire

```bash
# Générer un hash
python3 -c "import crypt; print(crypt.crypt('nixos', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Puis :

```nix
users.users.jeremie = {
  hashedPassword = "$6$...";  # Hash temporaire
  # Commentez :
  # hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};
```

---

# Workflow quotidien

## Ajouter un nouveau secret

```bash
# 1. Éditer le fichier chiffré
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml

# 2. Ajouter le secret (ex: api-key: ma-clé-secrète)
# Sauvegarder et quitter

# 3. Déclarer dans configuration.nix
sops.secrets.api-key = {
  owner = "mon-service";
  group = "mon-service";
  mode = "0400";
};

# 4. Utiliser dans la configuration
services.mon-service = {
  apiKeyFile = config.sops.secrets.api-key.path;
};

# 5. Commit et déployer
git add secrets/mimosa.yaml hosts/mimosa/configuration.nix
git commit -m "🔒 Add API key for mon-service"
git push

ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## Éditer un secret existant

```bash
# 1. Éditer
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml

# 2. Modifier et sauvegarder

# 3. Commit et déployer
git add secrets/mimosa.yaml
git commit -m "🔒 Update secrets"
git push

ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## Ajouter un nouvel hôte

```bash
# 1. Créer le template
cp secrets/mimosa.yaml.example secrets/nouveau-host.yaml

# 2. Récupérer la clé publique du nouvel hôte
ssh root@nouveau-host "cat /var/lib/sops-nix/key.pub"

# 3. Ajouter dans .sops.yaml
# - path_regex: secrets/nouveau-host\.yaml$
#   key_groups:
#     - age:
#         - &nouveau-host age1zzzzz...

# 4. Éditer et chiffrer les secrets
sops secrets/nouveau-host.yaml

# 5. Commit
git add -f secrets/nouveau-host.yaml .sops.yaml
git commit -m "🔒 Add secrets for nouveau-host"
git push
```

---

# Troubleshooting

## Erreur : "no keys could decrypt the data key"

**Cause** : La clé privée n'est pas sur la VM ou est incorrecte.

**Solution** :

```bash
# Vérifier que la clé existe sur la VM
ssh root@mimosa "ls -la /var/lib/sops-nix/key.txt"

# Si elle n'existe pas, copier depuis votre Mac (clé partagée)
cat ~/.config/sops/age/key.txt | ssh root@mimosa "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@mimosa "chmod 600 /var/lib/sops-nix/key.txt"

# Redéployer
ssh root@mimosa "nixos-rebuild switch --flake /etc/nixos#mimosa"
```

## Erreur : "file 'secrets/mimosa.yaml' not found"

**Cause** : Le fichier de secrets n'a pas été créé ou committé.

**Solution** :

```bash
# Sur votre Mac
cd /path/to/nix-config
cp secrets/mimosa.yaml.example secrets/mimosa.yaml
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml
# Sauvegarder et quitter

git add -f secrets/mimosa.yaml
git commit -m "🔒 Add encrypted secrets"
git push
```

## Le secret n'est pas disponible dans /run/secrets/

**Vérifier** :

```bash
# Sur l'hôte, vérifier les secrets déchiffrés
ls -la /run/secrets/

# Vérifier les logs systemd
journalctl -u sops-nix-mimosa.service

# Vérifier la clé age
cat /var/lib/sops-nix/key.pub
```

**Causes fréquentes** :
1. La clé publique dans `.sops.yaml` ne correspond pas à celle de l'hôte
2. Le fichier n'est pas chiffré avec cette clé
3. La clé privée n'existe pas : `/var/lib/sops-nix/key.txt`

**Solution** : Re-chiffrer avec les bonnes clés

```bash
sops updatekeys secrets/mimosa.yaml
```

## Je ne peux plus me connecter après le redéploiement

**Cause** : Le hash de mot de passe est incorrect ou le secret n'est pas déchiffré.

**Solution** :

1. Connectez-vous via la console Proxmox (pas SSH)
2. Réinitialisez le mot de passe manuellement :

```bash
passwd jeremie
```

3. Vérifiez la configuration sops :

```bash
# Le secret est-il déchiffré ?
ls -la /run/secrets/jeremie-password-hash

# Le fichier est-il lisible ?
cat /run/secrets/jeremie-password-hash

# Les logs sops
journalctl -u sops-nix
```

4. Corrigez et redéployez

## sops ne trouve pas ma clé pour éditer

**Cause** : Variable d'environnement `SOPS_AGE_KEY_FILE` non définie.

**Solution** :

```bash
# Définir la variable
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt

# Ou ajouter dans ~/.zshrc / ~/.bashrc
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt' >> ~/.zshrc

# Réessayer
sops secrets/mimosa.yaml
```

## Erreur de déchiffrement avec plusieurs clés

**Cause** : Le secret a été chiffré avec d'anciennes clés qui ne sont plus valides.

**Solution** : Re-chiffrer avec les clés actuelles

```bash
# Mettre à jour .sops.yaml avec les bonnes clés publiques
vim .sops.yaml

# Re-chiffrer tous les secrets
sops updatekeys secrets/mimosa.yaml
sops updatekeys secrets/magnolia.yaml
sops updatekeys secrets/whitelily.yaml

# Commit
git add secrets/*.yaml
git commit -m "🔒 Re-encrypt secrets with updated keys"
git push
```

## Vérifier qu'un fichier est bien chiffré

```bash
# Doit contenir "sops:" et "mac:"
cat secrets/mimosa.yaml | grep "sops:"

# Si vous voyez du texte en clair, le fichier n'est PAS chiffré !
# Ne JAMAIS committer un fichier non chiffré !
```

---

## 🔒 Sécurité

### Bonnes pratiques

✅ **À FAIRE** :
- Utiliser sops-nix pour tous les secrets en production
- Sauvegarder vos clés privées age dans un endroit sûr (password manager)
- Vérifier que les fichiers sont chiffrés avant de committer
- Utiliser `.gitignore` pour bloquer les `.yaml` non chiffrés
- Changer régulièrement les mots de passe

❌ **À NE JAMAIS FAIRE** :
- Committer des secrets en clair dans git
- Partager les clés privées age
- Oublier `neededForUsers = true;` pour les mots de passe
- Utiliser `initialPassword` en production
- Exposer les secrets dans les logs

### Hiérarchie de sécurité

| Approche | Sécurité | Production |
|----------|----------|------------|
| `initialPassword` | ⚠️ Très faible | ❌ Jamais |
| `password` | ⚠️ Très faible | ❌ Jamais |
| `hashedPassword` | ✅ Bon | ⚠️ Dev/test uniquement |
| `hashedPasswordFile` + sops | 🔒 Excellent | ✅ **Recommandé** |

---

## 📚 Ressources

- [Documentation sops-nix](https://github.com/Mic92/sops-nix)
- [Documentation sops](https://github.com/getsops/sops)
- [Documentation age](https://github.com/FiloSottile/age)
- [NixOS Manual - User Management](https://nixos.org/manual/nixos/stable/index.html#sec-user-management)

---

## 💬 Support

En cas de problème :
1. Consulter la section Troubleshooting ci-dessus
2. Vérifier les logs : `journalctl -u sops-nix`
3. Vérifier que les clés sont bien présentes et valides
4. Créer une issue dans le repository
