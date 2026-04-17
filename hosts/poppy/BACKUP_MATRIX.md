# Backup/Restore Matrix — poppy

## Référence rapide

| App | Service backup | Fréquence backup | Repo Drive (restic) | Prune | Commande restore recommandée |
|---|---|---|---|---|---|
| garage (S3) | `garage-restic-backup.service` (`garage-restic-backup.timer`) | `OnCalendar=*-*-* 01:20:00` (+ `RandomizedDelaySec=5m`) | `rclone:gdrive_capsule:garage` | via `restic-prune.timer` `03:30` quotidien + forget local du script garage | `just --justfile hosts/poppy/justfile restore-stack app=memos` (ou moodboard/twenty, garage-first) |
| memos | `memos-restic-backup.service` (`memos-restic-backup.timer`) | `OnCalendar=*-*-* 02:00:00` (+5m) | `rclone:gdrive_capsule:memos` | `restic-prune.timer` `03:30` quotidien | `just --justfile hosts/poppy/justfile restore-stack app=memos` |
| vikunja | `vikunja-restic-backup.service` (`vikunja-restic-backup.timer`) | `OnCalendar=*-*-* 02:20:00` (+5m) | `rclone:gdrive_capsule:vikunja` | `restic-prune.timer` `03:30` quotidien | `just --justfile hosts/poppy/justfile restore-stack app=vikunja` |
| moodboard | `moodboard-restic-backup.service` (`moodboard-restic-backup.timer`) | `OnCalendar=*-*-* 02:40:00` (+5m) | `rclone:gdrive_capsule:moodboard` | `restic-prune.timer` `03:30` quotidien | `just --justfile hosts/poppy/justfile restore-stack app=moodboard` |
| twenty | `twenty-restic-backup.service` (`twenty-restic-backup.timer`) | `OnCalendar=*-*-* 01:40:00` (+5m) | `rclone:gdrive_capsule:twenty` | `restic-prune.timer` `03:30` quotidien | `just --justfile hosts/poppy/justfile restore-stack app=twenty` |

## Notes
- Dépendance S3/Garage : `memos`, `moodboard`, `twenty` => restore **garage-first** recommandé.
- `vikunja` peut être restauré sans Garage.
- Smoke test complet (canary) :
  - `just --justfile hosts/poppy/justfile smoke-all`
