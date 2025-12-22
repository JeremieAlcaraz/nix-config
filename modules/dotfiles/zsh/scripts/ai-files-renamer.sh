#!/bin/bash

# Configuration
VERSION="2.1.0"
DEFAULT_FOLDER="/Users/jeremiealcaraz/Desktop/2.Pending/for_renamer_ai"

# Couleurs et emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Fonction d'affichage du header
show_header() {
  echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${WHITE}      🤖 AI RENAMER PRO v${VERSION} 🤖      ${BLUE}║${NC}"
  echo -e "${BLUE}║${CYAN}        Renommage intelligent avec Ollama        ${BLUE}║${NC}"
  echo -e "${BLUE}║${PURPLE}              100% Local et Gratuit              ${BLUE}║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
  echo
}

# Fonction d'aide
show_help() {
  show_header
  echo -e "${CYAN}📖 UTILISATION:${NC}"
  echo -e "${WHITE}  $0${NC}                    Mode normal (Ollama)"
  echo -e "${WHITE}  $0 -f <dossier>${NC}        Dossier personnalisé"
  echo -e "${WHITE}  $0 -m <modèle>${NC}         Modèle personnalisé"
  echo -e "${WHITE}  $0 --openai${NC}            Force OpenAI (si vous voulez réessayer)"
  echo -e "${WHITE}  $0 --help${NC}              Affiche cette aide"
  echo
  echo -e "${CYAN}🤖 MODÈLES OLLAMA OPTIMISÉS M2:${NC}"
  echo -e "${WHITE}  • llava:7b${NC}      (Défaut - Parfait pour M2, 4.5GB)"
  echo -e "${WHITE}  • llava:13b${NC}     (Plus puissant - Si 16GB+ RAM)"
  echo -e "${WHITE}  • llava:34b${NC}     (Maximum - Si 24GB+ RAM)"
  echo -e "${WHITE}  • llama3:8b${NC}     (Texte uniquement - 4.7GB)"
  echo
  echo -e "${CYAN}📁 EXEMPLES:${NC}"
  echo -e "${WHITE}  $0 -f ~/Documents${NC}"
  echo -e "${WHITE}  $0 -f ~/Pictures -m llava:13b${NC}"
  echo -e "${WHITE}  $0 --openai -f ~/Desktop${NC}"
  echo
}

# Fonction de validation du modèle Ollama
validate_ollama_model() {
  local model="$1"
  case "$model" in
  "llava:7b" | "llava:13b" | "llava:34b" | "llama3:8b" | "llama3:70b")
    echo "$model"
    ;;
  *)
    echo -e "${RED}❌ Modèle Ollama invalide: $model${NC}" >&2
    echo -e "${YELLOW}💡 Modèles disponibles: llava:7b, llava:13b, llava:34b, llama3:8b${NC}" >&2
    exit 1
    ;;
  esac
}

# Fonction de validation du modèle OpenAI
validate_openai_model() {
  local model="$1"
  case "$model" in
  "gpt-4o" | "gpt-4o-mini" | "gpt-4-turbo" | "gpt-4")
    echo "$model"
    ;;
  *)
    echo -e "${RED}❌ Modèle OpenAI invalide: $model${NC}" >&2
    echo -e "${YELLOW}💡 Modèles disponibles: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-4${NC}" >&2
    exit 1
    ;;
  esac
}

