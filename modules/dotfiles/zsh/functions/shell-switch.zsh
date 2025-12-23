# Shell switching shortcuts
# Unset shell version variables to prevent Starship from showing multiple shells

# Switch to Nushell
n() {
    unset ZSH_VERSION FISH_VERSION NU_VERSION STARSHIP_SHELL
    exec nu
}

# Also define nu() for convenience
nu() {
    unset ZSH_VERSION FISH_VERSION NU_VERSION STARSHIP_SHELL
    exec command nu "$@"
}

# Switch to Zsh (reload) - zz to not conflict with zoxide
zz() {
    unset ZSH_VERSION FISH_VERSION NU_VERSION STARSHIP_SHELL
    exec zsh
}

# Switch to Fish
f() {
    unset ZSH_VERSION FISH_VERSION NU_VERSION STARSHIP_SHELL
    exec fish
}
