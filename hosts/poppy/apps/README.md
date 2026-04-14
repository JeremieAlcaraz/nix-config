# Inventaire applicatif — poppy

Ce document décrit l'état **déclaratif** des applications hébergées sous `/root/apps` sur `poppy`.

> Note: le chemin `/apps` n'existe pas sur l'hôte, le chemin réel est `/root/apps`.

## Applications détectées

### memos
- Chemin: `/root/apps/memos`
- Compose: `/root/apps/memos/compose.yml`
- Env: `/root/apps/memos/.env` (depuis `hosts/poppy/apps/memos/.env.template`)
- Port expose: `5230:5230`
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.memos`)
- Donnees: `/root/apps/memos/data`
- Sauvegardes: `/root/apps/memos/backups`
- Scripts backup:
  - `/root/apps/memos/scripts/backup.sh` (snapshot SQLite coherent via `sqlite3 .backup`)
  - `/root/apps/memos/scripts/upload-backups.sh`
- Scheduler: `memos-backup.timer` (05:30, systemd)
- Upload distant: `gdrive_capsule:memos`
- **S3 Storage**: memos stocke ses attachments dans Garage S3 (bucket `memos`).
  Configuration S3 via API (storage_type = S3), credentials dans la DB.
  See: `hosts/poppy/scripts/memos-storage-init.sh`

### vikunja
- Chemin: `/root/apps/vikunja`
- Compose: `/root/apps/vikunja/compose.yml`
- Env: `/root/apps/vikunja/.env` (depuis `hosts/poppy/apps/vikunja/.env.template`)
- Port expose: `3456:3456`
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.vikunja`)
- Donnees:
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
- Env: `/root/apps/moodboard/.env.prod` (depuis `hosts/poppy/apps/moodboard/.env.template`)
- Port expose: `3005:3005`
- Garage S3: endpoint `http://host.containers.internal:3900` (service partage)
- Secrets: dans `secrets/poppy.yaml` (SOPS, section `apps.moodboard`)
- Donnees:
  - `/root/apps/moodboard/assets`
  - `/root/apps/moodboard/.local`
- Scripts backup:
  - `/root/apps/moodboard/backup-moodboard.sh`
  - `/root/apps/moodboard/scripts/backup-moodboard.sh`
- Upload distant: `gdrive_capsule:moodboard`

### Garage S3 (standalone)
- Chemin: `/root/apps/garage`
- Compose: `/root/apps/garage/compose.yml` (service `garage`)
- Config: `/root/apps/garage/garage-prod.toml` (depuis template + SOPS)
- Ports: `3900` (S3 API), `3903` (admin)
- Donnees: `/root/apps/garage/data`
- Systemd: `garage.service` (demarre avant les apps)
- Buckets: `memos` (attachments memos), `moodboard-dev` (assets moodboard)
- Secrets Garage: dans `secrets/poppy.yaml` (SOPS, section `apps.garage`)
- Scripts:
  - `garage-bootstrap.sh` (creation buckets + cles, idempotent)
  - `memos-storage-init.sh` (config S3 memos via API + migration DB->S3)
- S3 memos: storage_type = S3 (bucket `memos`), credentials dans la DB memos
- S3 moodboard: bucket `moodboard-dev`, credentials dans env vars

## Runtime

- Toutes les apps tournent via `podman` / `podman-compose`.
- Garage est un service standalone accessible via host port `3900`.
- Memos et moodboard se connectent a Garage via `host.containers.internal:3900`.
- Aucun conteneur applicatif ne doit rester sous `nerdctl`.

## Vérifications minimales

Depuis ce repo:
- `just poppy-check`

Depuis un shell root sur `poppy`:
- `find /root/apps -maxdepth 2 -type d`
- `find /root/apps -maxdepth 4 -type f \( -name 'compose*.yml' -o -name 'docker-compose*.yml' -o -name '*.env' -o -name 'backup*.sh' \)`
- `podman exec garage /garage bucket list` (verifier les buckets)
- `podman exec garage /garage key list` (verifier les cles S3)
