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

## Scripts backup versionnes (source de verite)

Scripts versionnes dans ce depot (et deployes via `just poppy-apply`):
- `hosts/poppy/scripts/sync-capsule.sh` -> `/root/sync-capsule.sh`
- `hosts/poppy/scripts/memos-backup.sh` -> `/root/apps/memos/scripts/backup.sh`
- `hosts/poppy/scripts/memos-upload-backups.sh` -> `/root/apps/memos/scripts/upload-backups.sh`
- `hosts/poppy/systemd/memos-backup.service` -> `/etc/systemd/system/memos-backup.service`
- `hosts/poppy/systemd/memos-backup.timer` -> `/etc/systemd/system/memos-backup.timer`
- `hosts/poppy/scripts/vikunja-backup.sh` -> `/root/apps/vikunja/scripts/backup.sh`
- `hosts/poppy/scripts/vikunja-upload-backups.sh` -> `/root/apps/vikunja/scripts/upload-backups.sh`
- `hosts/poppy/scripts/moodboard-backup.sh` -> `/root/apps/moodboard/{backup-moodboard.sh,scripts/backup-moodboard.sh}`

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
- pousse aussi les scripts backup versionnes (memos/vikunja/moodboard),
- pousse et active le timer systemd `memos-backup.timer`,
- applique de maniere idempotente avec backup local des scripts/conf precedents.

## Rollback bootstrap

En cas de regression apres apply:
1. Se connecter sur `poppy`.
2. Restaurer le dernier backup `rclone.conf.bak-*`:
   - `cp /root/.config/rclone/rclone.conf.bak-<ts> /root/.config/rclone/rclone.conf`
3. Restaurer le dernier backup `sync-capsule.sh.bak-*`:
   - `cp /root/sync-capsule.sh.bak-<ts> /root/sync-capsule.sh && chmod 700 /root/sync-capsule.sh`
4. Verifier la crontab:
   - `crontab -l | grep sync-capsule.sh`
5. Revalider la cible:
   - `just poppy-check`
