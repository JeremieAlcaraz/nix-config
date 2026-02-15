# Plan de tâches - Poppy (PBS non-NixOS)

## Objectif

Déclarer et documenter entièrement `poppy` (Proxmox Backup Server) dans `nix-config` pour la reproductibilité opérationnelle, sans prétendre que c'est un hôte NixOS.

## Principes

- `poppy` n'est pas géré par `nixos-rebuild`.
- Le dépôt sert de source de vérité (docs, scripts, templates, runbooks, inventaire).
- Les secrets ne sont jamais committés en clair (tokens rclone, clés, mots de passe).
- Toute action applicative sur `poppy` est validée étape par étape.

## Suivi

- **Phase active:** `P4`
- **Dernière tâche terminée:** `T17`
- **Prochaine tâche:** `-`
- **Date maj:** `2026-02-15`

---

## P0 - Cadre et structure

- [x] **T01** Créer l'arborescence `hosts/poppy/` (README, scripts, rclone, cron, runbook, inventory local)
      **depends_on:** `-`
      **test:** `test -d hosts/poppy`
      **commit:** `chore(poppy): scaffold non-nixos host declaration`

- [x] **T02** Ajouter un encart explicite "non-NixOS" dans `hosts/poppy/README.md`
      **depends_on:** `T01`
      **test:** `rg -n "non-NixOS|pas un hote NixOS|nixos-rebuild" hosts/poppy/README.md`
      **commit:** `docs(poppy): clarify non-nixos scope`

