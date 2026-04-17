# epic-poppy-restic-single-mode-stabilization

## Objectif

Stabiliser définitivement les backups de `poppy` en **mode restic unique** pour `memos`, `moodboard`, `vikunja` et `twenty`, sans dossiers doublons `*-bak` sur Google Drive.

## Résultat attendu

- 1 seul schéma de backup: restic
- 1 dossier Drive par app: `memos`, `moodboard`, `vikunja`, `twenty`
- plus de coexistence ambiguë `app` vs `app-bak`
- tests complets backup + restore validés sur:
  1. Twenty (cobaye)
  2. Vikunja

## Contexte actuel

- Les snapshots restic existent mais dans des repos `*-bak`.
- Les timers legacy et restic coexistent partiellement.
- `vikunja-backup.timer` est cassé (`unit not found`), ce qui confirme une config non stabilisée.

## Scope

1. Unifier les paths restic vers `gdrive_capsule:<app>`.
2. Mettre en place des services/timers restic clairs pour les 4 apps.
3. Désactiver les pipelines legacy concurrents.
4. Valider la restaurabilité réelle (Twenty puis Vikunja).
5. Mettre à jour runbook + checks d’exploitation.

## Non-scope

- Refonte PBS datastore (`/backup-disk`) et son sync Proxmox.
- Changement d’infra S3/Garage hors besoins stricts backup/restore.

## Critères d'acceptation

- [ ] `restic snapshots --repo rclone:gdrive_capsule:memos` fonctionne et est alimenté automatiquement.
- [ ] idem pour `moodboard`, `vikunja`, `twenty`.
- [ ] aucun timer/service legacy actif pour ces 4 backups applicatifs.
- [ ] test de restore Twenty validé de bout en bout (preuve journalisée).
- [ ] test de restore Vikunja validé de bout en bout (preuve journalisée).
- [ ] documentation d’exploitation à jour et exécutable.
