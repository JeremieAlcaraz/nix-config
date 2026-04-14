# epic-poppy-backup-restic

## Objectif

Refondre le système de backup de Poppy autour de **restic + rclone** pour remplacer les scripts customs actuels (memos, vikunja, moodboard, twenty) par une solution unifiée avec versioning automatique.

## Contexte

- Poppy héberge 4 apps via podman-compose : memos, vikunja, moodboard, twenty
- Chaque app a un script de backup custom qui upload un fichier "latest" sans versioning
- rclone sync écrase le fichier sur Drive → pas d'historique
- Restore manuel = commandes spécifiques par app

## Pourquoi restic

| Problème actuel | Ce que restic apporte |
|---|---|
| Pas de versioning (fichiers écrasés à chaque run) | Snapshots horodatés, prune automatique |
| Scripts customs par app (5 scripts différents) | 1 binary, même interface pour tout |
| Dedup manuel impossible | Dedup natif (stockage Drive limité = c'est bien) |
| Restore = commandes manuelles | `restic restore latest --target /` |

## Scope

- **T01**: Installer restic + initialiser 4 repositories sur Drive
- **T02**: Migrer les scripts de backup → restic backup (une commande par app)
- **T03**: Intégrer prune automatique (`restic forget --keep-daily 7 --prune`)
- **T04**: Créer `hosts/poppy/justfile` avec `just restore` interactif (gum picker)
- **T05**: Tests de restore sur chaque app + documentation

## Non-scope

- Changement d'infrastructure (Garage S3 reste inchangé)
- Migration des données existantes (fresh restic repo)
- Backup du datastore Proxmox (PBS reste sur rclone sync)

## Bénéfices

- Versioning automatique (7 snapshots conservés)
- Dedup natif (économie de place sur Drive)
- 1 outil pour tout (memos, vikunja, moodboard, twenty)
- Restore interactif en 30 secondes via `just restore`
- Checksums + encryption sur Drive
