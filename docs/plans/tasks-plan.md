# Plan de tâches — Homarr sur myosotis (léger)

## Objectif

Déployer Homarr sur `myosotis` avec l'empreinte la plus légère possible, accessible en HTTPS sur le tailnet via Tailscale.

## Contraintes

- Pas d'exposition Internet publique.
- Priorité au module NixOS natif (`services.homarr`) si disponible.
- Base locale simple (SQLite) pour minimiser la complexité.
- Déploiement incrémental avec validation à chaque étape.

## Suivi

- **Phase active:** `P1`
- **Dernière tâche terminée:** `-`
- **Prochaine tâche:** `T01`
- **Date maj:** `2026-02-14`

---

## P1 — Pré-checks

- [x] **T01** Vérifier que `services.homarr` est disponible dans le flake lock actuel
      **depends_on:** `-`
      **test:** `rg -n "homarr" /etc/nixos 2>/dev/null || true` puis `nix eval .#nixosConfigurations.myosotis.config.services.homarr.enable`
      **commit:** `-`
      **note:** `services.homarr` indisponible dans ce lock, fallback vers container OCI léger.

- [ ] **T02** Confirmer le DNS tailnet exact (pour URL finale)
      **depends_on:** `T01`
      **test:** `tailscale status --json | jq -r '.Self.DNSName'`
      **commit:** `-`

---

## P2 — Configuration Homarr minimale

- [x] **T03** Créer `hosts/myosotis/homarr.nix`
      **depends_on:** `T01`
      **test:** `test -f hosts/myosotis/homarr.nix`
      **commit:** `feat(myosotis): add homarr module`

- [x] **T04** Activer Homarr en container OCI avec écoute locale (`127.0.0.1`) et port dédié (`7575`)
      **depends_on:** `T03`
      **test:** `nix build .#nixosConfigurations.myosotis.config.system.build.toplevel`
      **commit:** `feat(myosotis): enable homarr container on localhost`

- [x] **T05** Ajouter le secret SOPS `homarr_secret_encryption_key`
      **depends_on:** `T04`
      **test:** `sops -d secrets/myosotis.yaml | rg "homarr_secret_encryption_key"`
      **commit:** `feat(secrets): add homarr encryption key for myosotis`

- [x] **T06** Brancher le secret dans la config Homarr
      **depends_on:** `T05`
      **test:** `nix build .#nixosConfigurations.myosotis.config.system.build.toplevel`
      **commit:** `feat(myosotis): wire homarr secret from sops`

---

## P3 — Exposition HTTPS via Tailscale

- [x] **T07** Ajouter un service `tailscale-serve-homarr` (systemd oneshot, pattern identique Grafana)
      **depends_on:** `T06`
      **test:** `nix build .#nixosConfigurations.myosotis.config.system.build.toplevel`
      **commit:** `feat(myosotis): add tailscale serve service for homarr`

- [x] **T08** Gérer le conflit potentiel avec Grafana déjà exposé en `--https=443`
      **depends_on:** `T07`
      **test:** `tailscale serve status`
      **commit:** `chore(myosotis): align tailscale serve routing for grafana and homarr`
      **note:** Choisir 1 stratégie:
  - host/service dédié Tailscale pour Homarr
  - ou partage via routes/ports sans casser Grafana
    **note_resultat:** implémenté avec `--service=homarr` (service Tailscale dédié).

- [ ] **T09** Définir l'URL cible Homarr sur tailnet (`homarr.<tailnet>.ts.net` si faisable)
      **depends_on:** `T08`
      **test:** `tailscale status --json | jq -r '.Self.DNSName'` + vérif de l'URL documentée
      **commit:** `docs(myosotis): document homarr tailscale endpoint`
      **note_resultat:** sur la version Tailscale actuelle de `myosotis`, `--service` n'est pas supporté. Endpoint retenu: `https://myosotis.<tailnet>.ts.net:8443`.

---

## P4 — Déploiement et validation

- [x] **T10** Déployer sur `myosotis`
      **depends_on:** `T09`
      **test:** `sudo nixos-rebuild switch --flake .#myosotis`
      **commit:** `-`

- [x] **T11** Vérifier le service Homarr (container `podman-homarr`)
      **depends_on:** `T10`
      **test:** `ssh myosotis 'systemctl status podman-homarr --no-pager'`
      **commit:** `-`

- [x] **T12** Vérifier l'exposition Tailscale Serve
      **depends_on:** `T10`
      **test:** `ssh myosotis 'tailscale serve status'`
      **commit:** `-`

- [x] **T13** Vérifier l'accès HTTPS depuis un client du tailnet
      **depends_on:** `T12`
      **test:** `curl -I https://<endpoint-homarr>`
      **commit:** `-`

- [ ] **T14** Vérifier la persistance et un redémarrage
      **depends_on:** `T11`
      **test:** `ssh myosotis 'sudo systemctl restart podman-homarr && sleep 2 && systemctl is-active podman-homarr'`
      **commit:** `-`

---

## P5 — Documentation et rollback

- [ ] **T15** Documenter l'exploitation dans `docs/RUNBOOK-ALERTES.md` (ou doc dédiée)
      **depends_on:** `T13`
      **test:** `rg -n "Homarr|homarr" docs`
      **commit:** `docs(myosotis): add homarr operations notes`

- [ ] **T16** Préparer rollback rapide
      **depends_on:** `T10`
      **test:** rollback validé par `nixos-rebuild switch --rollback`
      **commit:** `-`

---

## Tests de recette (checklist finale)

- [x] `podman-homarr` actif au boot (`systemctl is-enabled podman-homarr` = `enabled`)
- [x] `podman-homarr` actif runtime (`systemctl is-active podman-homarr` = `active`)
- [x] `tailscale serve status` montre la publication Homarr attendue
- [x] Accès HTTPS OK depuis un device tailnet
- [x] Pas de régression Grafana (`https://myosotis.<tailnet>.ts.net` toujours OK)
- [x] Rebuild NixOS sans erreur sur `myosotis`

---

## Fin de chantier

- [ ] Valider avec capture des commandes de test
- [ ] Supprimer ce fichier `tasks-plan.md` une fois le chantier terminé
