# Runbook - poppy (PBS non-NixOS)

## Contexte

- Hote: `poppy` (Proxmox Backup Server)
- Datastore principal: `capsule` -> `/backup-disk`
- Sync Drive: `rclone sync /backup-disk gdrive_capsule:proxmox`
- Schedule actuel: cron root a `04:00` (quotidien)

## Attention operations

- La commande `rclone sync` est potentiellement destructive cote destination (suppressions).
- Pour un controle sans risque, utiliser d'abord:
  - `hosts/poppy/scripts/verify-drive-target.sh` (read-only)
  - `hosts/poppy/scripts/test-drive-write.sh` (fichier marqueur minimal)

## Verification quotidienne (checklist)

1. Verifier l'etat PBS:
   - `proxmox-backup-manager datastore list`
   - `findmnt -T /backup-disk -o TARGET,SOURCE,FSTYPE,OPTIONS`
2. Verifier le planning:
   - `crontab -l | grep sync-capsule.sh`
3. Verifier logs du dernier run:
   - `tail -n 80 /var/log/rclone-sync.log`
4. Verifier la cible Drive attendue:
   - `./hosts/poppy/scripts/verify-drive-target.sh`
5. Verifier le monitoring node exporter:
   - `systemctl is-active prometheus-node-exporter`
   - `curl -fsS http://127.0.0.1:9100/metrics | head`

## Monitoring Node Exporter (poppy)

Etat cible:
- service systemd: `prometheus-node-exporter` actif et enabled,
- endpoint local: `http://127.0.0.1:9100/metrics` repond,
- scrape distant: `myosotis` voit `http://poppy:9100/metrics` en `health: up`.

Installation (declarative via repo):
- `just poppy-apply` (convergence idempotente: installe/active `prometheus-node-exporter` si absent)

Installation manuelle (fallback):
- `apt-get update && apt-get install -y prometheus-node-exporter`

Validation depuis myosotis:
- `curl -fsS http://127.0.0.1:8428/api/v1/targets | jq -c '.data.activeTargets[] | select(.labels.instance=="poppy:9100") | {health,lastError}'`
- `curl -fsS 'http://127.0.0.1:8428/api/v1/query?query=up{instance="poppy:9100",job="node"}' | jq -c .data.result`

## Garage S3 — memos storage backend

Garage S3 tourne en service standalone (`garage.service`).
Memos utilise Garage comme storage backend pour les attachments (bucket `memos`).
Les credentials S3 sont stockes dans la DB memos, pas dans les env vars.

### Configuration S3 memos (API declarative)

Le storage S3 est configure via l'API Connect-RPC (et non env vars) :

```bash
# 1. Sign-in (necessite le mot de passe admin memos)
TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"passwordCredentials":{"username":"jeremie","password":"<PASS>"}}' \
  http://localhost:5230/memos.api.v1.AuthService/SignIn \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 2. Configurer S3 (voir hosts/poppy/scripts/memos-storage-init.sh)
bash /root/apps/garage/memos-storage-init.sh --password "<PASS>"
```

Le script `memos-storage-init.sh` est deploye par `just poppy-apply`.
Il est idempotent (verification du storage type avant action).

### Backup S3 memos (historique)

Ce flux legacy (`memos-s3-backup.timer`) est désormais désactivé en mode restic-only.
Les objets S3 doivent être restaurés via le flux stack-aware (garage-first).

### Status Garage

```bash
podman exec garage /garage bucket list
podman exec garage /garage key list
```

## Scripts backup versionnes (source de verite)

Scripts versionnes dans ce depot (et deployes via `just poppy-apply`):
- `hosts/poppy/scripts/sync-capsule.sh` -> `/root/sync-capsule.sh`
- `hosts/poppy/scripts/memos-backup.sh` -> `/root/apps/memos/scripts/backup.sh`
- `hosts/poppy/scripts/memos-upload-backups.sh` -> `/root/apps/memos/scripts/upload-backups.sh`
- `hosts/poppy/scripts/memos-backup-s3.sh` -> `/root/apps/memos/scripts/backup-s3.sh`
- `hosts/poppy/systemd/memos-backup.service` -> `/etc/systemd/system/memos-backup.service`
- `hosts/poppy/systemd/memos-backup.timer` -> `/etc/systemd/system/memos-backup.timer`
- `hosts/poppy/scripts/vikunja-backup.sh` -> `/root/apps/vikunja/scripts/backup.sh`
- `hosts/poppy/scripts/vikunja-upload-backups.sh` -> `/root/apps/vikunja/scripts/upload-backups.sh`
- `hosts/poppy/scripts/moodboard-backup.sh` -> `/root/apps/moodboard/{backup-moodboard.sh,scripts/backup-moodboard.sh}`
- `hosts/poppy/scripts/garage-bootstrap.sh` -> `/root/apps/garage/garage-bootstrap.sh`
- `hosts/poppy/scripts/memos-storage-init.sh` -> `/root/apps/garage/memos-storage-init.sh` (S3 config API)
- `hosts/poppy/scripts/memos-storage-migrate.sh` -> `/root/apps/memos/scripts/migrate-to-s3.sh` (migration DB->S3)

