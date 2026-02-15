# INDEX - poppy

## Fichiers principaux

- `hosts/poppy/README.md`: contexte hote, statut non-NixOS, flux PBS -> Drive.
- `hosts/poppy/runbook.md`: exploitation, verifications, incidents, rollback.
- `hosts/poppy/BACKLOG-V2.md`: suite du chantier (hardening et evolution ops).
- `hosts/poppy/inventory.yaml`: metadonnees d'inventaire local.

## Scripts

- `hosts/poppy/scripts/sync-capsule.sh`: script de sync principal (`rclone sync`).
- `hosts/poppy/scripts/verify-drive-target.sh`: verification read-only de la cible Drive.
- `hosts/poppy/scripts/test-drive-write.sh`: test d'ecriture minimal (fichier marqueur).
- `hosts/poppy/bootstrap/apply-remote.sh`: application idempotente cote `poppy`.
- `scripts/poppy/apply-from-magnolia.sh`: orchestrateur push (SOPS -> SSH).
- `scripts/poppy/check.sh`: checks post-apply depuis `magnolia`.

## Config templates

- `hosts/poppy/rclone/rclone.conf.example`: template rclone sans secrets.
- `hosts/poppy/cron/root.crontab.example`: cron root actuel (sync quotidienne 04:00).
