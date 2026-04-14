# Lot issues

| key | task_ref | type | title | labels | assignee | parent_key | issue_id | url | state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EPIC-RESTIC-001 | - | epic | [EPIC] Refondre les backups Poppy avec restic + rclone | type/epic,prio/high | jeremiealcaraz | | 82 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/82 | open |
| STORY-RESTIC-001 | T01 | story | [STORY] Infrastructure restic (install + init repos) | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC-001 | 88 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/88 | open |
| TASK-RESTIC-001 | T01 | task | [T01] Installer restic + initialiser 4 repositories | type/task,prio/high | jeremiealcaraz | STORY-RESTIC-001 | 83 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/83 | open |
| STORY-RESTIC-002 | T02-T03 | story | [STORY] Migration scripts backup vers restic | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC-001 | 89 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/89 | open |
| TASK-RESTIC-002 | T02 | task | [T02] Migrer scripts backup → restic backup | type/task,prio/high | jeremiealcaraz | STORY-RESTIC-002 | 84 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/84 | open |
| TASK-RESTIC-003 | T03 | task | [T03] Prune automatique (restic forget --keep-daily 7) | type/task,prio/medium | jeremiealcaraz | STORY-RESTIC-002 | 85 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/85 | open |
| STORY-RESTIC-003 | T04-T05 | story | [STORY] Restore interactif via justfile + tests | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC-001 | 90 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/90 | open |
| TASK-RESTIC-004 | T04 | task | [T04] just restore interactif (gum picker) | type/task,prio/high | jeremiealcaraz | STORY-RESTIC-003 | 86 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/86 | open |
| TASK-RESTIC-005 | T05 | task | [T05] Tests de restore + documentation | type/task,prio/medium | jeremiealcaraz | STORY-RESTIC-003 | 87 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/87 | open |
