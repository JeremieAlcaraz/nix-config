# 🧩 Ajouter un package sur Marigold (darwin)

Ce guide explique comment ajouter un nouveau package sur **Marigold** avec la séparation actuelle:

- `dotfiles` pour les packages Homebrew
- `nix-config` pour les packages Nix et l'orchestration système

---

## ✅ Où ajouter quoi ?

### 1) **CLI / TUI via Homebrew**

Ajoute-le dans [Brewfile](/Users/jeremiealcaraz/c/dotfiles/Brewfile).

```ruby
brew "neovim"
brew "ripgrep"
brew "fd"
brew "jq"
```

Puis applique:

```bash
cd /Users/jeremiealcaraz/c/dotfiles
just brew-install-packages
```

---

### 2) **CLI / TUI via Nix**

Utilise cette voie seulement si tu veux explicitement garder le package côté Nix.

Ajoute-le dans `home/marigold.nix` → `home.packages`.

```nix
home.packages = with pkgs; [
  # ...
  ripgrep
  fd
  # nouvel outil
  jq
];
```

Si le package est plus récent en unstable :
```nix
home.packages = with pkgs; [
  unstable.tabiew
];
```

---

### 3) **GUI / app macOS**

Utilise Homebrew **cask** dans [Brewfile](/Users/jeremiealcaraz/c/dotfiles/Brewfile).

```ruby
cask "1password"
cask "hammerspoon"
cask "raycast"
```

---

### 4) **App avec config (dotfiles)**
Si l’outil a une config dédiée, place-la dans `modules/dotfiles/<app>/` puis référence-la via `xdg.configFile` dans `home/marigold.nix`.

Exemple :
```nix
xdg.configFile."myapp/config.toml".source = ../modules/dotfiles/myapp/config.toml;
```

---

### 5) **Cas spécifiques (plugins, runtime deps, etc.)**
Si un outil est **uniquement requis par une app**, préfère le déclarer près de cette app.

Exemple (Yazi) :
```nix
programs.yazi.yaziPlugins.runtimeDeps = lib.mkAfter [
  pkgs.unstable.tabiew
];
```

---

## 🔍 Trouver un package

```bash
# Stable
nix search nixpkgs <nom>

# Unstable (si besoin d'une version récente)
nix search nixpkgs-unstable <nom>
```

---

## 🚀 Appliquer

```bash
# Packages Brew
cd ~/c/dotfiles && just brew-install-packages

# Rebuild Nix seulement si tu as touché à la partie Nix
 darwin-rebuild switch --flake .#marigold
```

---

## ✅ Vérifier

```bash
command -v <binaire>
<outil> --version
```

---

## 🧠 Résumé “structure propre”

- **Packages Homebrew CLI/TUI/GUI** → `dotfiles/Brewfile`
- **Packages Nix** → `home/marigold.nix` → `home.packages`
- **Config** → `modules/dotfiles/<app>/` + `xdg.configFile`
- **Dépendance spécifique à une app** → dans le bloc de cette app (ex: `programs.yazi.*`)

---

Si tu veux, je peux ajouter un exemple concret dans ce guide à partir d’un outil que tu choisis.
