########################################################
#                    TOOLS MODULE                      #
# Configuration des outils externes                   #
########################################################


# =========================================================
# SSH Agent - Forcer 1Password
# =========================================================

# Utiliser l'agent 1Password si disponible
if [ -S "$HOME/.1password/agent.sock" ]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi





# === PATH CONFIGURATION ===
# Add local user binaries to PATH
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
# === THEFUCK - Correction de commandes ===
if command -v thefuck &> /dev/null; then
    eval $(thefuck --alias)
fi

# === ZOXIDE - Navigation intelligente ===
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# === ATUIN - Shell history sync ===
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# === NAVI - Configuration et alias ===
if command -v navi &> /dev/null; then
    export NAVI_PATH="$HOME/.config/navi/cheats"
    alias navi='navi --path "$NAVI_PATH"'
fi

# === NNN - Configuration ===
if command -v nnn &> /dev/null; then
    export NNN_TMPFILE="$HOME/.config/nnn/.lastd"
    export NNN_OPTS="AdHoU"
    export NNN_FCOLORS='c1e2272e006033f7c6d6abc4'
fi

# === BAT - Configuration ===
if command -v bat &> /dev/null; then
    export BAT_THEME=tokyonight_night
fi


# === SCRIPTS PERSONNELS - Utilitaires GitHub ===
if [[ -d "$HOME/.config/zsh/scripts" ]]; then
    export PATH="$HOME/.config/zsh/scripts:$PATH"
    
    # Alias pour le téléchargeur de dossiers GitHub
    if [[ -f "$HOME/.config/zsh/scripts/github-folder-downloader.sh" ]]; then
        alias gh-dl="github-folder-downloader.sh"
    fi
    # Alias pour la suppression de dépôts GitHub (picker fzf)
    if [[ -f "$HOME/.config/zsh/scripts/delete-repo.sh" ]]; then
        alias dgh="delete-repo.sh"
    fi 
    # Alias pour créer un dépôt GitHub
    if [[ -f "$HOME/.config/zsh/scripts/mkrepo.sh" ]]; then
        alias cgh="mkrepo.sh"
    fi
fi


# == DOTFILE MANAGER FOR STOW ==
if [[ -f "$HOME/dotfiles/scripts/shell/dotfiles-manager.sh" ]]; then
    source "$HOME/dotfiles/scripts/shell/dotfiles-manager.sh"
fi


# vivid: LS_COLORS global theme
if command -v vivid &>/dev/null; then
  export LS_COLORS="$(vivid generate tokyonight-night)"
fi
# === DEBUG TOOLS (lazy load) ===
function zhooks() {
    source "${ZDOTDIR:-$HOME}/.zsh/plugins/zhooks/zhooks.plugin.zsh"
    unfunction zhooks
    zhooks "$@"
}
