########################################################
#                    TOOLS MODULE - MARIGOLD           #
# Configuration des outils pour macOS (gérés par Nix) #
########################################################

# === SSH Agent - 1Password ===
if [ -S "$HOME/.1password/agent.sock" ]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

# === LOCAL BINARIES ===
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# === THEFUCK - Correction de commandes ===
# Géré par Home Manager
if command -v thefuck &> /dev/null; then
    eval $(thefuck --alias)
fi

# === ZOXIDE - Navigation intelligente ===
# Géré par Home Manager
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# === ATUIN - Shell history sync ===
# Géré par Home Manager
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# === NAVI - Cheatsheets interactifs ===
# Géré par Home Manager
if command -v navi &> /dev/null; then
    export NAVI_PATH="$HOME/.config/navi/cheats"
    alias navi='navi --path "$NAVI_PATH"'
fi

# === TABIEW - CSV viewer ===
if command -v tw &> /dev/null; then
    alias tabview="tw"
    alias tabiew="tw"
fi

# === BAT - Cat amélioré ===
# Géré par Home Manager
if command -v bat &> /dev/null; then
    export BAT_THEME=tokyonight_night
fi

# === VIVID - LS_COLORS thème ===
# Géré par Home Manager
if command -v vivid &>/dev/null; then
  export LS_COLORS="$(vivid generate tokyonight-night)"
fi

# === DIRENV - Gestion d'environnements par projet ===
# Géré par Home Manager
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# === SCRIPTS PERSONNELS ===
# Scripts dans ~/.config/zsh/scripts (gérés par Home Manager)
if [[ -d "$HOME/.config/zsh/scripts" ]]; then
    export PATH="$HOME/.config/zsh/scripts:$PATH"

    # Alias pour les scripts GitHub
    [[ -f "$HOME/.config/zsh/scripts/github-folder-downloader.sh" ]] && alias gh-dl="github-folder-downloader.sh"
    [[ -f "$HOME/.config/zsh/scripts/delete-repo.sh" ]] && alias dgh="delete-repo.sh"
    [[ -f "$HOME/.config/zsh/scripts/mkrepo.sh" ]] && alias cgh="mkrepo.sh"
fi
