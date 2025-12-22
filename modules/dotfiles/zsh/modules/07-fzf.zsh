# ~/.config/zsh/modules/07-fzf.zsh
# Configuration fzf

# Ajout au PATH si nécessaire
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Chargement de l'intégration zsh
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# Configuration personnalisée fzf (optionnel)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .DS_Store'
export FZF_DEFAULT_OPTS="--ansi --height 45% --layout=reverse --border=rounded --border-label=' completion ' --prompt='> ' --marker='✓' --pointer='▶' --separator='─' --info=inline --scrollbar='┃' --color=bg:#1e1e2e,fg:#cdd6f4,hl:#89b4fa,fg+:#f5e0dc,bg+:#313244,hl+:#89b4fa,spinner:#f38ba8,header:#f9e2af,info:#94e2d5,pointer:#f38ba8,marker:#a6e3a1,prompt:#89b4fa,scrollbar:#585b70,border:#585b70"
export FZF_CTRL_T_OPTS="--preview 'cat {}' --preview-window=right:50%"
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
