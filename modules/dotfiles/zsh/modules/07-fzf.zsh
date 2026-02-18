# ~/.config/zsh/modules/07-fzf.zsh
# Configuration fzf

# Ajout au PATH si nécessaire
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Chargement de l'intégration zsh
if command -v fzf >/dev/null 2>&1; then
  if [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
    source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  elif [[ -f /usr/local/opt/fzf/shell/key-bindings.zsh ]]; then
    source /usr/local/opt/fzf/shell/key-bindings.zsh
  elif [[ -f /etc/profiles/per-user/$USER/share/fzf/key-bindings.zsh ]]; then
    source /etc/profiles/per-user/$USER/share/fzf/key-bindings.zsh
  else
    source <(fzf --zsh)
  fi
fi

# fzf-tab est configuré/lazy-load dans 04-completion.zsh pour éviter les doubles init.

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
