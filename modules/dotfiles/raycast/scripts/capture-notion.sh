#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture 
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Notes" }
# Documentation:
# @raycast.description Capture to Notion my notes (with n8n)

note="$1" # Récupère l'argument passé depuis Raycast

webhook_url="https://n8n.jeremiealcaraz.com/webhook/6e5e07c7-e0af-4d8c-8ef5-de52fb131e12"

# Vérifier si une note est fournie
if [ -z "$note" ]; then
  echo "Aucune note fournie"
  exit 1
fi

# Envoyer la requête cURL
curl -X POST "$webhook_url" \
     -H "Content-Type: application/json" \
     -d "{\"note\": \"$note\"}"

# Vérifier si cURL a échoué
if [ $? -ne 0 ]; then
  echo "Erreur lors de l'envoi de la requête"
  exit 1
else
  echo "Note envoyée avec succès"
fi
