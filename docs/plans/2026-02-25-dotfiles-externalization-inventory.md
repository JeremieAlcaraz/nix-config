# Inventaire — références `modules/dotfiles`

Date: 2026-02-25
Contexte: préparation migration des dotfiles hors repo Nix vers `/Users/jeremiealcaraz/c/dotfiles`.

## 1) Références runtime Home Manager / flake

- `modules/home-manager/dev-mode.nix`
  - `dotfilesDevPathDefault = "${worktreeRootDefault}/modules/dotfiles"`
  - `repoPath.default = ../dotfiles`
  - helpers `source/path/mkScript`
- `home/marigold.nix`, `home/aerospace.nix`, `home/wezterm.nix`, `home/sketchybar.nix`
  - consommation de `config.jeremie.dotfiles.*`
- `flake.nix`
  - activation `jeremie.dotfiles.devMode = false/true` pour `homeConfigurations`

## 2) Références scripts opérationnels

- `modules/dotfiles/zsh/scripts/check-zsh-completion.sh`
- `modules/dotfiles/zsh/scripts/bench-zsh-completion.sh`

Ces scripts pointent explicitement vers `${REPO_ROOT}/modules/dotfiles/...` et devront être adaptés au nouveau root externe.

## 3) Références documentation à mettre à jour

- `docs/README.md`
- `docs/MARIGOLD-PACKAGES.md`
- `docs/MARIGOLD-ZSH-FZF-COMPLETION.md`
- `docs/golden-path-home-manager.md`
- `docs/plans/2026-02-24-wezterm-smart-tab-titles*.md`

## 4) Références internes aux dotfiles (impact faible)

- `modules/dotfiles/**/README.md` et fichiers de config mentionnant le chemin `modules/dotfiles/...`

Ces références migreront naturellement avec le dossier, mais doivent être revues si elles décrivent l’ancien emplacement.

## 5) Risques identifiés

- Régression des scripts de bench/check zsh si le chemin hardcodé n’est pas retiré.
- Divergence doc/réalité si la documentation n’est pas mise à jour dans le même chantier.
- Couplage implicite au worktree `nix-config/dev` via `dotfilesDevPathDefault`.
