# ~/.config/zsh/modules/07-fzf.zsh
# Configuration fzf

# Ajout au PATH si nécessaire
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Chargement de l'intégration zsh
if command -v fzf >/dev/null 2>&1; then
  fzf_shell_dir=""
  if [[ -d /opt/homebrew/opt/fzf/shell ]]; then
    fzf_shell_dir="/opt/homebrew/opt/fzf/shell"
  elif [[ -d /usr/local/opt/fzf/shell ]]; then
    fzf_shell_dir="/usr/local/opt/fzf/shell"
  elif [[ -d /etc/profiles/per-user/$USER/share/fzf ]]; then
    fzf_shell_dir="/etc/profiles/per-user/$USER/share/fzf"
  fi

  if [[ -n "$fzf_shell_dir" && -f "$fzf_shell_dir/key-bindings.zsh" ]]; then
    source "$fzf_shell_dir/key-bindings.zsh"
    # Active la completion fzf native (inclut le trigger **<TAB>).
    [[ -f "$fzf_shell_dir/completion.zsh" ]] && source "$fzf_shell_dir/completion.zsh"
  else
    # Fallback universel fourni par fzf (key-bindings + completion).
    source <(fzf --zsh)
  fi

  # completion.zsh rebind Tab sur fzf-completion. On conserve fzf-tab comme
  # comportement par défaut pour Tab; la completion fzf pourra être appelée
  # de façon ciblée (ex: wrapper nvim) dans les tâches suivantes.
  if (( $+widgets[fzf-tab-complete] )); then
    for keymap in emacs viins; do
      bindkey -M "$keymap" '^I' fzf-tab-complete
    done
  fi
fi

# fzf-tab est configuré/lazy-load dans 04-completion.zsh pour éviter les doubles init.

# Source de candidats fzf completion basée sur fd (récursif).
_fzf_compgen_path() {
  fd --hidden --follow --exclude .git --exclude .DS_Store \
    --type f --type d --type l . "${1:-.}" 2>/dev/null
}

_fzf_compgen_dir() {
  fd --hidden --follow --exclude .git --exclude .DS_Store \
    --type d . "${1:-.}" 2>/dev/null
}

# Configuration personnalisée fzf (optionnel)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .DS_Store'
export FZF_DEFAULT_OPTS="--ansi --height 45% --layout=reverse --border=rounded --border-label=' completion ' --prompt='> ' --marker='✓' --pointer='▶' --separator='─' --info=inline --scrollbar='┃' --color=bg:#1e1e2e,fg:#cdd6f4,hl:#89b4fa,fg+:#f5e0dc,bg+:#313244,hl+:#89b4fa,spinner:#f38ba8,header:#f9e2af,info:#94e2d5,pointer:#f38ba8,marker:#a6e3a1,prompt:#89b4fa,scrollbar:#585b70,border:#585b70"
export FZF_CTRL_T_OPTS="--preview 'cat {}' --preview-window=right:50%"
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"

# Re-bind Alt-m after fzf setup (some init scripts reset keymaps).
if (( $+widgets[carapace-force-completion] )); then
  for keymap in emacs viins vicmd; do
    bindkey -M "$keymap" '^[m' carapace-force-completion
  done
fi
