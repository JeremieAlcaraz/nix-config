
# Pour debug voir temps de chargement ! 
if [[ -n "$ZSH_DEBUGRC" ]]; then
  zmodload zsh/zprof
fi

# ~/.zshrc - Version corrigée
ZSH_CONFIG_DIR="$HOME/.config/zsh"
# 1. Chargement des modules dans l'ordre
for module in "$ZSH_CONFIG_DIR/modules"/*.zsh; do
    [[ -r "$module" ]] && source "$module"
done

# 3. Fonctions
for func in "$ZSH_CONFIG_DIR/functions"/*.zsh; do
    [[ -r "$func" ]] && source "$func"
done

# 4. Autres plugins (excluant zsh-autocomplete déjà chargé)
for plugin in "$ZSH_CONFIG_DIR/plugins"/*/*.zsh; do
    [[ "$(basename "$plugin")" == "zsh-autocomplete.plugin.zsh" ]] && continue
    [[ "$(basename "$plugin")" =~ ^(install|test|setup|uninstall)\.zsh$ ]] && continue
    [[ -r "$plugin" ]] && source "$plugin"
done
# =========================================================
# CONFIGURATION STRICTE SSH (fzf-tab suit ces réglages)
# =========================================================
# 1. Interdit à Zsh de lire /etc/hosts (plus de broadcasthost, localhost, gdmf.apple.com, mesu.apple.com)
zstyle ':completion:*:hosts' etc-hosts-files /dev/null
# 2. Ne propose que des hosts, pas les utilisateurs locaux (macports, pulse, root, etc.)
zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ip:ip'
# 3. Ceinture et bretelles : ignore explicitement les derniers indésirables
zstyle ':completion:*:*:*' ignored-patterns 'broadcasthost' 'localhost' '127.0.0.1' 'gdmf.apple.com' 'mesu.apple.com'
# 4. Garder aussi le filtrage des utilisateurs système génériques
zstyle ':completion:*:*:*:users' ignored-patterns '_*' 'root' 'daemon' 'nobody' 'polkitd' 'jeremiealcaraz'
# =========================================================


# pnpm
export PNPM_HOME="/Users/jeremiealcaraz/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/jeremiealcaraz/.lmstudio/bin"
# End of LM Studio CLI section

source /Users/jeremiealcaraz/.config/broot/launcher/bash/br
export PATH=$PATH:/Users/jeremiealcaraz/.spicetify


# Pour debug voir temps de chargement ! 
if [[ -n "$ZSH_DEBUGRC" ]]; then
  zprof
fi
source $HOME/.config/television/shell/integration.zsh

alias claude="/Users/jeremiealcaraz/.claude/local/claude"
export PATH="$HOME/.claude/local/bin:$PATH"
export PATH="$HOME/.claude/local/bin:$PATH"

# Added by Antigravity
export PATH="/Users/jeremiealcaraz/.antigravity/antigravity/bin:$PATH"

# Try.rb initialization
eval "$(ruby ~/.local/try.rb init ~/Development/_programmation/tries)"

# Added direnv for DX
eval "$(direnv hook zsh)"


lg() {
  # Crée un fichier temporaire pour stocker le chemin de sortie
  local temp_file=$(mktemp)

  # Lance lazygit, lui disant d'écrire le chemin dans ce fichier
  lazygit -o "$temp_file" "$@"

  # Lit le chemin depuis le fichier temporaire
  local worktree_path=$(cat "$temp_file")

  # Supprime le fichier temporaire
  rm "$temp_file"

  # Exécute le changement de répertoire si un chemin a été trouvé
  if [ -n "$worktree_path" ]; then
    cd "$worktree_path" || exit
  fi
}

# Shell switching helpers: drop inherited shell markers so Starship shows only the active shell
nu() { env -u ZSH_VERSION -u FISH_VERSION -u BASH_VERSION -u NU_VERSION command nu "$@"; }
f() { env -u ZSH_VERSION -u FISH_VERSION -u BASH_VERSION -u NU_VERSION command fish "$@"; }
