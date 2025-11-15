# Script de Backup n8n

## Description

`backup-n8n.sh` est un script complet de sauvegarde pour votre instance n8n. Il crée une archive complète contenant :

- Variables d'environnement du container n8n
- Clé d'encryption (critique pour les credentials)
- Dump complet de la base PostgreSQL
- Fichiers de données n8n (community nodes, configs, SSH keys)
- Fichier de configuration pour la migration
- README avec instructions de restauration

## Prérequis

- n8n fonctionnel avec Podman
- PostgreSQL configuré
- Droits sudo pour accéder aux containers et à la base
- Espace disque suffisant dans `~/Downloads`

## Utilisation

### Backup complet

```bash
sudo ./scripts/backup-n8n.sh
```

Le script va :
1. Récupérer les variables d'environnement
2. Extraire la clé d'encryption
3. Arrêter n8n temporairement
4. Sauvegarder la base PostgreSQL
5. Sauvegarder les fichiers n8n
6. Créer les fichiers de configuration
7. Compresser le tout dans une archive
8. Générer un hash SHA256
9. Redémarrer n8n

### Emplacement du backup

Le backup est créé dans `~/Downloads/` :
- `n8n_migration_YYYYMMDD_HHMMSS.tar.gz` - Archive complète
- `n8n_migration_YYYYMMDD_HHMMSS.tar.gz.sha256` - Hash d'intégrité

### Vérification de l'intégrité

```bash
cd ~/Downloads
sha256sum -c n8n_migration_*.tar.gz.sha256
```

Doit afficher : `OK`

### Contenu de l'archive

```bash
tar tzf n8n_migration_*.tar.gz
```

## Sécurité

**IMPORTANT** : L'archive contient la clé d'encryption n8n dans `migration_config.txt`. Cette clé est **CRITIQUE** pour décrypter les credentials.

- Stockez cette archive dans un endroit sécurisé
- Sauvegardez la clé d'encryption séparément dans un gestionnaire de mots de passe
- Ne partagez jamais cette archive publiquement

## Restauration

Pour restaurer ce backup sur une nouvelle installation, consultez la section appropriée du guide de migration n8n.

## Dépannage

Si le backup échoue :

1. Vérifiez que n8n tourne : `sudo podman ps | grep n8n`
2. Vérifiez l'espace disque : `df -h ~/Downloads`
3. Consultez les logs : `journalctl -u podman-n8n.service -n 50`

## Test sans impact

Pour tester le script sans arrêter n8n, vous pouvez commenter les lignes d'arrêt/démarrage (étapes 3 et fin du script). Cependant, le backup peut être inconsistant.
