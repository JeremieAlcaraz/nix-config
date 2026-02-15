# Plan de tâches - Bootstrap poppy depuis magnolia (avec SOPS)

## Objectif

Permettre un déploiement reproductible de la config `poppy` depuis `magnolia` via SSH, avec secrets gérés dans `secrets/poppy.yaml` (SOPS), sans exposition en clair dans les logs ni dans git.

## Contraintes de sécurité

- Aucune valeur secrète ne doit être affichée dans le terminal.
- Aucun secret en clair ne doit être écrit dans le repo.
- Les fichiers temporaires déchiffrés doivent être créés avec `umask 077`, puis supprimés en fin de run.
- Les commandes de debug doivent rester en mode non-verbose.

## Suivi

- **Phase active:** `B5`
- **Dernière tâche terminée:** `B14`
- **Prochaine tâche:** `-`
- **Date maj:** `2026-02-15`

---

## B0 - Design et périmètre

- [x] **B01** Définir le format de `secrets/poppy.yaml` (clé par clé)
      **depends_on:** `-`
      **test:** `test -f secrets/poppy.yaml.example`
      **commit:** `docs(secrets): define poppy secret schema`

- [x] **B02** Ajouter la règle `.sops.yaml` pour `secrets/poppy.yaml`
      **depends_on:** `B01`
      **test:** `rg -n "secrets/poppy\\.yaml" .sops.yaml`
      **commit:** `chore(sops): add poppy encryption rule`

---

## B1 - Fichiers secrets (repo)

- [x] **B03** Créer `secrets/poppy.yaml.example` (placeholders uniquement)
      **depends_on:** `B01`
      **test:** `rg -n "<REDACTED>|<FILL_ME>" secrets/poppy.yaml.example`
      **commit:** `feat(secrets): add poppy example secrets file`

- [x] **B04** Créer `secrets/poppy.yaml` chiffré via SOPS
      **depends_on:** `B02,B03`
      **test:** `test -f secrets/poppy.yaml && rg -n "sops:" secrets/poppy.yaml`
      **commit:** `feat(secrets): add encrypted poppy secrets`
      **note:** la création se fait sans imprimer les valeurs; édition interactive `sops` seulement.

---

## B2 - Bootstrap automatisé (magnolia -> poppy)

- [x] **B05** Ajouter `hosts/poppy/bootstrap/apply-remote.sh` (idempotent, côté poppy)
      **depends_on:** `B01`
      **test:** `test -x hosts/poppy/bootstrap/apply-remote.sh`
      **commit:** `feat(poppy): add remote apply script`

- [x] **B06** Ajouter `scripts/poppy/apply-from-magnolia.sh` (orchestrateur côté magnolia)
      **depends_on:** `B04,B05`
      **test:** `test -x scripts/poppy/apply-from-magnolia.sh`
      **commit:** `feat(poppy): add magnolia push apply script`
      **note:** decrypte SOPS en fichier temporaire sécurisé, envoie vers poppy, cleanup garanti.

- [x] **B07** Ajouter cibles `just`: `poppy-apply`, `poppy-check`, `poppy-dry-run`
      **depends_on:** `B06`
      **test:** `just -l | rg -n "poppy-apply|poppy-check|poppy-dry-run"`
      **commit:** `chore(tooling): add poppy bootstrap recipes`

---

## B3 - Implémentation des secrets sans exposition

- [x] **B08** Récupérer les valeurs depuis `poppy` sans affichage stdout (capture directe vers variables/fichier temp)
      **depends_on:** `B04,B06`
      **test:** run contrôlé sans fuite dans sortie terminal
      **commit:** `-`
      **note:** interdiction de `cat rclone.conf` brut; extraction ciblée/masquée uniquement.

- [x] **B09** Injecter les valeurs dans `secrets/poppy.yaml` via `sops` (édition locale chiffrée)
      **depends_on:** `B08`
      **test:** `sops -d secrets/poppy.yaml | yq e '.rclone.gdrive_capsule.root_folder_id' -`
      **commit:** `chore(secrets): populate poppy encrypted secrets`
      **note:** la validation affiche uniquement des champs non sensibles.

---

## B4 - Validation de bout en bout

- [x] **B10** Exécuter `just poppy-dry-run` (aucune écriture distante)
      **depends_on:** `B07,B09`
      **test:** dry-run success + checks de structure
      **commit:** `-`

- [x] **B11** Exécuter `just poppy-apply` depuis magnolia
      **depends_on:** `B10`
      **test:** script apply terminé sans erreur
      **commit:** `-`

- [x] **B12** Exécuter `just poppy-check` (remote: rclone/cron/script/target folder)
      **depends_on:** `B11`
      **test:** checks OK + test marker optionnel
      **commit:** `-`

---

## B5 - Documentation et rollback

- [x] **B13** Documenter le workflow dans `hosts/poppy/runbook.md` (bootstrap + rotation secrets + rollback)
      **depends_on:** `B11,B12`
      **test:** `rg -n "bootstrap|magnolia|sops|rollback" hosts/poppy/runbook.md`
      **commit:** `docs(poppy): document bootstrap workflow`

- [x] **B14** Ajouter une procédure de rollback rapide (restauration conf précédente + cron)
      **depends_on:** `B13`
      **test:** procédure testée manuellement
      **commit:** `docs(poppy): add rollback procedure for bootstrap`

---

## Checklist de recette

- [x] `secrets/poppy.yaml` existe et est chiffré SOPS.
- [x] Aucun secret en clair dans git diff ni logs.
- [x] `just poppy-apply` pousse et applique la config sur `poppy`.
- [x] `root_folder_id` attendu est présent côté poppy.
- [x] Script sync + cron sont en place après apply.
- [x] Vérification read-only réussie.
- [x] Runbook bootstrap et rollback à jour.

---

## Données prévues dans `secrets/poppy.yaml`

- `poppy.ssh_host` (ex: `root@poppy`)
- `rclone.gdrive.client_id`
- `rclone.gdrive.client_secret`
- `rclone.gdrive.token_json`
- `rclone.gdrive_capsule.token_json`
- `rclone.gdrive_capsule.root_folder_id`
- `sync.destination_subpath` (ex: `proxmox`)
- `sync.schedule_cron` (ex: `0 4 * * *`)

## Note importante

La récupération initiale des secrets depuis `poppy` sera faite en mode non-verbeux et sans affichage des valeurs. Je peux le faire de façon sûre, mais la prudence opérationnelle impose de valider chaque étape sensible avant exécution.