- [x] **T03** Documenter la base machine (hostname, role, Tailscale IP/DNS, PBS version, ISO d'installation PBS latest utilisée)
      **depends_on:** `T02`
      **test:** `rg -n "hostname|tailscale|pbs|iso|version" hosts/poppy/README.md`
      **commit:** `docs(poppy): add host identity and base install metadata`

---

## P1 - Capture de l'etat actuel (as-is)

- [x] **T04** Exporter le script actif `/root/sync-capsule.sh` vers `hosts/poppy/scripts/sync-capsule.sh`
      **depends_on:** `T01`
      **test:** `test -f hosts/poppy/scripts/sync-capsule.sh`
      **commit:** `feat(poppy): track active gdrive sync script`

- [x] **T05** Ajouter `hosts/poppy/rclone/rclone.conf.example` (sans secrets) avec champs importants (`type`, `scope`, `team_drive`, `root_folder_id`)
      **depends_on:** `T01`
      **test:** `rg -n "root_folder_id|gdrive_capsule|token = <REDACTED>" hosts/poppy/rclone/rclone.conf.example`
      **commit:** `feat(poppy): add sanitized rclone config template`

- [x] **T06** Déclarer le scheduling actuel (`cron` 04:00) dans `hosts/poppy/cron/root.crontab.example`
      **depends_on:** `T04`
      **test:** `rg -n "sync-capsule.sh|0 4 \\* \\* \\*" hosts/poppy/cron/root.crontab.example`
      **commit:** `docs(poppy): capture cron schedule for drive sync`

- [x] **T07** Décrire le flux fonctionnel complet "PBS datastore -> rclone -> dossier Drive cible" dans `hosts/poppy/README.md`
      **depends_on:** `T03,T04,T05,T06`
      **test:** `rg -n "backup-disk|gdrive_capsule|root_folder_id|proxmox" hosts/poppy/README.md`
      **commit:** `docs(poppy): explain backup sync data flow`

---

## P2 - Reproductibilite operationnelle

- [x] **T08** Ajouter `hosts/poppy/runbook.md` (checks quotidiens, verification cible Drive, verification job, incidents courants)
      **depends_on:** `T07`
      **test:** `rg -n "verification|incident|rollback|rclone|cron" hosts/poppy/runbook.md`
      **commit:** `docs(poppy): add operations runbook`

- [x] **T09** Ajouter `hosts/poppy/scripts/verify-drive-target.sh` (script de verification read-only, sans sync destructive)
      **depends_on:** `T05,T08`
      **test:** `test -x hosts/poppy/scripts/verify-drive-target.sh`
      **commit:** `feat(poppy): add non-destructive drive target verification script`

- [x] **T10** Ajouter `hosts/poppy/scripts/test-drive-write.sh` (fichier marqueur horodate vers `gdrive_capsule:proxmox/`)
      **depends_on:** `T05,T08`
      **test:** `test -x hosts/poppy/scripts/test-drive-write.sh`
      **commit:** `feat(poppy): add minimal drive write test script`

- [x] **T11** Documenter la politique secrets (ou placer placeholders SOPS si tu veux centraliser les meta-infos)
      **depends_on:** `T05`
      **test:** `rg -n "secrets|sops|token|jamais committer" hosts/poppy/README.md hosts/poppy/runbook.md`
      **commit:** `docs(poppy): define secret handling policy`

---

## P3 - Integration au repo global nix-config

- [x] **T12** Referencer `poppy` dans l'inventaire global (README racine + index docs/hosts)
      **depends_on:** `T03,T07`
      **test:** `rg -n "poppy" README.md docs hosts | head`
      **commit:** `docs(inventory): add poppy to global architecture map`

- [x] **T13** Ajouter un index `hosts/poppy/INDEX.md` pointant vers README, runbook, scripts, templates
      **depends_on:** `T08,T09,T10`
      **test:** `test -f hosts/poppy/INDEX.md`
      **commit:** `docs(poppy): add local index for fast navigation`

- [x] **T14** (Optionnel) Ajouter une couche Nix "outillage cohérence" non-NixOS (ex: `just`/script wrappers) sans deployment system
      **depends_on:** `T09,T10`
      **test:** `just -l | rg -n "poppy|drive|backup" || true`
      **commit:** `chore(tooling): add non-nixos wrappers for poppy operations`
      **note:** Pas de `nixosConfiguration.poppy`; uniquement des commandes/outils.

---

## P4 - Validation finale

- [x] **T15** Validation documentaire croisee (un nouveau device peut comprendre/operer `poppy` sans contexte oral)
      **depends_on:** `T12,T13`
      **test:** revue manuelle + checklist runbook completee
      **commit:** `-`

- [x] **T16** Validation technique minimale sur `poppy` (test marker + verification cible + logs)
      **depends_on:** `T10,T15`
      **test:** execution guidee des scripts `verify-drive-target.sh` puis `test-drive-write.sh`
      **commit:** `-`

- [x] **T17** Geler la v1 du dossier `hosts/poppy` et ouvrir phase v2 (hardening/systemd timers/migration cron)
      **depends_on:** `T16`
      **test:** ticket v2 cree + backlog priorise
      **commit:** `docs(poppy): mark v1 baseline and v2 backlog`

---

## Checklist de recette (definition of done)

- [x] `hosts/poppy/README.md` explique clairement que `poppy` est hors NixOS.
- [x] Le script de sync est versionne et documente (`sync-capsule.sh`).
- [x] La conf rclone templatee est versionnee et sanitisee.
- [x] Le `root_folder_id` cible est documente et verifiable.
- [x] Le scheduling (cron actuel) est explicite et reproductible.
- [x] Un runbook d'exploitation/recovery existe.
- [x] Le host est visible dans l'inventaire global du repo.
- [x] Les secrets ne sont presents nulle part en clair dans git.

---

## Ordre recommande d'execution

1. `P0` (cadre)
2. `P1` (capture as-is)
3. `P2` (scripts de verification + runbook)
4. `P3` (integration globale)
5. `P4` (validation)

## Blocages connus potentiels

- Acces SSH/Tailscale a `poppy` indisponible.
- Token OAuth rclone expire (necessite re-auth avant certains tests ecriture).
- Divergence entre etat serveur et etat de la doc si capture tardive.
