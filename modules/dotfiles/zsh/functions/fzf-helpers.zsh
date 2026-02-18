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

typeset -gA _V_FZF_CACHE
typeset -gA _V_FZF_CACHE_TS

_v_candidates_cache_key() {
    local search_dir="${1:-$PWD}"
    local git_root=""

    if git_root="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        print -r -- "git:${git_root}"
        return 0
    fi

    print -r -- "dir:${search_dir:A}"
}

_v_candidates_cached() {
    local search_dir="${1:-$PWD}"
    local ttl="${ZSH_V_FZF_CACHE_TTL:-3}"
    local key=""
    local now=0
    local ts=0
    local data=""

    [[ "$ttl" == <-> ]] || ttl=3

    key="$(_v_candidates_cache_key "$search_dir")"
    now="${EPOCHSECONDS:-$(date +%s)}"
    ts="${_V_FZF_CACHE_TS[$key]-0}"

    if [[ -n "${_V_FZF_CACHE[$key]-}" ]] && (( now - ts <= ttl )); then
        print -r -- "${_V_FZF_CACHE[$key]}"
        return 0
    fi

    data="$(_v_candidates_source "$search_dir")" || return 1
    _V_FZF_CACHE[$key]="$data"
    _V_FZF_CACHE_TS[$key]="$now"
    print -r -- "$data"
}
