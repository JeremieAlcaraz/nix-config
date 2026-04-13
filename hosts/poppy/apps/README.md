# Inventaire applicatif — poppy

Ce document décrit l'état **déclaratif** des applications hébergées sous `/root/apps` sur `poppy`.

> Note: le chemin `/apps` n'existe pas sur l'hôte, le chemin réel est `/root/apps`.

## Applications détectées

### memos
- Chemin: `/root/apps/memos`
- Compose: `/root/apps/memos/compose.yml`
- Port exposé: `5230:5230`
- Données: `/root/apps/memos/data`
- Sauvegardes: `/root/apps/memos/backups`
- Script backup: `/root/apps/memos/scripts/backup.sh`

### vikunja
- Chemin: `/root/apps/vikunja`
- Compose: `/root/apps/vikunja/compose.yml`
- Env: `/root/apps/vikunja/.env`
- Port exposé: `3456:3456`
- Données:
  - `/root/apps/vikunja/config`
  - `/root/apps/vikunja/data/files`
- Sauvegardes: `/root/apps/vikunja/backups`
- Scripts backup:
  - `/root/apps/vikunja/scripts/backup.sh`
  - `/root/apps/vikunja/scripts/upload-backups.sh`

### moodboard
- Chemin: `/root/apps/moodboard`
- Compose: `/root/apps/moodboard/compose.yml`
- Ports exposés:
  - `3005:3005` (app)
  - `3900:3900` (garage S3)
  - `3903:3903` (garage admin)
- Données:
  - `/root/apps/moodboard/assets`
  - `/root/apps/moodboard/.local`
- Scripts backup:
  - `/root/apps/moodboard/backup-moodboard.sh`
  - `/root/apps/moodboard/scripts/backup-moodboard.sh`

## Vérifications minimales

Depuis ce repo:
- `just poppy-check`

Depuis un shell root sur `poppy`:
- `find /root/apps -maxdepth 2 -type d`
- `find /root/apps -maxdepth 4 -type f \( -name 'compose*.yml' -o -name 'docker-compose*.yml' -o -name '*.env' -o -name 'backup*.sh' \)`
