# 🧩 Ajouter un package sur Marigold (darwin)

Ce guide explique comment ajouter un nouveau package sur **Marigold** en respectant la structure actuelle du repo.

---

## ✅ Où ajouter quoi ?

### 1) **CLI / TUI (outil terminal)**
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

### 2) **GUI / app macOS**
Utilise Homebrew **cask** dans `hosts/marigold/configuration.nix`.

```nix
homebrew = {
  enable = true;
  casks = [
    "1password"
    "hammerspoon"
    "raycast"
  ];
};
```

---

### 3) **App avec config (dotfiles)**
Si l’outil a une config dédiée, place-la dans `modules/dotfiles/<app>/` puis référence-la via `xdg.configFile` dans `home/marigold.nix`.

Exemple :
```nix
xdg.configFile."myapp/config.toml".source = ../modules/dotfiles/myapp/config.toml;
```

---

### 4) **Cas spécifiques (plugins, runtime deps, etc.)**
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
# Alias perso
 drs

# Ou explicitement
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

- **CLI/TUI** → `home/marigold.nix` → `home.packages`
- **GUI** → `hosts/marigold/configuration.nix` → `homebrew.casks`
- **Config** → `modules/dotfiles/<app>/` + `xdg.configFile`
- **Dépendance spécifique à une app** → dans le bloc de cette app (ex: `programs.yazi.*`)

---

Si tu veux, je peux ajouter un exemple concret dans ce guide à partir d’un outil que tu choisis.
