# Separation of Concerns: `nix-config` vs `dotfiles`

## Décision

La machine utilise maintenant une séparation simple:

- `dotfiles` = contenu utilisateur + packages Homebrew
- `nix-config` = orchestration Nix/Home Manager/nix-darwin

## `dotfiles`

Source de vérité pour:

- les fichiers de config applicatifs
- le [Brewfile](/Users/jeremiealcaraz/c/dotfiles/Brewfile)
- les commandes `just` liées à Brew
- le bootstrap Brew d'une machine neuve

Exemples:

- `nvim/`
- `wezterm/`
- `zsh/`
- `Brewfile`
- `scripts/bootstrap-brew.sh`

## `nix-config`

Source de vérité pour:

- les déclarations Home Manager
- les déclarations nix-darwin
- les symlinks vers `dotfiles`
- les wrappers, variables d'environnement et services
- les secrets et modules Nix

Exemples:

- `home/marigold.nix`
- `hosts/marigold/configuration.nix`
- `modules/home-manager/*`
- `flake.nix`

## Règles pratiques

### Ajouter un package Brew

Éditer:

- [Brewfile](/Users/jeremiealcaraz/c/dotfiles/Brewfile)

Puis appliquer:

```bash
cd /Users/jeremiealcaraz/c/dotfiles
just brew-install-packages
```

### Modifier une config applicative

Éditer le fichier dans `dotfiles`.

Lancer `home-manager switch` seulement si tu changes la déclaration du lien, pas pour une simple édition de contenu.

### Modifier le système ou les liens

Éditer dans `nix-config` si tu touches:

- un `xdg.configFile`
- un `home.file`
- une variable d'environnement
- un wrapper
- un service `launchd`
- un réglage macOS

## Ce qu'on évite

On évite désormais de piloter Homebrew depuis `nix-darwin`.

Pourquoi:

- moins de noeuds mentaux
- une seule commande claire pour les packages Brew
- pas besoin de rebuild Nix pour ajouter un package Brew
- moins de confusion entre packages Nix et packages Brew

## Exception actuelle

Tous les binaires ne sont pas encore forcément migrés vers Brew.

Exemple: `nvim` peut rester géré par Nix tant qu'une migration explicite n'a pas été décidée.

La règle reste simple:

- package Brew voulu mutable et facilement upgradable: `dotfiles/Brewfile`
- package voulu déclaratif côté Nix: `home.packages` ou module dédié
