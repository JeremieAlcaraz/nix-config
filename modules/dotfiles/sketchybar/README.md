# Sketchybar - icones d'apps

Ce dossier contient la config Sketchybar. Les icones d'apps utilisees dans la barre
viennent d'un mapping base sur le nom d'app renvoye par AeroSpace.

## Comment ca fonctionne

- `modules/dotfiles/sketchybar/items/spaces.lua` liste les fenetres via:
  `aerospace list-windows --workspace ... --format '%{app-name}' --json`
- Chaque `app-name` est mappe dans `modules/dotfiles/sketchybar/helpers/app_icons.lua`.
- Si aucune entree ne correspond, on utilise `app_icons["default"]`.
- La police d'icones est definie dans `modules/dotfiles/sketchybar/settings.lua`
  (`settings.icons`). Par defaut: `sketchybar-app-font:Regular:16.0`.

## Ajouter une icone pour une app

1) Trouver le nom exact de l'app:
```bash
aerospace list-windows --all --format '%{app-name}' | sort -u
```

2) Ajouter une entree dans `modules/dotfiles/sketchybar/helpers/app_icons.lua`:
```lua
["Nom Exact App"] = ":nom_icone:",
```

3) Redemarrer Sketchybar si besoin.

## Mettre des icones custom

Option A (recommande): utiliser une icone de `sketchybar-app-font`.
- Les valeurs `:nom_icone:` sont des ligatures de cette police.
- Ajoute simplement le bon token dans `app_icons.lua`.

Option B: utiliser une autre police (ex: Nerd Font).
1) Installer la police sur macOS.
2) Mettre a jour `settings.icons` dans `modules/dotfiles/sketchybar/settings.lua`.
3) Dans `app_icons.lua`, utiliser directement le glyphe (caractere Unicode) au lieu de
   `:nom_icone:`.