# Fonction de vérification du dossier
validate_folder() {
  local folder="$1"

  # Expansion du tilde
  folder="${folder/#\~/$HOME}"

  if [ ! -d "$folder" ]; then
    echo -e "${RED}❌ Dossier introuvable: $folder${NC}" >&2
    exit 1
  fi

  local file_count
  file_count=$(find "$folder" -maxdepth 1 -type f ! -name ".*" ! -name "Thumbs.db" ! -name "desktop.ini" | wc -l)

  if [ "$file_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Aucun fichier valide trouvé dans: $folder${NC}" >&2
    echo -e "${YELLOW}💡 (Les fichiers système comme .DS_Store sont ignorés)${NC}" >&2
    exit 1
  fi

  echo "$folder"
}

# Fonction de vérification d'Ollama
check_ollama() {
  echo -e "${YELLOW}🔍 Vérification d'Ollama...${NC}"

  if ! command -v ollama >/dev/null 2>&1; then
    echo -e "${RED}❌ Ollama non installé${NC}" >&2
    echo -e "${YELLOW}💡 Installez avec: brew install ollama${NC}" >&2
    exit 1
  fi

  # Vérification qu'Ollama tourne
  if ! ollama list >/dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Démarrage d'Ollama...${NC}"
    ollama serve &
    sleep 3
  fi

  echo -e "${GREEN}✅ Ollama OK${NC}"
}

# Fonction de vérification du modèle Ollama
check_ollama_model() {
  local model="$1"

  echo -e "${YELLOW}🔍 Vérification du modèle $model...${NC}"

  if ! ollama list | grep -q "$model"; then
    echo -e "${YELLOW}📥 Installation du modèle $model...${NC}"
    echo -e "${BLUE}💡 Cela peut prendre quelques minutes la première fois${NC}"
    ollama pull "$model"
  fi

  echo -e "${GREEN}✅ Modèle $model prêt${NC}"
}

# Fonction de récupération de la clé OpenAI (si nécessaire)
get_openai_key() {
  echo -e "${YELLOW}🔑 Récupération de la clé OpenAI depuis 1Password...${NC}"

  if ! command -v op >/dev/null 2>&1; then
    echo -e "${RED}❌ 1Password CLI non installé${NC}" >&2
    exit 1
  fi

  if ! op account list >/dev/null 2>&1; then
    echo -e "${YELLOW}🔐 Authentification 1Password requise...${NC}"
    op signin
  fi

  local key
  key=$(op item get "openai-renamer-ai" --field "credential" --reveal | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$key" ]; then
    echo -e "${RED}❌ Impossible de récupérer la clé OpenAI${NC}" >&2
    exit 1
  fi

  echo -e "${GREEN}✅ Clé OpenAI récupérée${NC}"
  echo "$key"
}

# Fonction d'affichage du récapitulatif
show_summary() {
  local folder="$1"
  local provider="$2"
  local model="$3"
  local file_count

  file_count=$(find "$folder" -maxdepth 1 -type f ! -name ".*" ! -name "Thumbs.db" ! -name "desktop.ini" | wc -l)

  echo -e "${CYAN}📊 RÉCAPITULATIF:${NC}"
  echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${WHITE} Dossier:    ${NC}$folder"
  echo -e "${BLUE}║${WHITE} Provider:   ${NC}$provider"
  echo -e "${BLUE}║${WHITE} Modèle:     ${NC}$model"
  echo -e "${BLUE}║${WHITE} Fichiers:   ${NC}$file_count fichier(s) valides"
  echo -e "${BLUE}║${WHITE} Format:     ${NC}[TYPE]_[SUJET]_[YYYYMMDD]_[VERSION]"
  echo -e "${BLUE}║${WHITE} Langue:     ${NC}English"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
  echo

  # Aperçu des fichiers
  if [ "$file_count" -gt 0 ]; then
    echo -e "${YELLOW}📋 Aperçu des fichiers à renommer:${NC}"
    find "$folder" -maxdepth 1 -type f ! -name ".*" ! -name "Thumbs.db" ! -name "desktop.ini" -exec basename {} \; | head -5
    if [ "$file_count" -gt 5 ]; then
      echo -e "${YELLOW}   ... et $((file_count - 5)) autres fichiers${NC}"
    fi
    echo

    # Affichage des fichiers ignorés
    local ignored_count
    ignored_count=$(find "$folder" -maxdepth 1 -type f \( -name ".*" -o -name "Thumbs.db" -o -name "desktop.ini" \) | wc -l)
    if [ "$ignored_count" -gt 0 ]; then
      echo -e "${PURPLE}🚫 Fichiers système ignorés: $ignored_count fichier(s)${NC}"
      echo -e "${PURPLE}   (inclut .DS_Store, .Thumbs.db, .desktop.ini, etc.)${NC}"
      echo
    fi
  fi
}

# Fonction principale
main() {
  local folder=""
  local provider="ollama"
  local model="llava:7b"
  local interactive=true

  # Parsing des arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -f | --folder)
      folder="$2"
      interactive=false
      shift 2
      ;;
    -m | --model)
      model="$2"
      shift 2
      ;;
    --openai)
      provider="openai"
      model="gpt-4o"
      shift
      ;;
    --help | -h)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Option inconnue: $1${NC}" >&2
      echo -e "${YELLOW}💡 Utilisez --help pour voir les options disponibles${NC}" >&2
      exit 1
      ;;
    esac
  done

  show_header

  # Dossier par défaut si non spécifié
  if [ -z "$folder" ]; then
    folder="$DEFAULT_FOLDER"
    echo -e "${CYAN}📁 Utilisation du dossier par défaut${NC}"
  fi

  # Validation du dossier
  folder=$(validate_folder "$folder")

  # Configuration selon le provider
  if [ "$provider" = "ollama" ]; then
    # Configuration Ollama
    model=$(validate_ollama_model "$model")
    check_ollama
    check_ollama_model "$model"

    # Affichage du récapitulatif
    show_summary "$folder" "$provider" "$model"

    # Confirmation si mode interactif
    if [ "$interactive" = true ]; then
      echo -ne "${YELLOW}🚀 Confirmer le renommage avec Ollama ? (Y/n): ${NC}"
      read -r confirm
      if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}❌ Opération annulée${NC}"
        exit 0
      fi
      echo
    fi

    # Prompt SOP
    local prompt="Analyze document content and rename using pattern: [TYPE]_[SUJET]_[YYYYMMDD]_[VERSION] where TYPE is 3-6 chars (pdf, doc, img, data, brief, export, tpl), SUJET is 8-20 chars project theme with dashes, DATE is YYYYMMDD, VERSION is v01/v02/final/draft/corrige. All lowercase, no accents, underscores as separators, max 45 chars total. Follow company SOP exactly: TYPE (3-6 chars like img, pdf, data, doc, brief, export, tpl), SUJET (8-20 chars with dashes for spaces), DATE (YYYYMMDD format), VERSION (v01/v02/final/draft/corrige). Use underscores between blocks, all lowercase, no accents, max 45 chars total. Analyze content to determine appropriate TYPE and descriptive SUJET."

    echo -e "${BLUE}🤖 Lancement d'AI Renamer avec Ollama...${NC}"
    echo -e "${YELLOW}⏳ Traitement en cours (local, pas de limite)...${NC}"
    echo

    # Mesure du temps d'exécution
    local start_time=$(date +%s)

    # Exécution avec Ollama
    if npx ai-renamer@1.0.22 "$folder" \
      --provider=ollama \
      --model="$model" \
      --language=English \
      --chars=45 \
      --custom-prompt="$prompt"; then

      local end_time=$(date +%s)
      local duration=$((end_time - start_time))

      echo
      echo -e "${GREEN}🎉 Renommage terminé avec succès !${NC}"
      echo -e "${BLUE}⏱️  Temps d'exécution: ${duration}s${NC}"
      echo -e "${PURPLE}🤖 Modèle utilisé: $model (Ollama)${NC}"
      echo -e "${CYAN}📁 Dossier traité: $folder${NC}"
      echo
      echo -e "${YELLOW}💡 Vérifiez les résultats dans le dossier${NC}"

    else
      echo
      echo -e "${RED}❌ Erreur lors du renommage${NC}"
      echo -e "${YELLOW}💡 Vérifiez qu'Ollama fonctionne: ollama list${NC}"
      exit 1
    fi

  else
    # Configuration OpenAI (si demandé explicitement)
    model=$(validate_openai_model "$model")
    local openai_key
    openai_key=$(get_openai_key)

    show_summary "$folder" "$provider" "$model"

    if [ "$interactive" = true ]; then
      echo -ne "${YELLOW}🚀 Confirmer le renommage avec OpenAI ? (Y/n): ${NC}"
      read -r confirm
      if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}❌ Opération annulée${NC}"
        exit 0
      fi
      echo
    fi

    local prompt="Analyze document content and rename using pattern: [TYPE]_[SUJET]_[YYYYMMDD]_[VERSION] where TYPE is 3-6 chars (pdf, doc, img, data, brief, export, tpl), SUJET is 8-20 chars project theme with dashes, DATE is YYYYMMDD, VERSION is v01/v02/final/draft/corrige. All lowercase, no accents, underscores as separators, max 45 chars total."

    echo -e "${BLUE}🤖 Lancement d'AI Renamer avec OpenAI...${NC}"
    echo -e "${YELLOW}⏳ Traitement en cours...${NC}"
    echo

    local start_time=$(date +%s)

    if npx ai-renamer@1.0.22 "$folder" \
      --provider=openai \
      --api-key="$openai_key" \
      --model="$model" \
      --language=English \
      --chars=45 \
      --custom-prompt="$prompt"; then

      local end_time=$(date +%s)
      local duration=$((end_time - start_time))

      echo
      echo -e "${GREEN}🎉 Renommage terminé avec succès !${NC}"
      echo -e "${BLUE}⏱️  Temps d'exécution: ${duration}s${NC}"
      echo -e "${PURPLE}🤖 Modèle utilisé: $model (OpenAI)${NC}"
      echo -e "${CYAN}📁 Dossier traité: $folder${NC}"

    else
      echo
      echo -e "${RED}❌ Erreur lors du renommage avec OpenAI${NC}"
      echo -e "${YELLOW}💡 Essayez avec Ollama: $0 -f '$folder'${NC}"
      exit 1
    fi
  fi
}

# Gestion des interruptions
trap 'echo -e "\n${YELLOW}🛑 Interruption détectée. Arrêt...${NC}"; exit 1' INT TERM

# Point d'entrée
main "$@"
