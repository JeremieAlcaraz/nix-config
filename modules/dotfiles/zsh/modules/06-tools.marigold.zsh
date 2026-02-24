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

# === FNM - Node manager (lazy init) ===
# Flow recommandé:
# - node/npm globaux (Nix) par défaut pour shell/scripts/agents.
# - fnm chargé seulement quand tu en as besoin pour switcher de version.
if command -v fnm &> /dev/null; then
    __fnm_lazy_init() {
        if [[ -n "${__FNM_LAZY_READY:-}" ]]; then
            return 0
        fi
        export __FNM_LAZY_READY=1

        # En shell nix develop, garder la toolchain Node fournie par Nix.
        local nix_node_path
        nix_node_path="$(whence -p node 2>/dev/null || true)"
        if [[ -n "${IN_NIX_SHELL:-}" && -n "$nix_node_path" ]]; then
            return 0
        fi

        eval "$(command fnm env --shell zsh)" >/dev/null 2>&1 || true
    }

    # Initialise fnm à la demande sans coût au startup shell.
    fnm() {
        __fnm_lazy_init
        command fnm "$@"
    }

    # Raccourci pratique: nuse 20 / nuse 22 / nuse --install-if-missing
    nuse() {
        __fnm_lazy_init
        command fnm use "$@"
    }
fi

# === ANY-NIX-SHELL - auto load nix-shell/flake envs ===
if command -v any-nix-shell &> /dev/null; then
    any-nix-shell zsh --info-right | source /dev/stdin
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

# === BROOT - File tree explorer ===
if command -v broot &> /dev/null; then
    function br {
        local cmd cmd_file code
        cmd_file=$(mktemp)
        if broot --outcmd "$cmd_file" "$@"; then
            cmd=$(<"$cmd_file")
            command rm -f "$cmd_file"
            eval "$cmd"
        else
            code=$?
            command rm -f "$cmd_file"
            return "$code"
        fi
    }
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

# === TELEVISION - Fuzzy Finder ===
# Keybindings: Ctrl+Y (smart autocomplete), Ctrl+O (shell history)
if command -v tv &> /dev/null; then
    if [[ -f "$HOME/.config/television/shell/integration.zsh" ]]; then
        source "$HOME/.config/television/shell/integration.zsh"
    fi
fi

# === CCL - CLI pour MiniMax ===
ccl() {
    command ccl "$@"
}

# === WEZTERM - Titres de tabs intelligents ===
# Envoie le contexte git/dossier à WezTerm via OSC 1337 SetUserVar.
# Déclenché après chaque commande (precmd hook).
# Guard : ne s'active que dans WezTerm ($WEZTERM_PANE est défini par WezTerm).
if [[ -n "${WEZTERM_PANE:-}" ]]; then
  __wezterm_update_tab_title() {
    local title git_branch git_root repo_name
    git_branch=$(git branch --show-current 2>/dev/null)

    if [[ -n "$git_branch" ]]; then
      if [[ "$git_branch" == "main" || "$git_branch" == "master" ]]; then
        # Pour main/master : affiche nom-repo/main
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        repo_name=$(basename "$git_root")
        title="${repo_name}/${git_branch}"
      else
        # Autres branches : affiche la branche directement (ex: feat/toto)
        title="$git_branch"
      fi
    else
      # Hors dépôt git : affiche le nom du dossier courant
      title="${PWD##*/}"
    fi

    # Envoie la variable à WezTerm via OSC 1337
    # base64 requis par le protocole ; tr -d '\n' supprime les sauts de ligne
    printf "\033]1337;SetUserVar=WEZTERM_TAB_TITLE=%s\007" \
      "$(printf '%s' "$title" | base64 | tr -d '\n')"
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __wezterm_update_tab_title
fi
