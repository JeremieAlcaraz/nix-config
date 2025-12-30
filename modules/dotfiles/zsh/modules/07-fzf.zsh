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

# -----------------------------------------------------------------
# Plugin fzf-tab (ACTIVÉ) 👍
# -----------------------------------------------------------------
# Remplace le menu de complétion standard par une interface fzf interactive.
# Assurez-vous que le chemin est correct pour votre installation.
if [[ -f "$ZSH_CONFIG_DIR/plugins/fzf-tab/fzf-tab.zsh" ]]; then
  # Activation du menu de sélection pour laisser fzf-tab prendre la main
  zstyle ':completion:*:descriptions' format '[%d]'

  # IMPORTANT : Grouper les complétions pour éviter l'affichage simultané avec carapace
  zstyle ':completion:*' group-name ''

  # Thème et UX fzf-tab - Reprise du thème Catppuccin Mocha de FZF_DEFAULT_OPTS
  zstyle ':fzf-tab:*' prefix ''
  zstyle ':fzf-tab:*' switch-group '<' '>'

  # Applique le même style que ton FZF_DEFAULT_OPTS (Catppuccin Mocha)
  zstyle ':fzf-tab:*' fzf-flags \
    --ansi \
    --height=80% \
    --layout=reverse \
    --border=rounded \
    --prompt='> ' \
    --marker='✓' \
    --pointer='▶' \
    --separator='─' \
    --info=inline \
    --scrollbar='┃' \
    --tabstop=8 \
    --color=bg:#1e1e2e,fg:#cdd6f4,hl:#89b4fa \
    --color=fg+:#f5e0dc,bg+:#313244,hl+:#89b4fa \
    --color=spinner:#f38ba8,header:#f9e2af,info:#94e2d5 \
    --color=pointer:#f38ba8,marker:#a6e3a1,prompt:#89b4fa \
    --color=scrollbar:#585b70,border:#585b70

  # Optimisations pour carapace + fzf-tab
  zstyle ':completion:*' fzf-search-display true
  zstyle ':fzf-tab:complete:*' fzf-bindings 'space:toggle+down'
  zstyle ':fzf-tab:*' query-string prefix first

  # Prévisualisation dédiée à git : affiche l'aide de la sous-commande à droite
  zstyle ':fzf-tab:complete:git-*' option-preview 'git help $word | col -bx | head -200'

  source "$ZSH_CONFIG_DIR/plugins/fzf-tab/fzf-tab.zsh"

  # Désactiver la complétion fzf classique si elle est chargée.
  if (( $+functions[fzf-completion] )); then
    unfunction fzf-completion
  fi

  # Assurer que Tab reste bien géré par fzf-tab.
  if (( $+widgets[fzf-tab-complete] )); then
    for keymap in emacs viins; do
      bindkey -M "$keymap" '^I' fzf-tab-complete
    done
  fi
fi

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
