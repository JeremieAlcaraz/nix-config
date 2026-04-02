# Tasks Plan — [EPIC] Redéfinir le scope Home Manager après extraction des dotfiles

## Objectif
Définir un scope Home Manager clair et durable après migration progressive des symlinks dotfiles vers Dotbot, avec une transition sûre et vérifiable inter-repos.

## Phases
- P1: Cartographie de l'existant HM
- P2: Décision d'architecture SoC cible
- P3: Décommission progressive des symlinks dotfiles HM
- P4: Nettoyage, garde-fous et documentation

## Détail des tâches
- [ ] T01 Inventorier les responsabilités HM actuelles (dotfiles, packages, hooks, services)
  Depends on: -
  Changes: `docs/hm-scope-inventory.md`
  Benefits: Vision exhaustive pour décider quoi garder/sortir.
  Tests: Vérification croisée `rg xdg.configFile/home.file` + sections home/*.nix.
  Commit: docs(hm): add current scope inventory

- [ ] T02 Formaliser la cible SoC Home Manager (ADR)
  Depends on: T01
  Changes: `docs/adr/ADR-hm-scope-after-dotbot.md`
  Benefits: Règles explicites pour éviter les retours en arrière.
  Tests: Validation manuelle des règles avec besoins utilisateur.
  Commit: docs(adr): define target home-manager scope

- [ ] T03 Préparer les changements HM minimaux pour coexistence avec Dotbot
  Depends on: T02
  Changes: modules/home-manager + home/*.nix (dépréciation progressive)
  Benefits: Transition safe sans rupture durant migration par lots.
  Tests: `home-manager switch` réussi + smoke tests shell/editor.
  Commit: refactor(hm): prepare gradual dotfiles extraction

- [ ] T04 Retirer les entrées HM du lot safe après validation Dotbot
  Depends on: T03
  Changes: suppressions ciblées `xdg.configFile` lot safe
  Benefits: Réduction immédiate de couplage HM↔dotfiles.
  Tests: symlinks directs post-switch + comportement CLI inchangé.
  Commit: refactor(hm): remove safe batch dotfile links
  Status: En cours — suppressions HM faites pour `gh`, `ripgrep`, `starship`; reste à aligner `bat` et `fd`.

- [ ] T05 Retirer les entrées HM des lots terminal puis sensible
  Depends on: T04
  Changes: suppressions `wezterm/tmux/yazi` puis `nvim/zsh/emacs/hammerspoon`
  Benefits: HM recentré sur son cœur utile.
  Tests: `home-manager switch` + smoke complet apps critiques.
  Commit: refactor(hm): remove remaining dotfile links

- [ ] T06 Ajouter garde-fous anti-réintroduction et doc d'exploitation
  Depends on: T05
  Changes: `scripts/check-hm-scope.sh`, `README.md`, docs
  Benefits: Maintenabilité long terme et règles automatisées.
  Tests: script échoue si nouveau `xdg.configFile` hors scope autorisé.
  Commit: chore(hm): enforce scope guardrails and docs
