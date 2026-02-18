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
    local git_prefix=""
    local up_prefix=""
    local depth=0
    local -a prefix_parts

    if git_root="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        git_prefix="$(git -C "$search_dir" rev-parse --show-prefix 2>/dev/null)"
        if [[ -n "$git_prefix" ]]; then
            prefix_parts=("${(@s:/:)${git_prefix%/}}")
            depth=${#prefix_parts}
            while (( depth > 0 )); do
                up_prefix+="../"
                (( depth-- ))
            done
        fi

        {
            git -C "$git_root" ls-files --full-name
            git -C "$git_root" ls-files --others --exclude-standard --full-name
        } | awk 'NF && !seen[$0]++ {print}' | while IFS= read -r root_rel; do
            if [[ -n "$git_prefix" && "$root_rel" == "$git_prefix"* ]]; then
                printf '%s\n' "${root_rel#$git_prefix}"
            else
                printf '%s%s\n' "$up_prefix" "$root_rel"
            fi
        done
        return 0
    fi

    (
        cd "$search_dir" 2>/dev/null || exit 0
        fd --hidden --follow --exclude .git --exclude .DS_Store \
          --type f . 2>/dev/null
    )
}

typeset -gA _V_FZF_CACHE
typeset -gA _V_FZF_CACHE_TS

_v_candidates_cache_log() {
    (( ${ZSH_V_FZF_CACHE_DEBUG:-0} )) || return 0
    print -u2 -- "[v-cache] $*"
}

_v_candidates_cache_key() {
    local search_dir="${1:-$PWD}"
    local git_root=""

    if git_root="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        print -r -- "git:${git_root}:cwd:${search_dir:A}"
        return 0
    fi

    print -r -- "dir:${search_dir:A}"
}

_v_candidates_cache_invalidate() {
    local target="${1:---all}"
    local key=""

    if [[ "$target" == "--all" ]]; then
        unset _V_FZF_CACHE _V_FZF_CACHE_TS
        typeset -gA _V_FZF_CACHE
        typeset -gA _V_FZF_CACHE_TS
        _v_candidates_cache_log "invalidate all"
        return 0
    fi

    key="$(_v_candidates_cache_key "$target")"
    unset "_V_FZF_CACHE[$key]"
    unset "_V_FZF_CACHE_TS[$key]"
    _v_candidates_cache_log "invalidate key=${key}"
}

_v_candidates_cache_stats() {
    print -r -- "entries=${#_V_FZF_CACHE} ttl=${ZSH_V_FZF_CACHE_TTL:-3}s debug=${ZSH_V_FZF_CACHE_DEBUG:-0}"
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
        _v_candidates_cache_log "hit key=${key} age=$((now-ts))s"
        print -r -- "${_V_FZF_CACHE[$key]}"
        return 0
    fi

    _v_candidates_cache_log "miss key=${key}"
    data="$(_v_candidates_source "$search_dir")" || return 1
    _V_FZF_CACHE[$key]="$data"
    _V_FZF_CACHE_TS[$key]="$now"
    print -r -- "$data"
}

_v_candidates_for_nvim_fzf() {
    local rel=""
    local dir=""
    local base=""
    local display=""
    local reset=$'\033[0m'
    local dir_color=$'\033[2;38;2;120;170;255m'
    local file_color=$'\033[1;38;2;255;120;245m'

    _v_candidates_cached | while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        [[ "$rel" == "./"* ]] && rel="${rel#./}"
        [[ -z "$rel" || "$rel" == "." ]] && continue

        dir="${rel:h}"
        base="${rel:t}"

        if [[ -z "$dir" || "$dir" == "." ]]; then
            display="${file_color}${base}${reset}"
        else
            display="${dir_color}${dir}/${reset}${file_color}${base}${reset}"
        fi

        printf '%s\t%s\n' "$display" "$rel"
    done
}

_fzf_complete_nvim() {
    (( $+functions[_fzf_complete] )) || return 1
    _fzf_complete \
      --ansi \
      --delimiter=$'\t' \
      --with-nth=1 \
      --height=85% \
      --layout=reverse \
      --border=rounded \
      --border-label=' nvim files ' \
      --prompt='nvim> ' \
      --pointer='▶' \
      --marker='✓' \
      --info=inline-right \
      --preview-window='right:58%,border-left,wrap' \
      --bind='ctrl-/:toggle-preview' \
      --color='bg:#11111b,fg:#cdd6f4,hl:#89b4fa,fg+:#f5c2e7,bg+:#313244,hl+:#f9e2af,pointer:#f38ba8,marker:#a6e3a1,prompt:#89b4fa,info:#94e2d5,border:#585b70,header:#bac2de' \
      --preview='target=$(printf "%s" {} | awk -F "\t" "{print \$2}"); if [[ -z "$target" ]]; then exit 0; fi; if [[ -d "$target" ]]; then if command -v eza >/dev/null 2>&1; then eza --icons=always --color=always -la "$target"; else ls -la "$target"; fi; else if command -v bat >/dev/null 2>&1; then bat --style=plain --color=always --line-range=:220 "$target" 2>/dev/null || sed -n "1,220p" "$target"; else sed -n "1,220p" "$target"; fi; fi' \
      -- "$@" < <(_v_candidates_for_nvim_fzf)
}

_fzf_complete_nvim_post() {
    local _display=""
    local insert=""
    while IFS=$'\t' read -r _display insert; do
        [[ -z "$insert" ]] && continue
        print -r -- "${(q)insert}"
    done
}

_fzf_complete_v() {
    _fzf_complete_nvim "$@"
}
