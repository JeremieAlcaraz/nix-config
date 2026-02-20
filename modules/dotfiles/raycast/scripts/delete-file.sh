#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Supp
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🗑️
# Documentation:
# @raycast.description test


#!/bin/bash

#!/bin/bash

# Récupère le chemin du fichier sélectionné dans le Finder
FILE_PATH=$(osascript -e 'tell application "Finder" to get POSIX path of (selection as alias)')

# Vérifie si un fichier a été sélectionné
if [ -z "$FILE_PATH" ]; then
    echo "Aucun fichier sélectionné dans le Finder."
    exit 1
fi

# Supprime le fichier sélectionné
if rm -f "$FILE_PATH"; then
    echo "Fichier supprimé : $FILE_PATH"
else
    echo "Erreur lors de la suppression du fichier."
    exit 1
fi

