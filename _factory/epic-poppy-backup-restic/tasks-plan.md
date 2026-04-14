# tasks-plan — epic-poppy-backup-restic

## Ordre d'exécution (séquentiel : 4 commits)

---

## ✅ T01 — Installer restic + initialiser 4 repositories

**Depends on**: nothing
**Changes**:
- `hosts/poppy/bootstrap/apply-remote.sh` → install restic + SOPS password
- `secrets/poppy.yaml` → add `apps.restic.*` (password)
- `secrets/poppy.yaml.example` → document new keys
- `hosts/poppy/scripts/restic-init.sh` → `restic init` for each repo (idempotent)
- `docs/restic/RESTIC.md` → updated with init details

**Benefits**: Prérequis pour tout le reste
**Tests**: `restic snapshots --repo rclone:gdrive_capsule:memos-bak/` → repo accessible
**Commit**: `feat(poppy): install restic + init 4 repositories`

---

## ✅ T02 — Migrer scripts backup → restic backup

**Depends on**: T01
**Changes**:
- `hosts/poppy/scripts/memos-backup-s3.sh` → `restic backup` (data only)
- `hosts/poppy/scripts/vikunja-backup.sh` → `restic backup` (config + data)
- `hosts/poppy/scripts/moodboard-backup.sh` → `restic backup` (assets + .local)
- `hosts/poppy/scripts/twenty-backup.sh` → `restic backup` (volumes db + server-data)
- `hosts/poppy/scripts/garage-bootstrap.sh` → bucket `memos-bak` etc. (optionnel: 4 repos)

**Benefits**: 1 commande par app au lieu de scripts customs
**Tests**:
- `bash /root/apps/memos/scripts/backup.sh` → `restic snapshots` shows new snapshot
- `bash /root/apps/twenty/scripts/backup.sh` → snapshot visible sur Drive
**Commit**: `refactor(poppy): migrate all backup scripts to restic`

---

## ✅ T03 — Prune automatique (restic forget)

**Depends on**: T02
**Changes**:
- Modifier chaque script de backup pour ajouter `restic forget --keep-daily 7 --prune` en fin de run
- Ou créer un timer systemd `restic-prune.timer` quotidien (03:30)

**Benefits**: Disk usage Drive maîtrisé, 7 jours conservés
**Tests**: `restic snapshots --repo ...` → max 7 snapshots par repo
**Commit**: `feat(poppy): add restic prune --keep-daily 7`

---

## ✅ T04 — `just restore` interactif

**Depends on**: T03
**Changes**:
- `hosts/poppy/justfile` → `just restore` (ou `just poppy-restore`)
- Script shell `hosts/poppy/scripts/restore.sh` :
  1. gum choose → sélection de l'app (memos / vikunja / moodboard / twenty)
  2. `restic snapshots --repo <app>` → liste des snapshots (date + taille)
  3. gum choose → sélection de la version (le plus récent en haut)
  4. Confirmation avec gum confirm avant restore
  5. `systemctl stop <app>.service`
  6. `restic restore <snapshot-id> --target /tmp/restore-<app>/`
  7. Copie des fichiers restaurés vers le bon chemin
  8. `systemctl start <app>.service`
  9. Log du restore dans `/var/log/restic-restore.log`

**Benefits**: Restore interactif en 30 secondes
**Tests**: `just poppy-restore` → picker → confirmation → restore OK
**Commit**: `feat(poppy): add just restore interactif with gum picker`

---

## ✅ T05 — Tests + documentation

**Depends on**: T04
**Changes**:
- Tests de restore sur chaque app (dans le tasks-plan.md ou script de test)
- Mise à jour `hosts/poppy/runbook.md` avec section "Restore un backup"
- Mise à jour `hosts/poppy/inventory.yaml` (restic repos, schedule)
- Mise à jour `docs/restic/RESTIC.md` (exemples restore)

**Benefits**: Documentation complète, procédure de restore validée
**Tests**: Toutes les apps testées : dump → restore → vérif健康
**Commit**: `docs(poppy): test restore + update runbook + docs/restic`

---

## Résumé

| # | Task | Depends | Changes | Tests | Commit |
|---|---|---|---|---|---|
| T01 | Installer restic + init repos | — | apply-remote + SOPS + init script | `restic snapshots` OK | `feat(poppy): install restic + init 4 repositories` |
| T02 | Migrer scripts → restic | T01 | 4 scripts backup | snapshots visibles | `refactor(poppy): migrate all backup scripts to restic` |
| T03 | Prune automatique | T02 | prune dans scripts | max 7 snapshots | `feat(poppy): add restic prune --keep-daily 7` |
| T04 | `just restore` interactif | T03 | justfile + restore.sh | restore OK | `feat(poppy): add just restore interactif with gum picker` |
| T05 | Tests + docs | T04 | runbook + inventory | toutes apps OK | `docs(poppy): test restore + update runbook + docs/restic` |

## Table de migration (scripts → restic)

| App | Ancien script | Volume/Data backupé | Repo Drive |
|---|---|---|---|
| memos | `memos-backup-s3.sh` | `/root/apps/memos/data` | `gdrive_capsule:memos-bak/` |
| vikunja | `vikunja-backup.sh` | `/root/apps/vikunja/data` + config | `gdrive_capsule:vikunja-bak/` |
| moodboard | `moodboard-backup.sh` | `/root/apps/moodboard/assets` + `.local` | `gdrive_capsule:moodboard-bak/` |
| twenty | `twenty-backup.sh` | volumes podman (`twenty-db-data`, `twenty-server-data`) | `gdrive_capsule:twenty-bak/` |

**Note**: Pour twenty, on backupe les volumes podman directement via `podman volume inspect` + restic backup du path host.

## Just restore : flow

```
just poppy-restore
  └─> gum choose "Which app?" → memos / vikunja / moodboard / twenty
        └─> restic snapshots --repo <app> (parse date + size)
              └─> gum choose "Which version?" (most recent on top)
                    └─> gum confirm "Restore <app> snapshot <id> ?"
                          └─> systemctl stop <app>.service
                                └─> restic restore <id> --target /tmp/restore-<app>/
                                      └─> cp -r /tmp/restore-<app>/<path> /root/apps/<app>/
                                            └─> systemctl start <app>.service
                                                  └─> echo "Restore done" | gum spin --spinner=line --
```
