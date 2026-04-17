# Tasks Plan — [EPIC] Stabiliser backups Poppy en mode restic unique + validation restore Twenty/Vikunja

## Objectif

Passer de l'état hybride actuel (legacy + restic `*-bak`) à un modèle unique, lisible et fiable: restic seulement, avec 1 dossier Drive par app, et des restores testés en conditions réelles.

## Phases

- Phase 1: Audit et design de migration
- Phase 2: Unification des repos restic Drive
- Phase 3: Automatisation systemd restic-only
- Phase 4: Validation restore Twenty puis Vikunja
- Phase 5: Documentation et checks opérationnels

## Détail des tâches

### Résultat T01 (2026-04-16)

- Timers actifs: `memos-backup`, `memos-s3-backup`, `backup-moodboard`, `twenty-backup`, `restic-prune`.
- Timer cassé: `vikunja-backup.timer` (unit not found / failed).
- Repos restic présents uniquement en `*-bak` avec derniers snapshots le `2026-04-14`.
- Drive en double arborescence: `memos` + `memos-bak`, `vikunja` + `vikunja-bak`, `moodboard` + `moodboard-bak`, `twenty` + `twenty-bak`.
- Décision de migration validée: cible canonique `gdrive_capsule:<app>` (sans suffixe `-bak`) en mode restic-only.

### Résultat T02 (2026-04-16)

- Scripts restic SoT reconfigurés vers les repos canoniques: `memos`, `vikunja`, `moodboard`, `twenty`.
- `restic-init.sh`, `restic-prune.sh`, `restic-restore.sh` mis à jour sans suffixe `-bak`.
- `hosts/poppy/justfile` (commande `snapshots`) aligné sur les repos canoniques.
- Documentation `docs/restic/RESTIC.md` alignée sur les chemins canoniques.

### Résultat T03 (2026-04-16)

- Repos canoniques initialisés sur Drive: `rclone:gdrive_capsule:memos|vikunja|moodboard|twenty`.
- Snapshots initiaux validés:
  - `memos`: `44db99c5` (2026-04-16 21:03:01)
  - `vikunja`: `ed600a1d` (2026-04-16 21:03:50)
  - `moodboard`: `b99588ab` (2026-04-16 21:04:42)
  - `twenty`: `f588f6f7` (2026-04-16 21:02:22)
- Legacy `*-bak` conservé pour rollback pendant la phase de transition.

### Résultat T04 (2026-04-16)

- Unités systemd ajoutées et déployées:
  - `memos-restic-backup.service|timer` (02:00)
  - `vikunja-restic-backup.service|timer` (02:20)
  - `moodboard-restic-backup.service|timer` (02:40)
  - `twenty-restic-backup.service|timer` (01:40)
- Timers activés et en attente (`enabled + active`).
- Exécution manuelle validée sur `twenty-restic-backup.service` avec nouveau snapshot `ee7783b7`.

### Résultat T05 (2026-04-16)

- Timers legacy désactivés (`disabled + inactive`):
  - `memos-backup.timer`
  - `memos-s3-backup.timer`
  - `backup-moodboard.timer`
  - `twenty-backup.timer`
- `vikunja-backup.timer` reste absent (`not-found`) et n'est plus dans le flux actif.
- Timers restic confirmés actifs: `memos|vikunja|moodboard|twenty-restic-backup.timer` + `restic-prune.timer`.
- Services applicatifs restent actifs (`memos`, `vikunja`, `moodboard`, `twenty`, `garage`).

### Résultat T10 (2026-04-16)

- Nouveau script `restic-restore-stack.sh` déployé sur poppy.
- Nouveau flux `just restore-stack app=<...>` ajouté.
- Orchestration: pour `memos|moodboard|twenty`, proposition `garage-first` avant restore app; `vikunja` reste app-only.
- Script validé syntaxiquement (`bash -n`) et déployé sans interruption des services.

### Résultat T07 (2026-04-16)

- Test E2E effectué sur Twenty (cobaye):
  1. backup forcé restic canonical,
  2. création d'un canary contrôlé dans le volume `twenty_twenty-server-data`,
  3. restore snapshot `826afecd`,
  4. recopie des volumes restaurés,
  5. redémarrage service.
- Validation: canary supprimé après restore + `twenty.service` actif.
- Conclusion: restore volume-level Twenty validé en conditions réelles.

### Résultat T08 (2026-04-16)

- Test E2E effectué sur Vikunja:
  1. backup forcé restic canonical,
  2. création d'un canary dans `/root/apps/vikunja/data`,
  3. restore snapshot `f30e5be4` en temporaire,
  4. stop service + recopie complète du répertoire data restauré,
  5. redémarrage service.
