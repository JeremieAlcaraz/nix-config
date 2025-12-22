#!/usr/bin/env bash
# delete-repo.sh — supprime un ou plusieurs dépôts GitHub possédés par l’utilisateur

set -euo pipefail

# 1) Récupère le login du compte authentifié via gh
OWNER="$(gh api user -q .login)"

# 2) Liste jusqu’à 300 dépôts vous appartenant, et passe la liste à fzf
SELECTED_REPOS=$(
  gh repo list "$OWNER" --limit 300 --json nameWithOwner \
    --jq '.[].nameWithOwner' |
    fzf -m --prompt="Sélectionnez les dépôts à supprimer > "
)

# 3) Si l’utilisateur n’a rien choisi, on quitte proprement
[[ -z "$SELECTED_REPOS" ]] && {
  echo "Aucun dépôt sélectionné. Abort."
  exit 0
}

# 4) Suppression sans invite supplémentaire (« --yes »)
echo "$SELECTED_REPOS" | while read -r repo; do
  echo "🗑️  Suppression de $repo ..."
  gh repo delete "$repo" --yes
done

echo "✅  Terminé."
