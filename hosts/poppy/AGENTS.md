# Poppy — Declarative Management Guide

## Qu'est-ce que poppy ?

Poppy est le serveur **Proxmox Backup Server** sous Debian 13, hébergé sur leProxmox `pve1`.

### Stack applicative

| App | Port | Volume données |
|---|---|---|
| memos | 5230 | `/root/apps/memos/data` |
| vikunja | 3456 | `/root/apps/vikunja/data/files` |
| moodboard | 3005 | `/root/apps/moodboard/` |

### Infrastructure

- Backup PBS : datastore `capsule` → sync quotidien vers Google Drive (`gdrive_capsule`)
- Monitoring : `prometheus-node-exporter` (`:9100`) scraped depuis `myosotis`
- Runtime : `podman` (vikunja) + `docker compose` (memos, moodboard)

---

## Comment modifier poppy

**Ne jamais modifier les fichiers directement sur poppy.**

Tout passe par ce dépôt (repo `nix-config` sur Marigold).

### Sources de vérité (sur Marigold)

```
/Users/jeremiealcaraz/c/nix-config/hosts/poppy/
├── apps/                    # compose.yml, .env.template, Dockerfile
│   ├── memos/
│   ├── vikunja/
│   └── moodboard/
├── scripts/                 # scripts backup (backup, upload)
│   ├── memos-backup.sh
│   ├── memos-upload-backups.sh
│   ├── vikunja-backup.sh
│   ├── vikunja-upload-backups.sh
│   └── moodboard-backup.sh
├── systemd/                 # units systemd (app + backup timers)
│   ├── memos.service
│   ├── vikunja.service
│   ├── memos-backup.service
│   └── memos-backup.timer
├── bootstrap/
│   └── apply-remote.sh      # script d'installation idempotent
├── secrets/                 # (sur Marigold) secrets/poppy.yaml (SOPS)
└── runbook.md               # documentation ops
```

### Comment apply

Depuis **Marigold** (ce dépôt) :

```bash
just poppy-dry-run   # voir ce qui serait déployé
just poppy-apply      # déployer vers poppy (idempotent)
just poppy-check      # vérifier l'état
```

### Comment ça marche

1. `apply-from-magnolia.sh` (sur Marigold) :
   - Lit `secrets/poppy.yaml` (SOPS) → décrypte secrets
   - Génère les `.env` depuis les templates (placeholders remplacés par secrets)
   - SCP tous les fichiers vers `/tmp/poppy-bootstrap/` sur poppy

2. `apply-remote.sh` (sur poppy) :
   - Installe chaque fichier (backup `.bak-*` si existant)
   - Set les permissions restrictives (readonly)
   - Recharge systemd

---

## Règles importantes

- **Ne pas modifier `/root/apps/`, `/etc/systemd/system/`, `/root/sync-capsule.sh` à la main**
- Tout changement = modifier les fichiers dans ce dépôt sur Marigold → `just poppy-apply`
- Les fichiers sur poppy sont **protégés en lecture seule** après déploiement
- En cas de drift détecté, `just poppy-check` le signalera

## Drift detection (T5)

Le script `check.sh` (via `just poppy-check`) détecte si un fichier a été modifié hors repo.

## Logs et troubleshooting

```bash
# Logs backup
journalctl -u memos-backup.service -n 20 --no-pager
journalctl -u vikunja-backup.service -n 20 --no-pager
journalctl -u backup-moodboard.service -n 20 --no-pager

# Logs app
podman logs memos
podman logs vikunja

# Status services
systemctl status memos.service vikunja.service memos-backup.timer

# Drive backup
rclone lsf gdrive_capsule:memos
rclone lsf gdrive_capsule:vikunja
rclone lsf gdrive_capsule:moodboard/daily
```

## Accès

- SSH : `ssh poppy`
- Tailscale DNS : `poppy.inanga-sirius.ts.net`
- PBS UI : https://poppy.inanga-sirius.ts.net:8007
- Memos : http://poppy.inanga-sirius.ts.net:5230
- Vikunja : http://poppy.inanga-sirius.ts.net:3456
- Moodboard : http://poppy.inanga-sirius.ts.net:3005