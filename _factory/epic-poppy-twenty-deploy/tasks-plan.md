# Tasks Plan — [EPIC] Déployer Twenty CRM sur Poppy (podman + declarative)

## Objectif

Déployer Twenty CRM sur Poppy avec podman-compose, storage Garage S3, secrets dans SOPS, backup timer, et service Tailscale. Extraction-only depuis Desktop (pas de copie du projet complet).

---

## Phases

- Phase 1 — Extraction + Préparation
- Phase 2 — SOPS + Garage S3
- Phase 3 — Deployment (compose + env + systemd)
- Phase 4 — Tailscale + Validation

---

## Détail des tâches

- [ ] T01 Créer bucket `twenty` + key `twenty-app` dans Garage S3
  Depends on: -
  Changes: `hosts/poppy/scripts/garage-bootstrap.sh` (ajout bucket/key twenty)
  Benefits: Storage S3 prêt pour twenty
  Tests: `ssh poppy garage bucket info twenty` + `ssh poppy garage key info twenty-app`
  Commit: `feat(poppy): add Garage bucket+key for twenty`

- [ ] T02 Extraire compose + .env depuis Desktop vers nix-config
  Depends on: -
  Changes: `hosts/poppy/apps/twenty/docker-compose.yml`, `hosts/poppy/apps/twenty/.env.template`
  Benefits: Fichiers nécessaires au déploiement dans le repo
  Tests: Fichiers présent + contient les vars twenty
  Commit: `feat(poppy): extract twenty compose+env from Desktop`

- [ ] T03 Adapter compose pour podman (runtime, extra_hosts, ports, S3)
  Depends on: T02
  Changes: `hosts/poppy/apps/twenty/compose.yml`
  Benefits: Compatible podman-compose, accède à garage via host.containers.internal:3900
  Tests: `podman-compose -f compose.yml config` OK
  Commit: `refactor(poppy): adapt twenty compose for podman + S3`

- [ ] T04 Ajouter secrets twenty dans SOPS
  Depends on: T02
  Changes: `secrets/poppy.yaml` (apps.twenty.*)
  Benefits: Tous les secrets dans SOPS, pas de secrets en clair
  Tests: `sops Decrypt secrets/poppy.yaml | yq '.apps.twenty'`
  Commit: `chore(poppy): add twenty secrets to SOPS`

- [ ] T05 Créer systemd unit `twenty.service` (podman-compose, After=garage.service)
  Depends on: T03
  Changes: `hosts/poppy/systemd/twenty.service`
  Benefits: twenty démarre automatiquement, dépend de garage
  Tests: `systemctl is-enabled twenty.service` après deploy
  Commit: `feat(poppy): add twenty systemd unit`

- [ ] T06 Intégrer twenty à `poppy-apply` (templates + scp + apply-remote + lock)
  Depends on: T03, T04, T05
  Changes: `scripts/poppy/apply-from-magnolia.sh`, `hosts/poppy/bootstrap/apply-remote.sh`
  Benefits: `just poppy-apply` déploie twenty comme les autres apps
  Tests: dry-run montre twenty dans les fichiers
  Commit: `feat(poppy): integrate twenty into poppy-apply`

- [ ] T07 Créer backup script + timer pour twenty (dump SQL + sync S3 → Drive)
  Depends on: T01, T05
  Changes: `hosts/poppy/scripts/twenty-backup.sh`, `hosts/poppy/systemd/twenty-backup.timer`, `hosts/poppy/systemd/twenty-backup.service`
  Benefits: Sauvegarde quotidienne SQL + sync S3 vers Drive
  Tests: `bash twenty-backup.sh` OK + timer enabled
  Commit: `feat(poppy): add twenty backup timer (daily 07:00)`

- [ ] T08 Configurer service Tailscale twenty
  Depends on: T05
  Changes: via `tailscale-service-golden-path` skill → scripts tailscale + ACL
  Benefits: twenty accessible via https://twenty.inanga-sirius.ts.net
  Tests: `curl -I https://twenty.inanga-sirius.ts.net` retourne 200
  Commit: `feat(poppy): add Tailscale svc:twenty for HTTPS`

- [ ] T09 Corriger OAuth callback URLs pour prod (SERVER_URL=https://twenty.inanga-sirius.ts.net)
  Depends on: T08
  Changes: `hosts/poppy/apps/twenty/.env.template` (callback URLs)
  Benefits: OAuth Google fonctionnel en prod
  Tests: Login Google via twenty.inanga-sirius.ts.net
  Commit: `fix(twenty): update OAuth callback URLs for prod domain`

- [ ] T10 Ajouter drift detection pour twenty dans `poppy-check.sh`
  Depends on: T06
  Changes: `scripts/poppy/check.sh`
  Benefits: Détection de drift sur tous les fichiers twenty
  Tests: `just poppy-check` montre twenty dans les checks
  Commit: `feat(poppy): add twenty drift detection to poppy-check`

---

## Résumé

| Phase | Tâches |
|---|---|
| Extraction + Préparation | T01, T02, T03 |
| SOPS + Garage S3 | T01 (bucket/key), T04 (secrets) |
| Deployment | T05 (systemd), T06 (apply), T10 (drift) |
| Backup | T07 (script + timer) |
| Tailscale | T08, T09 |