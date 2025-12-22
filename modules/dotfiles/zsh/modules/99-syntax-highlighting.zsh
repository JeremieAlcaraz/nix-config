# Syntax highlighting - DOIT ÊTRE EN DERNIER
if [[ -f $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
    echo "⚠️ zsh-syntax-highlighting non trouvé"
fi


# Plugins si disponibles
[[ -f $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

