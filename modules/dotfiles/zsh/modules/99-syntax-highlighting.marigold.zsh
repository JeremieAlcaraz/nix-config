# Syntax highlighting - DOIT ÊTRE EN DERNIER
# Version Marigold : utilise les packages Nix via Home Manager

# Home Manager installe les packages dans ce profil
HM_SHARE="$HOME/.local/state/nix/profiles/home-manager/home-path/share"

# zsh-autosuggestions (géré par Home Manager)
if [[ -f "$HM_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HM_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting (defer): charge après le premier prompt.
autoload -Uz add-zsh-hook
_load_syntax_highlighting_deferred() {
    (( ${+_ZSH_SYNTAX_HIGHLIGHTING_LOADED} )) && return
    typeset -g _ZSH_SYNTAX_HIGHLIGHTING_LOADED=1

    if [[ -f "$HM_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        source "$HM_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi

    add-zsh-hook -d precmd _load_syntax_highlighting_deferred
}
add-zsh-hook precmd _load_syntax_highlighting_deferred
