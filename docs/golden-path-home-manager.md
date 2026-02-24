# Golden Path — Home Manager Dev/Prod

## Vue d'ensemble

Ce repo utilise un système à deux profils Home Manager pour permettre d'éditer
les dotfiles en live (sans relancer `home-manager switch` à chaque modif) tout
en gardant une configuration de production stable.

```
nix-config/          (branche main)       → profil PROD
nix-config-playground/  (git worktree)    → profil DEV
```

---

## Les deux profils

| | `jeremiealcaraz` | `jeremiealcaraz-dev` |
|---|---|---|
| Répo | `nix-config` (main) | `nix-config-playground` (worktree) |
| `devMode` | `false` | `true` |
| Fichiers config | copiés dans le store Nix | **symlinkés** vers le worktree |
| `--impure` | non requis | **requis** |
| Prompt | `HM-CONFIG-PROD` (rose) | `HM-CONFIG-DEV` (violet) |

---

## Comment ça marche : devMode et mkOutOfStoreSymlink

En mode **prod**, les dotfiles sont copiés dans le store Nix (immuables) :
```
~/.config/aerospace/organize-workspaces.sh
  → /nix/store/xxxx-home-manager-files/.config/aerospace/organize-workspaces.sh
    (copie figée)
```

En mode **dev**, `mkOutOfStoreSymlink` crée une chaîne de symlinks jusqu'au
fichier réel dans le worktree :
```
~/.config/aerospace/organize-workspaces.sh
  → /nix/store/xxxx-home-manager-files/.config/aerospace/organize-workspaces.sh
    → /nix/store/xxxx-hm_organizeworkspaces.sh   (symlink store)
      → ~/Development/.../nix-config-playground/modules/dotfiles/aerospace/organize-workspaces.sh
        (fichier réel — éditable en live ✅)
```

**Apps qui bénéficient du live editing :** aerospace, sketchybar, wezterm,
zsh, git hooks, tmux.

---

## Le Golden Path

### 1. Passer en mode dev

```bash
hm-dev
# = cd nix-config-playground && home-manager switch --flake .#jeremiealcaraz-dev --impure
```

Ton prompt affiche **HM-CONFIG-DEV** en violet.
Tu peux maintenant éditer n'importe quel dotfile dans
`modules/dotfiles/` et voir l'effet immédiatement.

### 2. Tester les modifications

Édite un fichier — par exemple `modules/dotfiles/starship/starship.toml` —
puis recharge ton shell :

```bash
exec zsh
```

Pas besoin de relancer `home-manager switch` pour les fichiers symlinkés.
En revanche, si tu modifies un **fichier Nix** (`.nix`), il faut relancer `wcd`.

### 3. Vérifier que devMode est actif

```bash
# Méthode rapide : regarder le prompt
# → "HM-CONFIG-DEV" en violet = devMode actif

# Méthode explicite : suivre la chaîne de symlinks
readlink -f ~/.config/aerospace/organize-workspaces.sh
# → .../nix-config-playground/...  = devMode ✅
# → /nix/store/...                 = prod
```

### 4. Commiter et merger vers prod

Une fois satisfait de tes modifications :

```bash
cd ~/Development/_programmation/_production/_services/nix-config-playground
git add .
git commit -m "feat: ..."

# Merger vers main
cd ../nix-config
git merge playground   # ou via PR sur Gitea
```

### 5. Repasser en prod

```bash
hm-prod
# = cd nix-config && home-manager switch --flake .#jeremiealcaraz
```

Ton prompt affiche **HM-CONFIG-PROD** en rose.

---

## Règle d'or

> **Tu modifies toujours dans `nix-config-playground/`.**
> `nix-config/` (main) ne reçoit que des merges validés.

---

## Aide-mémoire des commandes

| Commande | Description |
|---|---|
| `hm-dev` | Bascule en mode dev (cd + home-manager switch) |
| `hm-prod` | Retour en prod (cd + home-manager switch) |
| `home-manager generations` | Voir l'historique des générations |
| `readlink -f ~/.config/aerospace/organize-workspaces.sh` | Vérifier le mode actif |