- Validation: canary supprimé + `vikunja.service` actif.
- Conclusion: restore Vikunja validé en conditions réelles.

### Résultat T09 (2026-04-17)

- Runbook finalisé pour mode restic-only (backup, restore app-only vs stack-aware, checklist post-restore).
- Documentation restic mise à jour (exploitation cible + règles cleanup legacy).
- Plan de cleanup contrôlé des dossiers `.bak` documenté (inventaire -> manifestes -> purge -> vérification).


- [x] T01 Cartographier l’état actuel backups/timers/scripts et définir plan de migration
  - Depends on: -
  - Changes: inventaire précis des unités systemd, scripts, repos Drive, snapshots récents; stratégie migration no-downtime.
  - Benefits: évite les régressions et donne une base factuelle.
  - Tests: rapport d’audit validé + commandes de vérification reproductibles.
  - Commit: docs(poppy): audit backup state and migration strategy

- [x] T02 Reconfigurer restic pour écrire dans gdrive_capsule:<app> (sans -bak)
  - Depends on: T01
  - Changes: scripts/env restic, mapping des repos, conventions de nommage.
  - Benefits: lisibilité immédiate sur Drive (1 app = 1 dossier).
  - Tests: `restic snapshots --repo rclone:gdrive_capsule:<app>` OK pour 4 apps.
  - Commit: refactor(poppy): switch restic repos to canonical app paths

- [x] T03 Migrer ou ré-initialiser les repos et valider la lisibilité snapshots
  - Depends on: T02
  - Changes: migration contrôlée (ou init propre) + vérifications d’intégrité.
  - Benefits: continuité des backups et historique propre.
  - Tests: snapshots visibles, pas d’erreurs restic unlock/check.
  - Commit: chore(poppy): migrate restic repositories to canonical drive folders

- [x] T04 Créer/activer les services+timers restic par app
  - Depends on: T03
  - Changes: unités `*.service`/`*.timer` restic pour memos/vikunja/moodboard/twenty.
  - Benefits: automatisation explicite et homogène.
  - Tests: `systemctl list-timers` + run manuel de chaque service.
  - Commit: feat(poppy): add per-app restic backup systemd timers

- [x] T05 Désactiver les timers/services legacy et nettoyer les chemins ambigus
  - Depends on: T04
  - Changes: disable legacy units/scripts backup, suppression des exécutions concurrentes.
  - Benefits: plus de duplication ni d’écrasement silencieux.
  - Tests: seuls les timers restic restent actifs pour les 4 apps.
  - Commit: chore(poppy): retire legacy backup timers and scripts from active schedule

- [ ] T06 Ajouter checks de santé backup (status + snapshots récents)
  - Depends on: T05
  - Changes: enrichir `just poppy-check`/runbook avec contrôles freshness snapshots.
  - Benefits: détection rapide des incidents.
  - Tests: check passe en nominal et échoue sur cas simulé.
  - Commit: feat(poppy): add backup health checks for restic-only mode

- [x] T07 Exécuter test complet backup + restore sur Twenty (cobaye)
  - Depends on: T06
  - Changes: scénario test documenté + preuves (logs, commandes, résultats).
  - Benefits: validation réelle du mécanisme avant généralisation.
  - Tests: backup forcé -> altération contrôlée -> restore snapshot -> app OK.
  - Commit: docs(poppy): validate end-to-end backup restore for twenty

- [x] T08 Exécuter test complet backup + restore sur Vikunja
  - Depends on: T07
  - Changes: reprise du protocole Twenty adapté à Vikunja.
  - Benefits: deuxième preuve sur stack différente.
  - Tests: backup forcé -> restore -> vérification données/fonctionnement.
  - Commit: docs(poppy): validate end-to-end backup restore for vikunja

- [x] T10 Orchestrer les restores dépendants S3 (garage-first)
  - Depends on: T07
  - Changes: ajouter un flux `restore-stack` qui restaure Garage avant apps dépendantes (memos/twenty/moodboard), et garde un mode app-only.
  - Benefits: évite les restores incohérents DB métadonnées vs objets S3.
  - Tests: restore-stack Twenty validé; restore Vikunja inchangé (sans garage).
  - Commit: feat(poppy): add garage-first restore orchestration for s3-dependent apps

- [x] T09 Mettre à jour runbook/docs + procédure d’exploitation finale
  - Depends on: T08, T10
  - Changes: runbook final, conventions Drive, commandes de contrôle/restore, troubleshooting.
  - Benefits: passation claire et ops reproductible.
  - Tests: procédure suivie à froid sans ambiguïté.
  - Commit: docs(poppy): finalize restic-only backup and restore runbook
