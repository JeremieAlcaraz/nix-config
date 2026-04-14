# Restic + rclone sur Poppy

## Pourquoi restic change la donne ici

| Problème actuel | Ce que restic apporte |
|---|---|
| Pas de versioning (fichiers écrasés à chaque run) | Snapshots horodatés, prune automatique |
| Scripts customs par app (5 scripts différents) | 1 binary, même interface pour tout |
| Dedup manuel impossible | Dedup natif (stockage Drive limité = c'est bien) |
| Restore = commandes manuelles | `restic restore latest --target /` |

## Concrètement sur Poppy

```bash
# Installer
apt-get install restic  # ou binaire unique

# 4 repositories (un par app)
restic --repo rclone:gdrive_capsule:memos-s3/      backup /root/apps/memos/data
restic --repo rclone:gdrive_capsule:vikunja-bak/   backup /root/apps/vikunja/data
restic --repo rclone:gdrive_capsule:moodboard-bak/ backup /root/apps/moodboard/data
restic --repo rclone:gdrive_capsule:twenty-bak/    backup /root/apps/twenty/data

# Voir l'historique
restic --repo rclone:gdrive_capsule:twenty-bak/ snapshots

# Restore une version
restic --repo rclone:gdrive_capsule:twenty-bak/ restore latest --target /tmp/restore-twenty/
```

## Les gains concrets

- **Versioning automatique** : 7 snapshots conservés par défaut (configurable)
- **Dedup** : si 95% des données sont identiques entre 2 backups, seul le delta est uploadé → экономия места на Drive
- **1 outil pour tout** : plus de `pg_dump`, `tar.gz`, `rclone copy`, tout passe par restic
- **Checksums + encryption** : les données sur Drive sont chiffrées par restic (option `--password-command`)
- **Restore sélectif** : on peut restaurer un fichier précis, pas besoin de tout dezipper
- **Prune automatique** : `restic forget --keep-daily 7 --prune` dans un cron

## Les points d'attention

| Concern | Solution |
|---|---|
| RAM (restic load index in memory) | Fonctionne bien sur Poppy (2 Go RAM, les volumes sont petits) |
| Nécessite apt/install | 1 ligne dans `apply-remote.sh` |
| Encryption des secrets restic | `RESTIC_PASSWORD` dans SOPS |
| Restore sans arrêter le service | `systemctl stop <app>.service` avant restore |
| Pas de fichier "latest" lisible | Les snapshots sont dans le repo, pas en fichier plain |

## Ce que je te recommande

**Oui, restic + rclone est le bon choix pour Poppy parce que :**
1. On a plusieurs apps avec des formats de backup différents → restic unifie
2. Le storage Drive est limité → dedup compense
3. Le versioning résout le problème de "latest only"
4. Restore interactif propre avec `just restore`

Ca vaut le coup de refondre les backups autour de restic plutôt que de patcher les scripts existants.
