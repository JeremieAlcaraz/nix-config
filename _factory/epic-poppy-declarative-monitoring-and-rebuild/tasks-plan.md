# Tasks Plan — [EPIC] Rendre poppy déclarative pour monitoring, inventaire et réinstallation PBS

## Objectif
Mettre `poppy` au même niveau de déclarativité opérationnelle que les autres hosts pour le monitoring, l'inventaire applicatif et la capacité de réinstallation/recovery, tout en restant sur un modèle non-NixOS.

## Phases
- P1: Audit et baseline technique de `poppy`
- P2: Intégration monitoring (scrape + exporter + dashboards)
- P3: Capture déclarative de `/apps` et des scripts backup
- P4: Documentation de réinstallation PBS et runbook de validation

## Détail des tâches
- [x] T01 Auditer l'état réel de poppy (exporter, endpoint metrics, versions système/PBS, structure `/apps`)
  Depends on: -
  Changes: `hosts/poppy/README.md`, `hosts/poppy/inventory.yaml`, notes d'audit
  Benefits: Point de départ fiable avant changements.
  Tests: `ssh poppy 'uname -r && pveversion && systemctl status node-exporter || true'`
  Commit: docs(poppy): capture current audit baseline
  Status: Terminé — audit SSH réalisé, `node-exporter` absent, endpoint 9100 KO, apps détectées sous `/root/apps` (`memos`, `moodboard`, `vikunja`).

- [x] T02 Ajouter poppy aux hosts monitorés dans la config déclarative
  Depends on: T01
  Changes: `config.nix`
  Benefits: Génération automatique de la target scrape dans `myosotis`.
  Tests: `rg -n "monitoredHosts" config.nix` + rebuild `myosotis` sans erreur
  Commit: feat(monitoring): add poppy to monitored hosts
  Status: Terminé — `poppy` ajouté à `tailscale.monitoredHosts` dans `config.nix`.

- [x] T03 Déployer/valider node_exporter sur poppy (flux Debian non-NixOS)
  Depends on: T02
  Changes: `scripts/deploy-proxmox.nix` (si nécessaire), `hosts/poppy/runbook.md`
  Benefits: Exposition des métriques système standards (CPU/RAM/disk).
  Tests: `curl -fsS http://poppy:9100/metrics | head` + `systemctl is-active node-exporter`
  Commit: chore(monitoring): ensure node-exporter on poppy
  Status: Terminé — paquet `prometheus-node-exporter` installé sur poppy, service actif, endpoint `:9100/metrics` OK, target VictoriaMetrics en `health: up`.

- [ ] T04 Valider l'affichage Grafana/VictoriaMetrics pour poppy
  Depends on: T03
  Changes: `hosts/myosotis/configuration.nix` (uniquement si ajustement requis), docs de validation
  Benefits: Visibilité opérationnelle complète de `poppy`.
  Tests: requêtes `up{host="poppy"}` / panels Node Exporter Full
  Commit: test(grafana): validate poppy host metrics visibility

- [ ] T05 Capturer l'inventaire déclaratif du dossier `/apps` de poppy
  Depends on: T01
  Changes: `hosts/poppy/apps/README.md`, `hosts/poppy/inventory.yaml`
  Benefits: Vision claire des apps non-NixOS à restaurer.
  Tests: `ssh poppy 'find /apps -maxdepth 3 -type f | wc -l'` + cohérence inventaire
  Commit: docs(poppy): add declarative apps inventory

- [ ] T06 Versionner et documenter les scripts backup de poppy
  Depends on: T01
  Changes: `hosts/poppy/scripts/`, `hosts/poppy/runbook.md`, `secrets/poppy.yaml.example` (si nouveaux champs)
  Benefits: Backup/recovery reproductibles et auditables.
  Tests: lint shell + exécution dry-run + `just poppy-check`
  Commit: feat(poppy): declare backup scripts and backup workflow

- [ ] T07 Enrichir README host avec rôle, kernel/distro, PBS et procédure de réinstallation rapide
  Depends on: T05,T06
  Changes: `hosts/poppy/README.md`, `hosts/poppy/INDEX.md`
  Benefits: Onboarding et réinstallation rapide sans connaissance implicite.
  Tests: relecture “cold-start” + checklist complète
  Commit: docs(poppy): add rebuild-ready host README

- [ ] T08 Ajouter la recette de validation finale (monitoring + backup + reinstall)
  Depends on: T04,T07
  Changes: `hosts/poppy/runbook.md`, `docs/` (si besoin)
  Benefits: Definition of Done testable et stable dans le temps.
  Tests: `just poppy-check` + requêtes metrics + checklist runbook
  Commit: docs(poppy): add end-to-end validation checklist
