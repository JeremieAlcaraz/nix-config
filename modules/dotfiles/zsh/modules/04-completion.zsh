# ~/.config/zsh/modules/04-completion.zsh
# Fichier configuré pour démarrer avec fzf-tab

# -----------------------------------------------------------------
# Initialisation du système de complétion de Zsh (optimisé)
# -----------------------------------------------------------------
autoload -Uz compinit

# Utilise un compdump par $ZDOTDIR (par défaut $HOME), et compile en .zwc pour accélérer le reload
zmodload zsh/parameter
local zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"

# Optimisation : ne recalculer le cache que si plus vieux que 20h, et skip l'audit lent
if [[ -n ${zcompdump}(#qNmh-20) ]]; then
  compinit -C -d "$zcompdump"
else
  compinit -u -d "$zcompdump"
fi

# Précompile le compdump si nécessaire (zsh charge automatiquement le .zwc s'il est plus récent)
if [[ -s $zcompdump && -w ${zcompdump:h} ]]; then
  local zcompzwc="${zcompdump}.zwc"
  if [[ ! -s $zcompzwc || $zcompdump -nt $zcompzwc ]]; then
    zcompile "$zcompdump"
  fi
fi

# -----------------------------------------------------------------
# Configuration générale de la complétion
# -----------------------------------------------------------------

# Ignorer les fichiers .DS_Store dans toutes les complétions de fichiers
fignore=(".DS_Store" "${fignore[@]}")

# SOLUTION DE CONTOURNEMENT : Complétion personnalisée pour nvim
_custom_completion_for_nvim() {
    local -a files
    files=(${(f)"$(fd --no-ignore --hidden --exclude .DS_Store)"})
    _describe 'files' files
}

# Appliquer la complétion personnalisée à `nvim` (et donc à l'alias `v`)
compdef _custom_completion_for_nvim nvim

# -----------------------------------------------------------------
# Menu de complétion natif (sélection avec flèches)
# -----------------------------------------------------------------
zmodload zsh/complist
zstyle ':completion:*' menu select
(( ${+LS_COLORS} )) && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Flèches dans les menus de complétion
bindkey -M menuselect '^[[A' up-line-or-history
bindkey -M menuselect '^[[B' down-line-or-history
bindkey -M menuselect '^[[C' forward-char
bindkey -M menuselect '^[[D' backward-char

# -----------------------------------------------------------------
# MIS EN COMMENTAIRE - Incompatible avec fzf-tab
# -----------------------------------------------------------------
# source "$ZSH_CONFIG_DIR/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

# -----------------------------------------------------------------
# Carapace (complétions générées)
# -----------------------------------------------------------------
if command -v carapace &>/dev/null; then
  source <(carapace _carapace zsh)
fi

# Raccourci : forcer la complétion Carapace (Alt-m)
_carapace_force_completion() {
  local cmd=${words[1]}
  local saved_pnpm_comp=""

  if [[ "$cmd" == "pnpm" ]]; then
    if ! (( $+functions[_carapace_lazy] )) && command -v carapace &>/dev/null; then
      eval "$(carapace _carapace zsh)"
    fi

    if (( $+functions[_carapace_lazy] )); then
      saved_pnpm_comp=${_comps[pnpm]}
      _comps[pnpm]=_carapace_lazy
    fi
  fi

  if (( ! $+widgets[fzf-tab-complete] )); then
    _fzf_tab_lazy_init >/dev/null 2>&1 || true
  fi

  if (( $+widgets[fzf-tab-complete] )); then
    zle fzf-tab-complete
  else
    zle complete-word
  fi

  if [[ "$cmd" == "pnpm" ]] && (( $+functions[_carapace_lazy] )); then
    if [[ -n "$saved_pnpm_comp" ]]; then
      _comps[pnpm]=$saved_pnpm_comp
    else
      unset "_comps[pnpm]"
    fi
  fi
}
zle -N carapace-force-completion _carapace_force_completion

# -----------------------------------------------------------------
# Plugin pnpm-shell-completion
# -----------------------------------------------------------------
if [[ -f ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.plugin.zsh ]]; then
  source ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.plugin.zsh
elif [[ -f ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.zsh ]]; then
  source ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.zsh
fi
if (( $+functions[_pnpm] )); then
  compdef _pnpm pnpm
fi

# -----------------------------------------------------------------
# MIS EN COMMENTAIRE - Rendu inutile par fzf-tab
# -----------------------------------------------------------------
# zmodload -i zsh/complist
# zstyle ':completion:*' menu yes select
#
# _carapace_pick() {
#   zle list-choices
#   zle menu-complete
#   zle -I
# }
# zle -N carapace-pick _carapace_pick
# bindkey '^[w' carapace-pick

# -----------------------------------------------------------------
# Plugin fzf-tab (lazy load): activé au premier Tab
# -----------------------------------------------------------------
_fzf_tab_lazy_init() {
  (( ${+_FZF_TAB_LAZY_INITIALIZED} )) && return 0
  typeset -g _FZF_TAB_LAZY_INITIALIZED=1

  if [[ ! -f "$ZSH_CONFIG_DIR/plugins/fzf-tab/fzf-tab.zsh" ]]; then
    return 1
  fi

  # Activation du menu de sélection pour laisser fzf-tab prendre la main
  zstyle ':completion:*:descriptions' format '[%d]'

  # IMPORTANT : Grouper les complétions pour éviter l'affichage simultané avec carapace
  zstyle ':completion:*' group-name ''

  # Thème et UX fzf-tab
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
    --tabstop=16 \
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

  # Une fois chargé, Tab pointe directement sur fzf-tab-complete.
  if (( $+widgets[fzf-tab-complete] )); then
    for keymap in emacs viins; do
      bindkey -M "$keymap" '^I' fzf-tab-complete
    done
  fi

  return 0
}

_fzf_tab_lazy_complete() {
  _fzf_tab_lazy_init >/dev/null 2>&1 || true

  if (( $+widgets[fzf-tab-complete] )); then
    zle fzf-tab-complete
  else
    zle complete-word
  fi
}
zle -N _fzf_tab_lazy_complete
for keymap in emacs viins; do
  bindkey -M "$keymap" '^I' _fzf_tab_lazy_complete
done

# Re-bind after plugins which may override keymaps.
if (( $+widgets[carapace-force-completion] )); then
  for keymap in emacs viins vicmd; do
    bindkey -M "$keymap" '^[m' carapace-force-completion
  done
fi
