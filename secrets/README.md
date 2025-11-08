# Secrets pour learnix

Ce répertoire contient les secrets chiffrés avec sops pour les différents hôtes.

## ⚠️ IMPORTANT

- **NE JAMAIS** committer de fichiers `.yaml` non chiffrés
- Seuls les fichiers **chiffrés** avec sops peuvent être committés
- Les fichiers `.example` sont des templates et ne contiennent pas de vraies valeurs

## Quick Start

1. **Lire la documentation complète** : [`docs/SECRETS.md`](../docs/SECRETS.md)

2. **Installer les outils** :
   ```bash
   nix-shell -p sops age ssh-to-age
   ```

3. **Récupérer la clé publique de l'hôte** :
   ```bash
   ssh root@jeremie-web "cat /var/lib/sops-nix/key.pub"
   ```

4. **Mettre à jour `.sops.yaml`** avec la vraie clé

5. **Créer et chiffrer les secrets** :
   ```bash
   cp jeremie-web.yaml.example jeremie-web.yaml
   sops jeremie-web.yaml
   # Éditer, sauvegarder
   ```

6. **Vérifier et committer** :
   ```bash
   cat jeremie-web.yaml | grep "sops:"  # Doit afficher du contenu chiffré
   git add -f jeremie-web.yaml
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
