# Poppy — Declarative Management Guide

## Qu'est-ce que poppy ?

Poppy est le serveur **Proxmox Backup Server** sous Debian 13, hébergé sur le Proxmox `pve1`.

### Stack applicative

| App | Port | Volume données |
|---|---|---|
| memos | 5230 | `/root/apps/memos/data` |
| vikunja | 3456 | `/root/apps/vikunja/data/files` |
| moodboard | 3005 | `/root/apps/moodboard/` |

### Infrastructure

- Backup PBS : datastore `capsule` → sync quotidien vers Google Drive (`gdrive_capsule`)
- Monitoring : `prometheus-node-exporter` (`:9100`) scraped depuis `myosotis`
- Runtime : `podman` / `podman-compose` (memos, vikunja, moodboard)

---

## Source of Truth — où sont les fichiers ?

### Sur Marigold (= ce dépôt = SoT)

**Tous les fichiers applicatifs viennent de ici.** Pour modifier quelque chose sur poppy, tu modifies ici puis tu re-déploies.

```
/Users/jeremiealcaraz/c/nix-config/hosts/poppy/
├── apps/                      # compose.yml, .env.template, Dockerfile
│   ├── memos/
│   ├── vikunja/
│   └── moodboard/
├── scripts/                  # scripts backup (backup, upload)
│   ├── memos-backup.sh
│   ├── memos-upload-backups.sh
│   ├── vikunja-backup.sh
│   ├── vikunja-upload-backups.sh
│   └── moodboard-backup.sh
├── systemd/                   # units systemd (app + backup timers)
│   ├── memos.service
│   ├── vikunja.service
│   ├── memos-backup.service
│   └── memos-backup.timer
├── bootstrap/
│   └── apply-remote.sh       # script installation idempotent (sur poppy)
├── secrets/                   # secrets/poppy.yaml (SOPS, chiffré)
└── runbook.md                # documentation ops
```

### Sur poppy (= destination finale)

| Path | Contenu | Garder ? |
|---|---|---|
| `/var/lib/poppy-deploy/` | Staging — fichiers du dernier deploy | Oui (ne pas toucher) |
| `/root/apps/<app>/` | Données + configs applicatives | Oui (données) |
| `/root/sync-capsule.sh` | Script sync PBS → Drive (depuis repo) | Oui |
| `/etc/systemd/system/` | Units systemd | Oui (depuis repo) |
| `/root/backup/` | Datastore PBS | Oui (ne pas toucher) |
| `/root/.bak/` | Backups legacy | Garder pour recovery |
| `/root/AGENTS.md` | Cette doc | Oui |
| `/root/go/` | Go runtime (requis PBS) | Oui |

---

## Comment modifier poppy

**Ne jamais modifier les fichiers directement sur poppy.**

Tout passe par ce dépôt sur Marigold → `just poppy-apply`.

### Commandes depuis Marigold

```bash
just poppy-dry-run   # voir ce qui serait déployé (sans rien changer)
just poppy-apply      # déployer vers poppy (idempotent)
just poppy-check      # vérifier l'état
```

### Comment ça marche

1. `scripts/poppy/apply-from-magnolia.sh` (sur Marigold) :
   - Lit `secrets/poppy.yaml` (SOPS) → décrypte secrets
   - Génère les `.env` depuis les templates (placeholders remplacés par secrets)
   - SCP tous les fichiers vers `/var/lib/poppy-deploy/` sur poppy

2. `apply-remote.sh` (sur poppy, dans `/var/lib/poppy-deploy/`) :
   - Déverrouille les fichiers protégés (`chattr -i`)
   - Installe chaque fichier (backup legacy → `/root/.bak/` si existant)
   - Protège les fichiers (`chattr +i`, `chmod 444`)
   - Recharge systemd

---

## Règles importantes

- **Ne pas modifier** `/root/apps/`, `/etc/systemd/system/`, `/root/sync-capsule.sh` **à la main**
- Pour changer un fichier : modifier dans ce repo (Marigold) → `just poppy-apply`
- Les fichiers sur poppy sont **protégés en lecture seule** après déploiement (`chattr +i`)
- En cas de drift, `just poppy-check` le signalera

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

# Deploy staging
ls /var/lib/poppy-deploy/

# Restore depuis .bak (si besoin)
ls /root/.bak/
cp /root/.bak/<file>.bak-XXX /root/<file>
chmod u+w /root/<file>
# puis re-deploy
```

## Accès

- SSH : `ssh poppy`
- Tailscale DNS : `poppy.inanga-sirius.ts.net`
- PBS UI : https://poppy.inanga-sirius.ts.net:8007
- Memos : http://poppy.inanga-sirius.ts.net:5230
- Vikunja : http://poppy.inanga-sirius.ts.net:3456
- Moodboard : http://poppy.inanga-sirius.ts.net:3005