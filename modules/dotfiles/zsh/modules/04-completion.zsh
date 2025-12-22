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
# MIS EN COMMENTAIRE - Incompatible avec fzf-tab
# -----------------------------------------------------------------
# source "$ZSH_CONFIG_DIR/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

# -----------------------------------------------------------------
# Carapace (complétions générées)
# -----------------------------------------------------------------
if command -v carapace &>/dev/null; then
  source <(carapace _carapace)
fi

# -----------------------------------------------------------------
# Plugin pnpm-shell-completion 
# -----------------------------------------------------------------
if [[ -f ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.zsh ]]; then
  source ~/.config/zsh/plugins/pnpm-shell-completion/pnpm-shell-completion.zsh
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
# Plugin fzf-tab (ACTIVÉ) 👍
# -----------------------------------------------------------------
# Remplace le menu de complétion standard par une interface fzf interactive.
# Assurez-vous que le chemin est correct pour votre installation.
if [[ -f "$ZSH_CONFIG_DIR/plugins/fzf-tab/fzf-tab.zsh" ]]; then
  # Activation du menu de sélection pour laisser fzf-tab prendre la main
  zmodload zsh/complist
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':completion:*' menu select
  (( ${+LS_COLORS} )) && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

  # Thème et UX fzf-tab
  zstyle ':fzf-tab:*' prefix ''
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:*' use-fzf-default-opts yes

  # Prévisualisation dédiée à git : affiche l'aide de la sous-commande à droite
  zstyle ':fzf-tab:complete:git-*' option-preview 'git help $word | col -bx | head -200'

  source "$ZSH_CONFIG_DIR/plugins/fzf-tab/fzf-tab.zsh"
fi
