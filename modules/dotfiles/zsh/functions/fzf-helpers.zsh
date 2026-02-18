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

# Source de candidats "smart" pour nvim/v:
# 1) index git (tracked + untracked) si on est dans un repo
# 2) fallback fd sinon
_v_candidates_source() {
    local search_dir="${1:-$PWD}"
    local git_root=""

    if git_root="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        {
            git -C "$search_dir" ls-files
            git -C "$search_dir" ls-files --others --exclude-standard
        } | awk 'NF && !seen[$0]++ {print}' | while IFS= read -r rel; do
            printf '%s/%s\n' "$git_root" "$rel"
        done
        return 0
    fi

    fd --absolute-path --hidden --follow --exclude .git --exclude .DS_Store \
      --type f . "$search_dir" 2>/dev/null
}
