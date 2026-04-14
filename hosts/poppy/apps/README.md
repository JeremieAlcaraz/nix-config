# Apps deployees sur Poppy

## Architecture

```
poppy (PBS Debian)
├── garage (podman S3 service)     :3900
├── memos (podman-compose)          :5230
├── vikunja (podman-compose)        :3080
├── moodboard (podman-compose)      :8080
└── twenty (podman-compose)         :3000
```

## Garage S3 (standalone)

- Chemin: `/root/apps/garage`
- Compose: `/root/apps/garage/compose.yml` (service `garage`)
- Config: `/root/apps/garage/garage-prod.toml` (depuis template + SOPS)
- Ports: `3900` (S3 API), `3903` (admin)
- Donnees: `/root/apps/garage/data`
- Systemd: `garage.service` (demarre avant les apps)
- Buckets: `memos` (attachments memos), `moodboard-dev` (assets moodboard), `twenty` (storage Twenty)
- Secrets Garage: dans `secrets/poppy.yaml` (SOPS, section `apps.garage`)
- Scripts:
  - `garage-bootstrap.sh` (creation buckets + cles, idempotent)
  - `memos-storage-init.sh` (config S3 memos via API + migration DB->S3)
- S3 memos: storage_type = S3 (bucket `memos`), credentials dans la DB memos
- S3 moodboard: bucket `moodboard-dev`, credentials dans env vars
- S3 Twenty: bucket `twenty`, credentials dans `.env` (STORAGE_S3_* vars)

## Apps deployees

| App | Url HTTPS | Local port | Storage | Backup timer |
|-----|-----------|------------|---------|--------------|
| memos | https://memos.inanga-sirius.ts.net | 5230 | Garage S3 | 05h30 |
| vikunja | https://vikunja.inanga-sirius.ts.net | 3080 | PostgreSQL | 04h30 |
| moodboard | https://moodboard.inanga-sirius.ts.net | 8080 | Garage S3 | 05h00 |
| twenty | https://twenty.inanga-sirius.ts.net | 3000 | Garage S3 | 03h00 |

## Runtime

- Toutes les apps tournent via `podman` / `podman-compose`.
- Garage est un service standalone accessible via host port `3900`.
- Memos, moodboard et Twenty se connectent a Garage via `host.containers.internal:3900`.
- Aucun conteneur applicatif ne doit rester sous `nerdctl`.

## Vérifications minimales

Depuis ce repo:
- `just poppy-check`

Depuis un shell root sur `poppy`:
- `find /root/apps -maxdepth 2 -type d`
- `find /root/apps -maxdepth 4 -type f \( -name 'compose*.yml' -o -name 'docker-compose*.yml' -o -name '*.env' -o -name 'backup*.sh' \)`
- `podman exec garage /garage bucket list` (verifier les buckets)
- `podman exec garage /garage key list` (verifier les cles S3)

## Restoration

Outil de restauration declaratif: `hosts/poppy/justfile` (commande `just restore`).