## Verification de cible Drive (read-only)

Script: `hosts/poppy/scripts/verify-drive-target.sh`

Ce script:
- verifie la presence de la remote `gdrive_capsule`,
- controle `root_folder_id`,
- liste les dossiers au niveau racine cible,
- verifie l'existence du dossier `proxmox/`.

## Test d'ecriture minimal

Script: `hosts/poppy/scripts/test-drive-write.sh`

Ce script:
- ecrit un unique fichier marqueur horodate dans `gdrive_capsule:proxmox/`,
- reliste le fichier pour confirmer la presence.

Variables utiles:
- `RCLONE_REMOTE` (defaut `gdrive_capsule`)
- `RCLONE_SUBPATH` (defaut `proxmox`)
- `TEST_PREFIX` (defaut `_codex-drive-target-test`)

## Incident: la sync part au mauvais endroit

1. Verifier le `root_folder_id` dans `rclone.conf`.
2. Verifier la destination dans `sync-capsule.sh`:
   - attendu: `gdrive_capsule:proxmox`
3. Executer `verify-drive-target.sh`.
4. Faire un test marqueur avec `test-drive-write.sh`.
5. Ne pas relancer un `rclone sync` complet tant que la cible n'est pas validee.

## Incident: token OAuth expire

Symptomes:
- erreurs 401/403 dans `rclone-sync.log`,
- demande de re-auth lors d'une commande `rclone config`.

Actions:
1. re-authentifier la remote selon la procedure interne,
2. verifier de nouveau avec `verify-drive-target.sh`,
3. tester avec `test-drive-write.sh`.

## Rollback pragmatique

Si une modification de script/config degrade le comportement:
1. restaurer la derniere version connue du script `sync-capsule.sh`,
2. restaurer la derniere conf rclone valide,
3. valider via script read-only,
4. lancer seulement ensuite une synchro reelle.

## Politique secrets

- Ne jamais committer de token OAuth, refresh token, client secret, mots de passe.
- Versionner uniquement des exemples sanitises (`*.example`).
- Stocker les secrets hors git (SOPS/gestionnaire de secrets/variables runtime).

## Bootstrap depuis magnolia (SOPS + SSH)

Prerequis:
- `secrets/poppy.yaml` present et chiffre SOPS.
- acces SSH `root@poppy` fonctionnel.
- outils locaux: `sops`, `yq`, `ssh`, `scp`.

Commandes:
1. Dry-run (obligatoire):
   - `just poppy-dry-run`
2. Apply:
   - `just poppy-apply`
3. Verification post-apply:
   - `just poppy-check`
   - optionnel: `just poppy-tail-sync-log`

Ce que fait l'apply:
- decrypte localement `secrets/poppy.yaml` en temporaire securise,
- genere `rclone.conf` + `sync-capsule.sh` + ligne cron,
- genere les `.env` depuis templates + secrets SOPS,
- pousse compose/systemd/scripts via staging `/var/lib/poppy-deploy`,
- pousse et active les services/timers systemd applicatifs,
- applique de maniere idempotente avec backup legacy dans `/root/.bak/`.


## Twenty CRM

Twenty CRM tourne en service via `podman-compose` (4 containers).

### URLs
- **HTTPS**: `https://twenty.inanga-sirius.ts.net` (via Tailscale svc:twenty)
- **Local**: `http://poppy:3000`

### Containers
```bash
podman ps --format "{{.Names}} ({{.Status}})" | grep twenty
# twenty-server  twenty-worker  twenty-db  twenty-redis
```

### Configuration S3 (storage)
Twenty utilise Garage S3 comme backend storage (bucket `twenty`).
Les credentials sont dans SOPS (`apps.twenty.*`).

### Backup quotidien
Le flux legacy `twenty-backup.timer` est désactivé en mode restic-only.
Le backup Twenty est désormais assuré par `twenty-restic-backup.timer`.

