# === NAVIGATION ET SYSTÈME ===
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias home="cd ~"
alias x="exit"
alias c="clear"

# Listing (eza si disponible, sinon ls par défaut)
if command -v eza &> /dev/null; then
    alias ls="eza --icons=always"
    alias ll="eza -la --icons --group-directories-first --ignore-glob='.DS_Store'"
    alias lt="eza --tree --level=2 --long --icons --git"
    alias ltd="eza --tree --level=2 --long --icons --git -a --git-ignore --ignore-glob='.DS_Store'"
    alias tree="eza --tree --icons --git"
else
    alias ll="ls -la"
fi

# === CONFIGURATION SHELL ===

alias reload-zsh="source ~/.zshrc"
alias edit-zsh="nvim ~/.zshrc"
alias edit-zshenv="nvim ~/.zshenv"

# === SYSTÈME macOS ===
alias clean-dsstore="find ~ -name .DS_Store -delete"
alias show-hidden="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
alias hide-hidden="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"

# === RÉSEAU ===
alias ssh="TERM=xterm-256color ssh"
alias ping="ping -c 5"
alias ports="lsof -i -P -n | grep LISTEN"

# === RACCOURCIS PRATIQUES ===
alias h="history"
alias j="jobs"
# alias path="echo $PATH | tr ':' '\n'"
alias reload="exec zsh"
alias v="nvim"
alias m="ncspot"
alias y="yazi"
alias e="emacs -nw" # lance emacs dans mon terminal




########################################################
#                      GIT ALIASES                     #
########################################################
alias gc="git clone"
alias add="git add"
alias commit="git commit"
alias pull="git pull"
alias gs="git status"
alias gdiff="git diff HEAD"
alias vdiff="git difftool HEAD"
alias log="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias cfg="git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"
alias push="git push"
alias g="lazygit"
alias d="lazydocker"

########################################################
#                      NIX ALIASES                     #
########################################################
alias nd="nix develop"
alias drs="darwin-rebuild switch --flake .#marigold"
alias sops-edit='SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/key.txt" sops'
alias sops-view='SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/key.txt" sops --decrypt'
