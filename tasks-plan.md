# Plan de tâches — Externaliser `modules/dotfiles` vers `/Users/jeremiealcaraz/c/` avec Home Manager

## Objectif

Sortir les fichiers de configuration de ce repo Nix en déplaçant `modules/dotfiles/` vers un dossier externe sous `/Users/jeremiealcaraz/c/`, tout en gardant Home Manager comme orchestrateur unique des liens, permissions et activations.

## Hypothèses

- Dossier cible retenu: `/Users/jeremiealcaraz/c/dotfiles`.
- Le repo Nix reste la source de vérité pour la logique (modules/options), pas pour le contenu des dotfiles.
- Migration effectuée en étapes réversibles, sans casser `homeConfigurations.jeremiealcaraz` ni `homeConfigurations.jeremiealcaraz-dev`.

## Suivi

- **Phase active:** `P2`
- **Dernière tâche terminée:** `T03`
- **Prochaine tâche:** `T04`
- **Date maj:** `2026-02-25`

---

## P1 — Cadrage et filet de sécurité

- [x] T01 Cartographier toutes les références à `modules/dotfiles`
  Depends on: -
  Changes: `tasks-plan.md`, notes d’inventaire (commande + résultats)
  Benefits: évite les oublis pendant la migration
  Tests: `rg -n "modules/dotfiles|\.\./dotfiles|jeremie\.dotfiles" flake.nix home modules docs scripts`
  Commit: `chore(plan): inventory dotfiles references before externalization`

- [x] T02 Définir le contrat cible des chemins dotfiles
  Depends on: T01
  Changes: `modules/home-manager/dev-mode.nix`, éventuel fichier d’options dédié
  Benefits: un seul point de configuration pour prod/dev/externe
  Tests: `nix eval .#homeConfigurations.jeremiealcaraz.options.jeremie.dotfiles.devPath.default` et `nix eval .#homeConfigurations.jeremiealcaraz.options.jeremie.dotfiles.repoPath.default`
  Commit: `feat(home-manager): define external dotfiles path contract`

---

## P2 — Préparer Home Manager pour un root externe

- [x] T03 Ajouter une option explicite de root externe dotfiles
  Depends on: T02
  Changes: `modules/home-manager/dev-mode.nix`
  Benefits: bascule claire vers `/Users/jeremiealcaraz/c/dotfiles` sans hardcode dispersé
  Tests: `nix eval .#homeConfigurations.jeremiealcaraz.options.jeremie.dotfiles` (vérification présence nouvelles options)
  Commit: `feat(home-manager): add external dotfiles root option`

- [ ] T04 Faire converger `source`, `path`, `mkScript` vers ce contrat unique
  Depends on: T03
  Changes: `modules/home-manager/dev-mode.nix`
  Benefits: Home Manager reste l’orchestrateur unique (symlinks + exec bits)
  Tests: `nix build .#homeConfigurations.jeremiealcaraz.activationPackage` et `nix build .#homeConfigurations.jeremiealcaraz-dev.activationPackage`
  Commit: `refactor(home-manager): unify dotfiles path resolution`

- [ ] T05 Supprimer les références directes restantes au chemin in-repo
  Depends on: T04
  Changes: `home/*.nix`, `modules/home-manager/*.nix`, scripts impactés
  Benefits: plus de dépendance implicite à `modules/dotfiles` dans le repo Nix
  Tests: `rg -n "modules/dotfiles|\.\./dotfiles" home modules scripts`
  Commit: `refactor(home-manager): remove in-repo dotfiles path references`

---

## P3 — Migration physique des fichiers

- [ ] T06 Copier le contenu vers `/Users/jeremiealcaraz/c/dotfiles` avec structure identique
  Depends on: T05
  Changes: dossier externe `/Users/jeremiealcaraz/c/dotfiles`
  Benefits: séparation nette contenu config vs infra Nix
  Tests: `rsync -aHvn --delete modules/dotfiles/ /Users/jeremiealcaraz/c/dotfiles/` puis `rsync -aHv --delete modules/dotfiles/ /Users/jeremiealcaraz/c/dotfiles/`
  Commit: `chore(dotfiles): bootstrap external dotfiles tree`

- [ ] T07 Initialiser le repo Git externe des dotfiles
  Depends on: T06
  Changes: `/Users/jeremiealcaraz/c/dotfiles/.git`, `.gitignore` (si nécessaire)
  Benefits: cycle de vie/historique indépendant pour les configs
  Tests: `git -C /Users/jeremiealcaraz/c/dotfiles status` puis `git -C /Users/jeremiealcaraz/c/dotfiles log --oneline -n 1`
  Commit: `chore(dotfiles): initialize standalone git repository`

- [ ] T08 Basculer Home Manager pour lire le dossier externe
  Depends on: T07
  Changes: `flake.nix` (module override éventuel), `home/marigold.nix` (si nécessaire)
  Benefits: activation réelle depuis le nouveau root externe
  Tests: `home-manager switch --flake .#jeremiealcaraz-dev --impure` puis `home-manager switch --flake .#jeremiealcaraz --impure`
  Commit: `feat(home-manager): switch dotfiles source to external root`

---

## P4 — Nettoyage repo et documentation

- [ ] T09 Retirer `modules/dotfiles` du repo Nix (ou le réduire à stub transitoire)
  Depends on: T08
  Changes: `modules/dotfiles/` (suppression ou README stub), `.gitignore` si nécessaire
  Benefits: le repo n’héberge plus les configs utilisateurs
  Tests: `rg -n "modules/dotfiles" flake.nix home modules docs scripts` (seulement mentions documentées)
  Commit: `chore(repo): remove in-repo dotfiles directory`

- [ ] T10 Mettre à jour la documentation (FR) et les commandes opératoires
  Depends on: T09
  Changes: `docs/README.md`, `docs/MARIGOLD-PACKAGES.md`, `docs/golden-path-home-manager.md`, autres docs concernées
  Benefits: onboarding cohérent avec la nouvelle architecture
  Tests: `rg -n "modules/dotfiles|/Users/jeremiealcaraz/c/dotfiles|Home Manager" docs`
  Commit: `docs(home-manager): document external dotfiles workflow`

- [ ] T11 Ajouter un check de non-régression pour éviter le retour de chemins legacy
  Depends on: T10
  Changes: `justfile` ou script dédié dans `scripts/`
  Benefits: garde-fou CI/local contre la réintroduction de `modules/dotfiles`
  Tests: `just <commande-check>` ou `bash scripts/<check>.sh`
  Commit: `chore(ci): add guardrail against legacy dotfiles paths`

---

## Validation finale (recette)

- [ ] `nix build .#homeConfigurations.jeremiealcaraz.activationPackage`
- [ ] `nix build .#homeConfigurations.jeremiealcaraz-dev.activationPackage`
- [ ] `home-manager switch --flake .#jeremiealcaraz-dev --impure` sans erreur
- [ ] Les liens actifs (`~/.config/...`) pointent vers `/Users/jeremiealcaraz/c/dotfiles/...`
- [ ] `rg -n "modules/dotfiles"` ne retourne plus de dépendance runtime

## Rollback (rapide)

- [ ] Revenir temporairement à l’ancien root dotfiles via option HM (`jeremie.dotfiles.*`)
- [ ] `home-manager switch --flake .#jeremiealcaraz --impure`
- [ ] Restaurer `modules/dotfiles/` depuis Git si nécessaire
