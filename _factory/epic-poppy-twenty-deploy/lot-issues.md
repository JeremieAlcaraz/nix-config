# Lot issues

| key | task_ref | type | title | labels | assignee | parent_key | issue_id | url | state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EPIC-TW-001 | - | epic | [EPIC] Déployer Twenty CRM sur Poppy (podman + declarative) | type/epic,prio/high | jeremiealcaraz | | 66 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/66 | open |
| STORY-TW-001 | T02 | story | [STORY] Extraire compose + env + secrets twenty | type/story,prio/high | jeremiealcaraz | EPIC-TW-001 | 67 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/67 | closed |
| TASK-TW-001 | T01 | task | [TASK] Créer bucket twenty + key twenty-app dans Garage | type/task,prio/high | jeremiealcaraz | STORY-TW-001 | 71 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/71 | closed |
| TASK-TW-002 | T02 | task | [TASK] Extraire compose + .env depuis Desktop | type/task,prio/high | jeremiealcaraz | STORY-TW-001 | 72 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/72 | closed |
| TASK-TW-003 | T03 | task | [TASK] Adapter compose pour podman (ports, extra_hosts, S3) | type/task,prio/high | jeremiealcaraz | STORY-TW-001 | 73 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/73 | closed |
| TASK-TW-004 | T04 | task | [TASK] Ajouter secrets twenty dans SOPS | type/task,prio/high | jeremiealcaraz | STORY-TW-001 | 74 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/74 | closed |
| STORY-TW-002 | T06 | story | [STORY] Déployer twenty via poppy-apply (compose + env + systemd) | type/story,prio/high | jeremiealcaraz | EPIC-TW-001 | 68 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/68 | open |
| TASK-TW-005 | T05 | task | [TASK] Créer systemd unit twenty.service | type/task,prio/high | jeremiealcaraz | STORY-TW-002 | 75 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/75 | open |
| TASK-TW-006 | T06 | task | [TASK] Intégrer twenty à poppy-apply + apply-remote | type/task,prio/high | jeremiealcaraz | STORY-TW-002 | 76 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/76 | open |
| TASK-TW-007 | T10 | task | [TASK] Ajouter drift detection twenty dans poppy-check | type/task,prio/medium | jeremiealcaraz | STORY-TW-002 | 80 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/80 | open |
| STORY-TW-003 | T07 | story | [STORY] Backup twenty (dump SQL + sync S3 → Drive) | type/story,prio/medium | jeremiealcaraz | EPIC-TW-001 | 69 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/69 | open |
| TASK-TW-008 | T07 | task | [TASK] Créer backup script + timer twenty | type/task,prio/medium | jeremiealcaraz | STORY-TW-003 | 77 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/77 | open |
| STORY-TW-004 | T08 | story | [STORY] Tailscale svc:twenty (HTTPS + OAuth callback prod) | type/story,prio/high | jeremiealcaraz | EPIC-TW-001 | 70 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/70 | open |
| TASK-TW-009 | T08 | task | [TASK] Configurer service Tailscale twenty | type/task,prio/high | jeremiealcaraz | STORY-TW-004 | 78 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/78 | open |
| TASK-TW-010 | T09 | task | [TASK] Corriger OAuth callback URLs pour prod | type/task,prio/high | jeremiealcaraz | STORY-TW-004 | 79 | http://dandelion:3000/jeremiealcaraz/nix-config/issues/79 | open |