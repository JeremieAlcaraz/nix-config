# Inventaire applicatif — poppy

Ce document décrit l'état **déclaratif** des applications hébergées sous `/root/apps` sur `poppy`.

> Note: le chemin `/apps` n'existe pas sur l'hôte, le chemin réel est `/root/apps`.

## Applications détectées

### memos
- Chemin: `/root/apps/memos`
- Compose: `/root/apps/memos/compose.yml`
- Env: `/root/apps/memos/.env` (depuis `hosts/poppy/apps/memos/.env.template`)
- Port exposé: `5230:5230`
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.memos`)
- Données: `/root/apps/memos/data`
- Sauvegardes: `/root/apps/memos/backups`
- Scripts backup:
  - `/root/apps/memos/scripts/backup.sh` (snapshot SQLite cohérent via `sqlite3 .backup`)
  - `/root/apps/memos/scripts/upload-backups.sh`
- Scheduler: `memos-backup.timer` (05:30, systemd)
- Upload distant: `gdrive_capsule:memos`

### vikunja
- Chemin: `/root/apps/vikunja`
- Compose: `/root/apps/vikunja/compose.yml`
- Env: `/root/apps/vikunja/.env` (depuis `hosts/poppy/apps/vikunja/.env.template`)
- Port exposé: `3456:3456`
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.vikunja`)
- Données:
  - `/root/apps/vikunja/config`
  - `/root/apps/vikunja/data/files`
- Sauvegardes: `/root/apps/vikunja/backups`
- Scripts backup:
  - `/root/apps/vikunja/scripts/backup.sh`
  - `/root/apps/vikunja/scripts/upload-backups.sh`
- Upload distant: `gdrive_capsule:vikunja`

### moodboard
- Chemin: `/root/apps/moodboard`
- Compose: `/root/apps/moodboard/compose.yml`
- Containerfile: `/root/apps/moodboard/Containerfile`
- Garage config: `/root/apps/moodboard/infra/garage/garage-prod.toml`
- Env: `/root/apps/moodboard/.env.prod` (depuis `hosts/poppy/apps/moodboard/.env.template`)
- Ports exposés:
  - `3005:3005` (app)
  - `3900:3900` (garage S3)
  - `3903:3903` (garage admin)
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.moodboard`)
- Données:
  - `/root/apps/moodboard/assets`
  - `/root/apps/moodboard/.local`
- Scripts backup:
  - `/root/apps/moodboard/backup-moodboard.sh`
  - `/root/apps/moodboard/scripts/backup-moodboard.sh`
- Upload distant: `gdrive_capsule:moodboard`

## Runtime

- Toutes les apps tournent via `podman` / `podman-compose`.
- Aucun conteneur applicatif ne doit rester sous `nerdctl`.

## Vérifications minimales

Depuis ce repo:
- `just poppy-check`

Depuis un shell root sur `poppy`:
- `find /root/apps -maxdepth 2 -type d`
- `find /root/apps -maxdepth 4 -type f \( -name 'compose*.yml' -o -name 'docker-compose*.yml' -o -name '*.env' -o -name 'backup*.sh' \)`
