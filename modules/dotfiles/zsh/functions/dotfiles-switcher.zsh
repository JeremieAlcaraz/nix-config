########################################################
#                🎯 DOTFILES SWITCHER                 #
# Fonction fancy pour gérer le basculement entre      #
# différentes versions de dotfiles avec GNU Stow      #
########################################################

dotv() {
    local script_path="$HOME/dotfiles/scripts/shell/switch-dotfiles.sh"
    
    # Couleurs ANSI
    local RESET='\033[0m'
    local BOLD='\033[1m'
    local DIM='\033[2m'
    local RED='\033[31m'
    local GREEN='\033[32m'
    local YELLOW='\033[33m'
    local BLUE='\033[34m'
    local MAGENTA='\033[35m'
    local CYAN='\033[36m'
    local WHITE='\033[37m'
    
    # Animation de loading
    _loading_animation() {
        local msg="$1"
        local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        local i=0
        while [[ $i -lt 6 ]]; do
            echo -ne "\r${CYAN}${chars:$i:1}${RESET} $msg"
            sleep 0.08
            i=$((i+1))
        done
        echo -ne "\r${GREEN}✓${RESET} $msg\n"
    }
    
    # Header ultra-fancy
     _print_header() {
        echo -e "${BOLD}${MAGENTA}"
        echo "╭─────────────────────────────────────────╮"
        echo "│    /\\_/\\    DOTFILES SWITCH             │"
        echo "│   ( o.o )     BY JEREMIAOU              │"
        echo "│    > ^ <                                 │"
        echo "│    ${DIM}Powered by GNU Stow & LazyVim${RESET}${BOLD}${MAGENTA}    │"
        echo "╰─────────────────────────────────────────╯"
        echo -e "${RESET}"
    }
    
    # Profile info avec icônes personnalisées
    _get_profile_info() {
        case "$1" in
            "lazy"|"lazyvim") echo "🚀 ${YELLOW}LazyVim${RESET} - Configuration développement NeoVim" ;;
            "perso"|"personal") echo "⚡ ${BLUE}Personal${RESET} - Configuration personnelle optimisée" ;;
            *) echo "❓ ${RED}Unknown${RESET} - Profile inconnu" ;;
        esac
    }
    
    # Vérifier que le script existe avec style
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}╭─ ERREUR ─────────────────────────────────╮${RESET}"
        echo -e "${RED}│ ❌ Script non trouvé :                  │${RESET}"
        echo -e "${RED}│    ${script_path}    │${RESET}"
        echo -e "${RED}╰──────────────────────────────────────────╯${RESET}"
        return 1
    fi
    
    # Gestion des commandes avec style
    case "$1" in
        "switch")
            _print_header
            echo -e "${BOLD}${CYAN}🔄 CHANGEMENT DE CONFIGURATION${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            
            case "$2" in
                "lazy")
                    echo -e "Basculement vers: $(_get_profile_info "lazy")"
                    _loading_animation "Application de la configuration LazyVim..."
                    "$script_path" switch lazyvim "${@:3}"
                    ;;
                "perso")
                    echo -e "Basculement vers: $(_get_profile_info "perso")"
                    _loading_animation "Application de la configuration Personal..."
                    "$script_path" switch personal "${@:3}"
                    ;;
                *)
                    echo -e "Basculement vers: ${CYAN}$2${RESET}"
                    _loading_animation "Application de la configuration $2..."
                    "$script_path" switch "$2" "${@:3}"
                    ;;
            esac
            ;;
            
        "lazy")
            _print_header
            echo -e "${BOLD}${CYAN}🚀 ACTIVATION LAZYVIM${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "Configuration: $(_get_profile_info "lazy")"
            _loading_animation "Basculement rapide vers LazyVim..."
            "$script_path" switch lazyvim "${@:2}"
            ;;
            
        "perso")
            _print_header
            echo -e "${BOLD}${CYAN}⚡ ACTIVATION PERSONAL${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "Configuration: $(_get_profile_info "perso")"
            _loading_animation "Basculement rapide vers Personal..."
            "$script_path" switch personal "${@:2}"
            ;;
            
        "status")
            _print_header
            echo -e "${BOLD}${CYAN}📊 STATUT SYSTÈME${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            "$script_path" status
            ;;
            
        "list")
            _print_header
            echo -e "${BOLD}${CYAN}📋 VERSIONS DISPONIBLES${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            "$script_path" list
            ;;
            
        "packages")
            _print_header
            echo -e "${BOLD}${CYAN}📦 PACKAGES - ${YELLOW}$2${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            "$script_path" packages "$2"
            ;;
            
        "clean")
            _print_header
            echo -e "${BOLD}${CYAN}🧹 NETTOYAGE SYSTÈME${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            _loading_animation "Suppression des fichiers .DS_Store..."
            "$script_path" clean
            ;;
            
        "help")
            "$script_path" help
            ;;
            
        "")
            # Aide personnalisée ultra-fancy
            _print_header
            echo -e "${BOLD}${CYAN}📖 GUIDE D'UTILISATION${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e ""
            echo -e "${BOLD}${GREEN}🎯 COMMANDES PRINCIPALES${RESET}"
            echo -e "  ${BOLD}switch lazy|perso${RESET}    → Bascule entre configurations"
            echo -e "  ${BOLD}lazy${RESET}                 → $(_get_profile_info "lazy")"
            echo -e "  ${BOLD}perso${RESET}                → $(_get_profile_info "perso")"
            echo -e ""
            echo -e "${BOLD}${GREEN}📊 GESTION & INFORMATION${RESET}"
            echo -e "  ${BOLD}status${RESET}               → ${CYAN}📊 Affiche le statut actuel${RESET}"
            echo -e "  ${BOLD}list${RESET}                 → ${CYAN}📋 Liste les versions disponibles${RESET}"
            echo -e "  ${BOLD}packages <version>${RESET}   → ${CYAN}📦 Liste les packages d'une version${RESET}"
            echo -e "  ${BOLD}clean${RESET}                → ${CYAN}🧹 Nettoie les fichiers .DS_Store${RESET}"
            echo -e "  ${BOLD}help${RESET}                 → ${CYAN}📖 Affiche l'aide complète${RESET}"
            echo -e ""
            echo -e "${BOLD}${GREEN}⚡ RACCOURCIS ULTRA-RAPIDES${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "  ${BOLD}${YELLOW}dvl${RESET}  → dotv lazy     ${DIM}(LazyVim en 3 touches)${RESET}"
            echo -e "  ${BOLD}${YELLOW}dvp${RESET}  → dotv perso    ${DIM}(Personal en 3 touches)${RESET}"
            echo -e "  ${BOLD}${YELLOW}dvs${RESET}  → dotv status   ${DIM}(Statut rapide)${RESET}"
            echo -e ""
            echo -e "${BOLD}${GREEN}💡 EXEMPLES D'UTILISATION${RESET}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "  ${CYAN}dotv lazy${RESET}            # Passe en mode développement"
            echo -e "  ${CYAN}dotv perso${RESET}           # Passe en mode personnel"
            echo -e "  ${CYAN}dvs${RESET}                  # Vérifie la config actuelle"
            echo -e "  ${CYAN}dotv packages lazy${RESET}   # Voir les packages LazyVim"
            ;;
            
        *)
            echo -e "${RED}❌ Commande '$1' inconnue${RESET}"
            echo -e "${DIM}Utilisez ${BOLD}dotv help${RESET}${DIM} ou ${BOLD}dotv${RESET}${DIM} pour l'aide${RESET}"
            return 1
            ;;
    esac
}

# Aliases complémentaires avec descriptions fancy
alias dvl="dotv lazy"           # 🚀 LazyVim config
alias dvp="dotv perso"          # ⚡ Personal config  
alias dvs="dotv status"         # 📊 Status check

########################################################
#                 🎉 FANCY SWITCHER                    #
# Configuration terminée avec style !                 #
########################################################
