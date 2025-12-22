# Configuration historique basique
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_ignore_dups

# Navigation historique
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