### Logs
```bash
tail -f /var/log/twenty-backup.log
```

### Status systemd
```bash
systemctl status twenty.service
systemctl status twenty-backup.timer
```

### Restoration
Voir `hosts/poppy/justfile`:
- `just restore` (app-only, usage expert)
- `just restore-stack app=<memos|moodboard|twenty|vikunja>` (recommande)

Guide court incident: `hosts/poppy/URGENT_RESTORE.md`
Guide break-glass (secrets + recovery): `hosts/poppy/BREAK_GLASS.md`

Regle d'or:
- apps S3-dependantes (`memos`, `moodboard`, `twenty`) => restaurer Garage d'abord.
- `vikunja` => restore app-only.

Checklist post-restore:
```bash
systemctl is-active garage.service memos.service moodboard.service twenty.service vikunja.service
RESTIC_PASSWORD="$(grep ^RESTIC_PASSWORD= /root/.config/restic/env | tr -d "'" | cut -d= -f2)"; export RESTIC_PASSWORD
for repo in memos vikunja moodboard twenty; do
  echo "=== $repo ==="
  restic snapshots --repo "rclone:gdrive_capsule:$repo" --compact | tail -n 4
done
```


## Migration restic-only (audit T01 — 2026-04-16)

Constat audite:
- timers legacy actifs: `memos-backup.timer`, `memos-s3-backup.timer`, `backup-moodboard.timer`, `twenty-backup.timer`.
- timer casse: `vikunja-backup.timer` (`unit not found`).
- restic: repos `*-bak` existants et lisibles, mais pas de timers backup restic par app.
- Drive: coexistence `app` + `app-bak` pour les 4 apps.

Strategie validee (ordre):
1. Reconfigurer restic vers les repos canoniques `gdrive_capsule:memos|vikunja|moodboard|twenty`.
2. Activer des timers backup restic par app (et garder `restic-prune.timer`).
3. Desactiver les timers/services legacy applicatifs.
4. Valider par tests E2E restore: Twenty puis Vikunja.

Etat courant (2026-04-17):
- Timers restic actifs: `garage-restic-backup.timer`, `memos-restic-backup.timer`, `vikunja-restic-backup.timer`, `moodboard-restic-backup.timer`, `twenty-restic-backup.timer`, `restic-prune.timer`.
- Timers legacy desactives: `memos-backup.timer`, `memos-s3-backup.timer`, `backup-moodboard.timer`, `twenty-backup.timer`.
- `vikunja-backup.timer` legacy: absent/casse (not-found).
- Tests restore E2E valides: Twenty + Vikunja.

Plan cleanup legacy Drive (.bak) — apres validation finale:
```bash
# 1) Inventaire (read-only)
for p in memos memos-bak vikunja vikunja-bak moodboard moodboard-bak twenty twenty-bak; do
  echo "=== $p ==="
  rclone lsf "gdrive_capsule:${p}" --max-depth 1 | head -n 20
done

# 2) Safety tag avant suppression (copie manifeste)
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p /root/cleanup-manifests
for p in memos-bak vikunja-bak moodboard-bak twenty-bak; do
  rclone lsf -R "gdrive_capsule:${p}" > "/root/cleanup-manifests/${p}-${TS}.txt"
done

# 3) Suppression controlee (uniquement legacy, jamais canonical)
# rclone purge "gdrive_capsule:memos-bak"
# rclone purge "gdrive_capsule:vikunja-bak"
# rclone purge "gdrive_capsule:moodboard-bak"
# rclone purge "gdrive_capsule:twenty-bak"

# 4) Verification post-cleanup
for p in memos vikunja moodboard twenty; do
  restic snapshots --repo "rclone:gdrive_capsule:${p}" --compact | tail -n 4
done
```

## Rollback bootstrap

En cas de regression apres apply:
1. Se connecter sur `poppy`.
2. Restaurer le dernier backup legacy depuis `/root/.bak/` (fichiers nommés avec path encodé):
   - ex `cp /root/.bak/root__sync-capsule.sh.bak-<ts> /root/sync-capsule.sh && chmod 700 /root/sync-capsule.sh`
   - ex `cp /root/.bak/root__.config__rclone__rclone.conf.bak-<ts> /root/.config/rclone/rclone.conf`
3. Si besoin, re-appliquer:
   - `just poppy-apply`
4. Verifier la crontab:
   - `crontab -l | grep sync-capsule.sh`
5. Revalider la cible:
   - `just poppy-check`
