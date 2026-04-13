# poppy - Proxmox Backup Server (hors NixOS)

## Statut

`poppy` n'est **pas** un hôte NixOS et n'est **pas** piloté par `nixos-rebuild`.

Ce dossier existe pour la déclaration, la traçabilité et la reproductibilité opérationnelle:
- documentation système et réseau,
- scripts d'exploitation,
- templates de configuration,
- runbooks.

## Portee

- Ce dépôt ne déploie pas `poppy`.
- Ce dépôt documente `poppy` comme source de vérité infra.
- Les secrets ne sont pas commités en clair.

## Identite machine (etat releve)

- Hostname: `poppy`
- FQDN local: `poppy.local`
- Role: `Proxmox Backup Server` (backup central)
- Version PBS package: `proxmox-backup-server 4.1.6-1`
- Version runtime relevee: `4.1.0`
- OS base: `Debian GNU/Linux 13 (trixie)`
- Kernel: `6.17.2-1-pve`
- Tailscale IPv4: `100.120.10.61`
- Tailscale DNS: `poppy.inanga-sirius.ts.net`

## ISO PBS

- ISO PBS precise: **a confirmer manuellement** (non retrouvee de facon fiable dans les logs presentes).
- Indice technique: stack en `PBS 4.1.x` sur Debian 13.
- Cible documentaire v1: noter explicitement le nom exact du media utilise (ex: `proxmox-backup-server_4.1-*.iso`) des que retrouve.

## Arborescence

- `hosts/poppy/scripts/`: scripts exploités sur le nœud.
- `hosts/poppy/rclone/`: templates de conf `rclone` sans secrets.
- `hosts/poppy/cron/`: exemples de scheduling (cron/systemd).
- `hosts/poppy/runbook.md`: procédures d'exploitation et incident.
- `hosts/poppy/inventory.yaml`: métadonnées hôte (inventaire local).

## Audit technique (2026-04-13)

- Service `node-exporter`: **absent** (`systemd: not-found`, port `9100` non exposé)
- Endpoint métriques local `http://127.0.0.1:9100/metrics`: **KO**
- Arborescence applicative détectée: `/root/apps` (et non `/apps`)
- Apps détectées: `memos`, `moodboard`, `vikunja`
- Script de sync PBS actif: `/root/sync-capsule.sh`
- Scheduling actuel: cron root `0 4 * * *`

## Stockage PBS (etat actuel)

- Datastore PBS: `capsule`
- Path datastore: `/backup-disk`
- Montages: `/backup-disk` est actuellement un dossier sur la racine `/` (pas un volume monte separement)
- Fichier source: `/etc/proxmox-backup/datastore.cfg`

## Flux fonctionnel (PBS -> Google Drive)

1. Les sauvegardes PBS sont ecrites localement dans `/backup-disk` (index VM + `.chunks`).
2. Un job cron root lance chaque jour a `04:00` le script `/root/sync-capsule.sh`.
3. Le script execute: `rclone sync /backup-disk "gdrive_capsule:proxmox" ...`
4. La remote `gdrive_capsule` est scopee vers le dossier Drive:
   - `root_folder_id = 1q9urpon7tZUSdeO1UfW3kIM8feURFIYe`
5. Resultat:
   - Le contenu arrive sous `<folder_id>/proxmox/` et non a la racine globale du Drive.
6. Logs:
   - sortie job/script: `/var/log/rclone-sync.log`

## Fichiers de reference versionnes ici

- Script sync: `hosts/poppy/scripts/sync-capsule.sh`
- Template rclone: `hosts/poppy/rclone/rclone.conf.example`
- Planning cron: `hosts/poppy/cron/root.crontab.example`

## A completer (prochaines taches)

- confirmer le nom exact de l'ISO PBS utilisee a l'installation,
- ajouter les scripts de verification (read-only + test marker) et procedures de recovery detaillees.
