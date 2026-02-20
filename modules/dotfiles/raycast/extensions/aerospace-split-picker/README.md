# Aero Split Picker (Raycast PoC)

Mini extension Raycast pour choisir une fenêtre AeroSpace et la splitter dans le workspace courant.

## Installation locale (PoC)

1. Ouvre Raycast
2. `Extensions` -> `Develop Extensions`
3. `Import Extension`
4. Sélectionne ce dossier:
   `modules/dotfiles/raycast/extensions/aerospace-split-picker`

## Usage

- Lance la commande: `Aero Split Picker`
- Filtre la fenêtre à ajouter
- Entrée puis choisis l'action (`Split Right/Left/Up/Down`)

### Commandes dédiées par direction

- `Aero Split Right`
- `Aero Split Left`
- `Aero Split Up`
- `Aero Split Down`

Tu peux assigner un hotkey Raycast à chacune:
1. `Raycast -> Manage Extensions`
2. `Aero Split Picker`
3. Sur chaque commande, `Assign Hotkey`
4. Mets par exemple:
   - Right: `cmd + ctrl + alt + right`
   - Left: `cmd + ctrl + alt + left`
   - Up: `cmd + ctrl + alt + up`
   - Down: `cmd + ctrl + alt + down`

## Pré-requis

- AeroSpace installé à: `/opt/homebrew/bin/aerospace`
- Raycast installé
