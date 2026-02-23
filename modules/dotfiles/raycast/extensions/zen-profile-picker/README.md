# Zen Profile Picker (Raycast)

Cette extension permet de basculer proprement (graceful shutdown) entre vos profils Zen Browser.

## Profils configurés

- **Professionnal** (💼) : Pour le travail.
- **Personal** (🧘‍♂️) : Navigation personnelle.
- **Default** (🌍) : Profil par défaut.

## Fonctionnement

L'extension utilise AppleScript pour demander à Zen de se fermer proprement avant de relancer l'application avec le flag `-P "NomDuProfil"`. Cela évite la corruption des bases SQLite et les messages d'erreur "Oups, Zen s'est fermé de manière inattendue".

## Installation

1. Ouvre Raycast
2. `Extensions` -> `Develop Extensions`
3. `Import Extension`
4. Sélectionne ce dossier: `modules/dotfiles/raycast/extensions/zen-profile-picker`

## Pré-requis

- Zen Browser installé dans `/Applications/Zen.app` (doit être reconnu par macOS sous le nom `Zen`).
