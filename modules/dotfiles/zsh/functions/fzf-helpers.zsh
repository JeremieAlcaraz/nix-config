# ~/.config/zsh/functions/fzf-helpers.zsh
# Fonctions utilitaires fzf

# Éditer un fichier avec fzf
fzf-edit() {
    local file
    file=$(fzf --query="$1" --select-1 --exit-0)
    [ -n "$file" ] && ${EDITOR:-vim} "$file"
}

# Recherche dans les fichiers git
fzf-git() {
    git ls-files | fzf --preview 'cat {}'
}

