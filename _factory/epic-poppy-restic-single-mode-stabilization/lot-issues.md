# Lot issues

| key | task_ref | type | title | labels | assignee | parent_key | issue_id | url | state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EPIC-RESTIC2-001 | - | epic | [EPIC] Stabiliser backups Poppy en mode restic unique + validation restore Twenty/Vikunja | type/epic,prio/high | jeremiealcaraz |  | 94 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/94 | open |
| STORY-RESTIC2-001 | T01 | story | [STORY] Unifier les destinations Drive et migration restic sans .bak | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC2-001 | 95 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/95 | open |
| TASK-RESTIC2-001 | T01 | task | [TASK] Cartographier l’état actuel backups/timers/scripts et définir plan de migration | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-001 | 96 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/96 | open |
| TASK-RESTIC2-002 | T02 | task | [TASK] Reconfigurer restic pour écrire dans gdrive_capsule:<app> (sans -bak) | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-001 | 97 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/97 | open |
| TASK-RESTIC2-003 | T03 | task | [TASK] Migrer ou re-initialiser les repos et valider la lisibilité snapshots | type/task,prio/medium | jeremiealcaraz | STORY-RESTIC2-001 | 98 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/98 | open |
| STORY-RESTIC2-002 | T04 | story | [STORY] Activer l’automatisation restic unique et retirer le legacy | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC2-001 | 99 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/99 | open |
| TASK-RESTIC2-004 | T04 | task | [TASK] Créer/activer les services+timers restic par app | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-002 | 100 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/100 | open |
| TASK-RESTIC2-005 | T05 | task | [TASK] Désactiver les timers/services legacy et nettoyer les chemins ambigus | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-002 | 101 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/101 | open |
| TASK-RESTIC2-006 | T06 | task | [TASK] Ajouter checks de santé backup (status + snapshots récents) | type/task,prio/medium | jeremiealcaraz | STORY-RESTIC2-002 | 102 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/102 | open |
| STORY-RESTIC2-003 | T07 | story | [STORY] Valider restauration bout-en-bout sur Twenty puis Vikunja | type/story,prio/high | jeremiealcaraz | EPIC-RESTIC2-001 | 103 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/103 | open |
| TASK-RESTIC2-007 | T07 | task | [TASK] Exécuter test complet backup + restore sur Twenty (cobaye) | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-003 | 104 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/104 | open |
| TASK-RESTIC2-008 | T08 | task | [TASK] Exécuter test complet backup + restore sur Vikunja | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-003 | 105 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/105 | open |
| TASK-RESTIC2-010 | T10 | task | [TASK] Orchestrer les restores dépendants S3 (garage-first pour apps concernées) | type/task,prio/high | jeremiealcaraz | STORY-RESTIC2-003 | 107 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/107 | open |
| TASK-RESTIC2-009 | T09 | task | [TASK] Mettre à jour runbook/docs + procédure d’exploitation finale | type/task,prio/medium | jeremiealcaraz | STORY-RESTIC2-003 | 106 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/106 | open |
