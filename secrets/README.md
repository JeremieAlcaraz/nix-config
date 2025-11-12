# Secrets pour learnix

Ce répertoire contient les secrets chiffrés avec sops pour les différents hôtes.

## ⚠️ IMPORTANT

- **NE JAMAIS** committer de fichiers `.yaml` non chiffrés
- Seuls les fichiers **chiffrés** avec sops peuvent être committés
- Les fichiers `.example` sont des templates et ne contiennent pas de vraies valeurs

## Quick Start - Méthode Recommandée (manage-secrets.sh)

**NOUVEAU** : Utilisez le script `manage-secrets.sh` pour gérer vos secrets facilement !

```bash
# Créer ou régénérer les secrets pour un host
cd /path/to/nix-config
sudo ./scripts/manage-secrets.sh [magnolia|mimosa|whitelily]

# Le script va :
# 1. Vérifier que vous avez les outils nécessaires (sops, age, openssl, mkpasswd)
# 2. Vérifier que la clé age est configurée
# 3. Générer les secrets de manière interactive
# 4. Chiffrer automatiquement avec sops
# 5. Sauvegarder les anciens secrets si existants
```

### Avantages de manage-secrets.sh

- ✅ **Séparé de l'installation** : Gérez les secrets indépendamment du build/install
- ✅ **Rotation facile** : Régénérez n'importe quel secret à tout moment
- ✅ **Interactif et guidé** : Le script vous guide étape par étape
- ✅ **Backup automatique** : Les anciens secrets sont sauvegardés avant régénération
- ✅ **Chiffrement automatique** : Les secrets sont chiffrés avec sops immédiatement

### Après génération des secrets

```bash
# Vérifier que les secrets sont bien chiffrés
cat secrets/mimosa.yaml | grep "sops:"

# Committer les secrets
git add secrets/mimosa.yaml
git commit -m "🔒 Update secrets for mimosa"

# Déployer sur l'host
sudo nixos-rebuild switch --flake .#mimosa
```

## Méthode Alternative - Manuelle

Si vous préférez créer les secrets manuellement :

1. **Installer les outils** :
   ```bash
   nix-shell -p sops age ssh-to-age
   ```

2. **Créer et chiffrer les secrets** :
   ```bash
   cp mimosa.yaml.example mimosa.yaml  # Pour le serveur web
   sops mimosa.yaml
   # Éditer, sauvegarder
   ```

3. **Vérifier et committer** :
   ```bash
   cat mimosa.yaml | grep "sops:"  # Doit afficher du contenu chiffré
   git add -f mimosa.yaml
   git commit -m "🔒 Add encrypted secrets"
   ```

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
