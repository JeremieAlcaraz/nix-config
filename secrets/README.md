# Secrets pour learnix

Ce répertoire contient les secrets chiffrés avec sops pour les différents hôtes.

## ⚠️ IMPORTANT

- **NE JAMAIS** committer de fichiers `.yaml` non chiffrés
- Seuls les fichiers **chiffrés** avec sops peuvent être committés
- Les fichiers `.example` sont des templates et ne contiennent pas de vraies valeurs

## Quick Start - Utilisez manage-secrets.sh

**Le seul script dont vous avez besoin pour gérer vos secrets !**

### 🚀 Usage

```bash
# Créer ou régénérer les secrets pour un host
cd /etc/nixos
sudo ./scripts/manage-secrets.sh [magnolia|mimosa|whitelily]
```

### ✨ Le script fait tout automatiquement

1. ✅ Vérifie les outils nécessaires (sops, age, openssl, mkpasswd)
2. ✅ Vérifie/configure la clé age
3. ✅ Génère les secrets de manière interactive
4. ✅ Sauvegarde les anciens secrets avant modification
5. ✅ Chiffre automatiquement avec sops

### 📦 Après génération

```bash
# Vérifier que les secrets sont bien chiffrés
cat secrets/mimosa.yaml | grep "sops:"

# Déployer sur l'host
sudo nixos-rebuild switch --flake .#mimosa

# Si vous êtes sur une autre machine, committer et pusher
git add secrets/mimosa.yaml
git commit -m "🔒 Update secrets for mimosa"
git push
```

### 💡 Pourquoi manage-secrets.sh ?

- 🔒 **Sécurité** : Les secrets ne sont jamais créés au build time
- 🔄 **Rotation facile** : Régénérez n'importe quel secret à tout moment
- 🎯 **Interactif** : Le script vous guide étape par étape
- 💾 **Backup** : Les anciens secrets sont automatiquement sauvegardés
- ⚡ **Chiffrement** : Automatique et transparent avec sops

## Fichiers

- `*.example` : Templates de secrets (non chiffrés, pour référence)
- `*.yaml` : Secrets chiffrés (à committer avec `-f`)
- `.gitignore` : Protection contre les commits accidentels

## Obtenir le token Cloudflare Tunnel

1. https://one.dash.cloudflare.com/
2. Access → Tunnels
3. Configure → Installation token
4. Copier le token (la longue chaîne après `--token`)

## Aide

Voir [`docs/SECRETS.md`](../docs/SECRETS.md) pour la documentation complète.
