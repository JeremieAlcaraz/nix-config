# ~/.zshenv - Version corrigée
# ~/.zshenv - Version corrigée avec priorité forcée
export XDG_CONFIG_HOME="$HOME/.config"

# Éditeurs
export EDITOR="nvim"
export VISUAL="nvim"
export MANPAGER="nvim +Man\!"

# Palette de couleurs
export BLACK=0xff181819
export WHITE=0xffe2e2e3
export RED=0xfffc5d7c
export GREEN=0xff9ed072
export BLUE=0xff76cce0
export YELLOW=0xffe7c664
export ORANGE=0xfff39660
export MAGENTA=0xffb39df3
export GREY=0xff7f8490
export TRANSPARENT=0x00000000
export BG0=0xff2c2e34
export BG1=0xff363944
export BG2=0xff414550

# Homebrew - nécessaire partout (scripts, shells non-interactifs, etc.)
export PATH="/opt/homebrew/bin:$PATH"


# Age Key
export SOPS_AGE_KEY_FILE="$XDG_CONFIG_HOME/sops/age/keys.txt"
