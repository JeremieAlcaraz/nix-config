#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Déplacer un fichier
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📁
# @raycast.argument1 { "type": "dropdown", "placeholder": "Choisir un dossier", "data": [{ "title": "Prospection", "value": "22. Prospection" }, { "title": "Automation", "value": "Automation" }, { "title": "Tests", "value": "Tests" }, { "title": "Archives", "value": "Archives" }] }

# Documentation:
# @raycast.description Déplace le fichier sélectionné vers un dossier choisi
# @raycast.author Votre Nom
# @raycast.authorURL VotreLien

# Chemin vers le fichier log pour débogage
log_file=~/Downloads/raycast-move.log

# Récupère les arguments passés depuis Raycast
target_folder="$1"  # Premier argument : dossier cible

# Vérifier si un dossier est fourni
if [ -z "$target_folder" ]; then
  echo "$(date): Aucun dossier sélectionné." >> "$log_file"
  exit 1
fi

# Récupérer le chemin complet du fichier sélectionné
file_path=$(osascript -e "tell application \"Finder\" to get POSIX path of (selection as alias)")

# Vérifier si un fichier est sélectionné
if [ -z "$file_path" ]; then
  echo "$(date): Aucun fichier sélectionné dans le Finder." >> "$log_file"
  exit 1
fi

# Déterminer le chemin cible pour le déplacement
parent_dir=$(dirname "$file_path")  # Répertoire parent du fichier sélectionné
destination="$parent_dir/$target_folder"  # Dossier cible dans le même répertoire

# Créer le dossier cible s'il n'existe pas
if [ ! -d "$destination" ]; then
  mkdir -p "$destination"
  echo "$(date): Dossier $target_folder créé dans $parent_dir." >> "$log_file"
fi

# Déplacer le fichier
mv "$file_path" "$destination/"

# Vérifier si le déplacement a réussi
if [ $? -ne 0 ]; then
  echo "$(date): Erreur lors du déplacement de $file_path vers $destination." >> "$log_file"
else
  echo "$(date): Fichier $file_path déplacé avec succès vers $destination." >> "$log_file"
fi
