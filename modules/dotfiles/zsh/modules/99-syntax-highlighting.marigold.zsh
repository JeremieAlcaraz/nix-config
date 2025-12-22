# Syntax highlighting - DOIT ÊTRE EN DERNIER
# Version Marigold : utilise les packages Nix via Home Manager

# Home Manager installe les packages dans ce profil
HM_SHARE="$HOME/.local/state/nix/profiles/home-manager/home-path/share"

# zsh-syntax-highlighting (géré par Home Manager)
if [[ -f "$HM_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$HM_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# zsh-autosuggestions (géré par Home Manager)
if [[ -f "$HM_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HM_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
