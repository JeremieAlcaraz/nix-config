#!/usr/bin/env bash
set -euo pipefail

# Script de gestion des secrets sops-nix
# Usage: ./manage-secrets.sh [magnolia|mimosa|whitelily]
#
# Ce script permet de :
# - Créer des secrets pour un host
# - Régénérer des secrets existants
# - Chiffrer les secrets avec sops-nix
#
# NOTE: Ce script doit être exécuté depuis la racine du repo nix-config

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# AUTO-INSTALLATION DES DÉPENDANCES
# ============================================================================

# Détection de l'OS (défini tôt car nécessaire pour l'auto-install)
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# Fonction pour vérifier si toutes les dépendances sont présentes
check_dependencies_available() {
    local os=$(detect_os)
    local missing=()

    for cmd in sops age openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ "$os" == "linux" ]] && ! command -v mkpasswd &>/dev/null; then
        missing+=("mkpasswd")
    fi

    [[ ${#missing[@]} -eq 0 ]]
}

# Auto-installation : vérifier et guider l'utilisateur
if ! check_dependencies_available; then
    os=$(detect_os)

    echo ""
    echo -e "${RED}❌ Dépendances manquantes${NC}"
    echo ""

    if [[ "$os" == "linux" ]]; then
        echo -e "${YELLOW}Pour installer automatiquement les dépendances, lancez :${NC}"
        echo ""
        echo -e "${GREEN}  nix-shell -p sops age openssl mkpasswd --run \"bash $0 $*\"${NC}"
        echo ""
        echo -e "${BLUE}Ou entrez dans un shell avec les dépendances :${NC}"
        echo -e "${GREEN}  nix-shell -p sops age openssl mkpasswd${NC}"
        echo -e "${GREEN}  bash $0 $*${NC}"
    else
        echo -e "${YELLOW}Sur macOS, installez avec Homebrew :${NC}"
        echo -e "${GREEN}  brew install sops age${NC}"
    fi
    echo ""
    exit 1
fi

# ============================================================================
# GESTION DES PERMISSIONS
# ============================================================================

# Vérifier si on peut écrire dans le répertoire secrets
check_write_permissions() {
    local test_file="secrets/.write_test_$$"

    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        return 0
    else
        return 1
    fi
}

# Si on ne peut pas écrire et qu'on n'est pas déjà root, relancer avec sudo
if [[ -d "secrets" ]] && ! check_write_permissions && [[ $EUID -ne 0 ]] && [[ -z "${SUDO_WRAPPED:-}" ]]; then
    echo -e "${YELLOW}⚙️  Permissions requises pour écrire dans secrets/. Relancement avec sudo...${NC}"
    echo ""
    export SUDO_WRAPPED=1
    exec sudo -E bash "$0" "$@"
fi

error() {
    echo -e "${RED}❌ ERREUR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

prompt() {
    echo -e "${YELLOW}❓ $1${NC}"
}

# Fonction pour générer un hash de mot de passe compatible multi-OS
generate_password_hash() {
    local os=$(detect_os)

    if [[ "$os" == "macos" ]]; then
        # Sur macOS, utiliser openssl passwd avec SHA-512
        openssl passwd -6
    else
        # Sur Linux, utiliser mkpasswd
        mkpasswd -m sha-512
    fi
}

# Fonction sed compatible multi-OS
sed_inplace() {
    local pattern="$1"
    local file="$2"
    local os=$(detect_os)

    if [[ "$os" == "macos" ]]; then
        # Sur macOS (BSD sed), -i nécessite un argument
        sed -i '' "$pattern" "$file"
    else
        # Sur Linux (GNU sed)
        sed -i "$pattern" "$file"
    fi
}

# Vérifications initiales
check_requirements() {
    local missing=()
    local os=$(detect_os)

    # Commandes communes à tous les OS
    for cmd in sops age openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # mkpasswd seulement sur Linux (macOS utilise openssl)
    if [[ "$os" == "linux" ]] && ! command -v mkpasswd &>/dev/null; then
        missing+=("mkpasswd")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ "$os" == "macos" ]]; then
            error "Commandes manquantes: ${missing[*]}\nInstallez avec: brew install sops age"
        else
            error "Commandes manquantes: ${missing[*]}\nInstallez-les avec: nix-shell -p sops age openssl mkpasswd"
        fi
    fi

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f ".sops.yaml" ]]; then
        error "Fichier .sops.yaml non trouvé. Exécutez ce script depuis la racine du repo nix-config"
    fi

    # Vérifier que le répertoire secrets existe
    if [[ ! -d "secrets" ]]; then
        error "Répertoire 'secrets' non trouvé"
    fi
}

# Vérifier la clé age
check_age_key() {
    local os=$(detect_os)
    local age_key_file

    # Chemins différents selon l'OS
    if [[ "$os" == "macos" ]]; then
        age_key_file="$HOME/.config/sops/age/keys.txt"
    else
        age_key_file="/var/lib/sops-nix/key.txt"
    fi

    # Vérifier si la clé existe déjà
    if [[ -f "$age_key_file" ]]; then
        info "Clé age trouvée : $age_key_file"
        export SOPS_AGE_KEY_FILE="$age_key_file"
        return 0
    fi

    # La clé n'existe pas, proposer de la créer
    warning "Clé age sops non trouvée à ${age_key_file}"
    echo ""
    prompt "Voulez-vous fournir votre clé age ? (oui/non):"
    read -r provide_key

    if [[ "$provide_key" == "oui" ]]; then
        echo ""
        info "Collez votre clé age (format: AGE-SECRET-KEY-1...)"
        info "La clé ne sera PAS affichée pour des raisons de sécurité"
        echo ""
        prompt "Clé age :"
        read -rs AGE_KEY
        echo ""

        if [[ -n "$AGE_KEY" ]]; then
            # Créer le répertoire parent
            local key_dir=$(dirname "$age_key_file")
            if [[ "$os" == "macos" ]]; then
                mkdir -p "$key_dir"
                echo "$AGE_KEY" > "$age_key_file"
                chmod 600 "$age_key_file"
            else
                sudo mkdir -p "$key_dir"
                echo "$AGE_KEY" | sudo tee "$age_key_file" >/dev/null
                sudo chmod 600 "$age_key_file"
            fi

            if grep -q "AGE-SECRET-KEY-1" "$age_key_file"; then
                info "Clé age configurée avec succès"
            else
                error "Format de clé invalide"
            fi
        else
            error "Aucune clé fournie"
        fi
    else
        error "Clé age requise pour chiffrer les secrets"
    fi

    export SOPS_AGE_KEY_FILE="$age_key_file"
}

# Parser tous les secrets existants pour magnolia
parse_existing_magnolia_secrets() {
    local secrets_file="$1"

    # Déchiffrer le fichier
    local decrypted=$(sops -d "$secrets_file")

    # Extraire chaque secret
    EXISTING_JEREMIE_HASH=$(echo "$decrypted" | grep "jeremie-password-hash:" | sed 's/jeremie-password-hash: //')
}

# Générer les secrets pour magnolia
generate_magnolia_secrets() {
    local secrets_file="$1"
    local update_mode="${2:-full}"
    local secret_to_update="${3:-}"

    info "Configuration pour magnolia (infrastructure Proxmox)"
    echo ""

    # Si mode selective, charger les secrets existants
    if [[ "$update_mode" == "selective" ]]; then
        parse_existing_magnolia_secrets "secrets/magnolia.yaml"
    fi

    # Mot de passe jeremie
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "jeremie_password" ]]; then
        prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
        JEREMIE_HASH=$(generate_password_hash)
    else
        JEREMIE_HASH="$EXISTING_JEREMIE_HASH"
        info "Réutilisation du mot de passe jeremie existant"
    fi

    cat > "$secrets_file" <<EOF
# Secrets pour magnolia (infrastructure Proxmox)
# Généré par manage-secrets.sh le $(date '+%Y-%m-%d %H:%M:%S')

jeremie-password-hash: ${JEREMIE_HASH}
EOF
}

# Parser tous les secrets existants pour mimosa
parse_existing_mimosa_secrets() {
    local secrets_file="$1"

    # Déchiffrer le fichier
    local decrypted=$(sops -d "$secrets_file")

    # Extraire chaque secret
    EXISTING_JEREMIE_HASH=$(echo "$decrypted" | grep "jeremie-password-hash:" | sed 's/jeremie-password-hash: //')
    EXISTING_CF_TOKEN=$(echo "$decrypted" | grep "cloudflare-tunnel-token:" | sed 's/.*cloudflare-tunnel-token: "//' | sed 's/".*//')
}

# Générer les secrets pour mimosa
generate_mimosa_secrets() {
    local secrets_file="$1"
    local update_mode="${2:-full}"
    local secret_to_update="${3:-}"

    info "Configuration pour mimosa (serveur web)"
    echo ""

    # Si mode selective, charger les secrets existants
    if [[ "$update_mode" == "selective" ]]; then
        parse_existing_mimosa_secrets "secrets/mimosa.yaml"
    fi

    # Mot de passe jeremie
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "jeremie_password" ]]; then
        prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
        JEREMIE_HASH=$(generate_password_hash)
    else
        JEREMIE_HASH="$EXISTING_JEREMIE_HASH"
        info "Réutilisation du mot de passe jeremie existant"
    fi

    # Token Cloudflare
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "cloudflare_token" ]]; then
        echo ""
        info "Configuration Cloudflare Tunnel"
        echo "1. Allez sur https://one.dash.cloudflare.com/"
        echo "2. Zero Trust → Access → Tunnels"
        echo "3. Créez un tunnel (ou utilisez un existant)"
        echo "4. Copiez le TOKEN (la longue chaîne après --token)"
        echo ""
        prompt "Collez le token Cloudflare Tunnel :"
        read -r CF_TOKEN

        if [[ -z "$CF_TOKEN" ]]; then
            error "Le token Cloudflare ne peut pas être vide"
        fi
    else
        CF_TOKEN="$EXISTING_CF_TOKEN"
        info "Réutilisation du token Cloudflare existant"
    fi

    cat > "$secrets_file" <<EOF
# Secrets pour mimosa (serveur web)
# Généré par manage-secrets.sh le $(date '+%Y-%m-%d %H:%M:%S')

jeremie-password-hash: ${JEREMIE_HASH}

cloudflare-tunnel-token: "${CF_TOKEN}"
EOF
}

# Déchiffrer et extraire un secret existant
extract_existing_secret() {
    local secrets_file="$1"
    local key_path="$2"

    # Déchiffrer et extraire la valeur
    sops -d "$secrets_file" | grep -A100 "$key_path" | head -1 | sed 's/.*: //' | sed 's/"//g'
}

# Parser tous les secrets existants pour whitelily
parse_existing_whitelily_secrets() {
    local secrets_file="$1"

    # Déchiffrer le fichier
    local decrypted=$(sops -d "$secrets_file")

    # Extraire chaque secret
    EXISTING_JEREMIE_HASH=$(echo "$decrypted" | grep "jeremie-password-hash:" | sed 's/jeremie-password-hash: //')
    EXISTING_N8N_ENCRYPTION=$(echo "$decrypted" | grep "encryption_key:" | sed 's/.*encryption_key: "//' | sed 's/".*//')
    EXISTING_N8N_USER=$(echo "$decrypted" | grep "basic_user:" | sed 's/.*basic_user: "//' | sed 's/".*//')
    EXISTING_N8N_PASS=$(echo "$decrypted" | grep "basic_pass:" | sed 's/.*basic_pass: "//' | sed 's/".*//')
    EXISTING_DB_PASS=$(echo "$decrypted" | grep "db_password:" | sed 's/.*db_password: "//' | sed 's/".*//')
    EXISTING_CF_TOKEN=$(echo "$decrypted" | grep "cloudflared:" -A1 | grep "token:" | sed 's/.*token: "//' | sed 's/".*//')
    EXISTING_GH_TOKEN=$(echo "$decrypted" | grep "github:" -A1 | grep "token:" | sed 's/.*token: "//' | sed 's/".*//')
}

# Générer les secrets pour whitelily
generate_whitelily_secrets() {
    local secrets_file="$1"
    local update_mode="${2:-full}"  # full ou selective
    local secret_to_update="${3:-}"

    info "Configuration pour whitelily (n8n automation)"
    echo ""

    # Si mode selective, charger les secrets existants
    if [[ "$update_mode" == "selective" ]]; then
        parse_existing_whitelily_secrets "secrets/whitelily.yaml"
    fi

    # Mot de passe jeremie
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "jeremie_password" ]]; then
        prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
        JEREMIE_HASH=$(generate_password_hash)
    else
        JEREMIE_HASH="$EXISTING_JEREMIE_HASH"
        info "Réutilisation du mot de passe jeremie existant"
    fi

    # Génération automatique des secrets n8n
    echo ""

    # N8N Encryption Key
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "n8n_encryption" ]]; then
        info "Génération de la clé de chiffrement n8n..."
        N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
        warning "⚠️  IMPORTANT : Clé de chiffrement n8n"
        echo "Cette clé chiffre TOUTES vos credentials n8n."
        echo -e "${YELLOW}N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}${NC}"
        echo "Sauvegardez-la dans un gestionnaire de mots de passe !"
        echo ""
        read -p "Appuyez sur Entrée une fois sauvegardée..."
    else
        N8N_ENCRYPTION_KEY="$EXISTING_N8N_ENCRYPTION"
        info "Réutilisation de la clé de chiffrement n8n existante"
    fi

    # N8N User
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "n8n_user" ]]; then
        echo ""
        prompt "Nom d'utilisateur pour n8n (défaut: admin):"
        read -r N8N_USER
        N8N_USER="${N8N_USER:-admin}"
    else
        N8N_USER="$EXISTING_N8N_USER"
        info "Réutilisation du nom d'utilisateur n8n existant: $N8N_USER"
    fi

    # N8N Password
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "n8n_password" ]]; then
        echo ""
        info "Génération du mot de passe n8n..."
        N8N_BASIC_PASS=$(openssl rand -base64 24)
        echo "Nouveau mot de passe n8n: ${N8N_BASIC_PASS}"
    else
        N8N_BASIC_PASS="$EXISTING_N8N_PASS"
        info "Réutilisation du mot de passe n8n existant"
    fi

    # DB Password
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "db_password" ]]; then
        echo ""
        info "Génération du mot de passe DB PostgreSQL..."
        DB_PASSWORD=$(openssl rand -base64 32)
        echo "Nouveau mot de passe DB: ${DB_PASSWORD}"
    else
        DB_PASSWORD="$EXISTING_DB_PASS"
        info "Réutilisation du mot de passe DB existant"
    fi

    # Domaine (toujours demander ou réutiliser)
    if [[ "$update_mode" == "full" ]]; then
        echo ""
        prompt "Domaine complet pour n8n (ex: n8n.votredomaine.com):"
        read -r DOMAIN
        [[ -z "$DOMAIN" ]] && error "Le domaine ne peut pas être vide"
    else
        # Tenter de récupérer le domaine depuis n8n.nix
        if [[ -f "hosts/whitelily/n8n.nix" ]]; then
            DOMAIN=$(grep 'domain = ' hosts/whitelily/n8n.nix | head -1 | sed 's/.*domain = "//' | sed 's/".*//')
            info "Réutilisation du domaine existant: $DOMAIN"
        else
            prompt "Domaine complet pour n8n (ex: n8n.votredomaine.com):"
            read -r DOMAIN
            [[ -z "$DOMAIN" ]] && error "Le domaine ne peut pas être vide"
        fi
    fi

    # Cloudflare Token
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "cloudflare_token" ]]; then
        echo ""
        info "Configuration Cloudflare Tunnel"
        echo "1. Allez sur https://one.dash.cloudflare.com/"
        echo "2. Zero Trust → Access → Tunnels"
        echo "3. Créez un tunnel (ou utilisez un existant)"
        echo "4. Configurez la route publique :"
        echo "   - Public Hostname: ${DOMAIN}"
        echo "   - Service: http://localhost:80"
        echo "5. Copiez le TOKEN du tunnel (la longue chaîne qui commence par 'eyJ...')"
        echo ""
        prompt "Collez le token Cloudflare Tunnel :"
        read -r CLOUDFLARED_TOKEN

        if [[ -z "$CLOUDFLARED_TOKEN" ]]; then
            error "Le token Cloudflare ne peut pas être vide"
        fi
    else
        CLOUDFLARED_TOKEN="$EXISTING_CF_TOKEN"
        info "Réutilisation du token Cloudflare existant"
    fi

    # Token GitHub pour auto-update
    if [[ "$update_mode" == "full" ]] || [[ "$secret_to_update" == "github_token" ]]; then
        echo ""
        info "Configuration GitHub (pour mises à jour automatiques de n8n)"
        echo "Le token GitHub permet au workflow d'automatiser les mises à jour de n8n:next."
        echo ""
        echo "📚 Documentation complète : docs/GITHUB-TOKEN-SETUP.md"
        echo ""
        echo "Résumé rapide :"
        echo "1. Aller sur https://github.com/settings/tokens/new"
        echo "2. Note: 'n8n auto-update workflow'"
        echo "3. Expiration: 'No expiration' ou 1 an"
        echo "4. Scope: ✅ repo (cocher TOUT le scope 'repo')"
        echo "5. Generate token"
        echo "6. Copier le token (commence par 'ghp_...')"
        echo ""
        prompt "Voulez-vous configurer l'auto-update GitHub ? (oui/non, défaut: non):"
        read -r setup_github
        setup_github="${setup_github:-non}"

        if [[ "$setup_github" == "oui" ]]; then
            prompt "Collez le token GitHub (ghp_...) :"
            read -r GITHUB_TOKEN

            if [[ -z "$GITHUB_TOKEN" ]]; then
                warning "Token GitHub non fourni - fonctionnalité d'auto-update désactivée"
                GITHUB_TOKEN="PLACEHOLDER_GITHUB_TOKEN_DISABLED"
            elif [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
                warning "Le token ne commence pas par 'ghp_' - vérifiez qu'il s'agit d'un Personal Access Token"
                prompt "Voulez-vous continuer quand même ? (oui/non):"
                read -r continue_anyway
                if [[ "$continue_anyway" != "oui" ]]; then
                    GITHUB_TOKEN="PLACEHOLDER_GITHUB_TOKEN_DISABLED"
                fi
            fi

            echo ""
            warning "⚠️  N'oubliez pas d'ajouter ce token dans GitHub Secrets !"
            echo "Allez dans Settings → Secrets and variables → Actions → New repository secret"
            echo "  - Name: N8N_UPDATE_TOKEN"
            echo "  - Value: ${GITHUB_TOKEN}"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
        else
            warning "Auto-update GitHub non configuré"
            echo "Vous pourrez l'ajouter plus tard avec: sops secrets/whitelily.yaml"
            GITHUB_TOKEN="PLACEHOLDER_GITHUB_TOKEN_DISABLED"
        fi
    else
        GITHUB_TOKEN="$EXISTING_GH_TOKEN"
        if [[ "$GITHUB_TOKEN" == "PLACEHOLDER_GITHUB_TOKEN_DISABLED" ]]; then
            info "Auto-update GitHub non configuré précédemment"
        else
            info "Réutilisation du token GitHub existant"
        fi
    fi

    cat > "$secrets_file" <<EOF
# Secrets pour whitelily (VM n8n automation)
# Généré par manage-secrets.sh le $(date '+%Y-%m-%d %H:%M:%S')

jeremie-password-hash: ${JEREMIE_HASH}

n8n:
  encryption_key: "${N8N_ENCRYPTION_KEY}"
  basic_user: "${N8N_USER}"
  basic_pass: "${N8N_BASIC_PASS}"
  db_password: "${DB_PASSWORD}"

cloudflared:
  token: "${CLOUDFLARED_TOKEN}"

github:
  token: "${GITHUB_TOKEN}"
EOF

    # Sauvegarder le domaine pour référence
    echo "$DOMAIN" > /tmp/whitelily-domain.txt

    info "Résumé de la configuration n8n :"
    echo "  • Domaine          : ${DOMAIN}"
    echo "  • Utilisateur      : ${N8N_USER}"
    echo "  • Mot de passe     : ${N8N_BASIC_PASS}"
    echo "  • Clé chiffrement  : ${N8N_ENCRYPTION_KEY}"
    echo ""
    warning "Sauvegardez ces informations !"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."

    # Mettre à jour le domaine dans n8n.nix si le fichier existe
    if [[ -f "hosts/whitelily/n8n.nix" ]]; then
        echo ""
        prompt "Voulez-vous mettre à jour le domaine dans hosts/whitelily/n8n.nix ? (oui/non, défaut: oui):"
        read -r update_domain
        update_domain="${update_domain:-oui}"

        if [[ "$update_domain" == "oui" ]]; then
            sed_inplace "s|domain = \".*\";|domain = \"${DOMAIN}\";|" "hosts/whitelily/n8n.nix"
            info "Domaine mis à jour dans n8n.nix : ${DOMAIN}"
        fi
    fi
}

# Chiffrer les secrets avec sops
encrypt_secrets() {
    local secrets_file="$1"
    local host="$2"

    step "Chiffrement des secrets avec sops"

    # Vérifier que le fichier existe
    if [[ ! -f "$secrets_file" ]]; then
        error "Fichier de secrets non trouvé : $secrets_file"
    fi

    # Chiffrer in-place
    info "Chiffrement en cours..."
    sops -e -i "$secrets_file"

    # Vérifier que c'est bien chiffré
    if grep -q "sops:" "$secrets_file"; then
        info "Secrets chiffrés avec succès"
        echo ""
        info "Fichier de secrets : $secrets_file"
    else
        error "Échec du chiffrement des secrets"
    fi
}

# Menu principal
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🔐 Gestion des secrets sops-nix               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Vérifications
    check_requirements
    check_age_key

    # Récupérer l'host ou afficher le menu
    HOST="${1:-}"

    if [[ -z "$HOST" ]]; then
        echo -e "${BLUE}Hosts disponibles :${NC}"
        echo ""
        echo -e "${GREEN}1)${NC} ${YELLOW}magnolia${NC} - Infrastructure Proxmox"
        echo -e "${GREEN}2)${NC} ${YELLOW}mimosa${NC}    - Serveur web (j12zdotcom)"
        echo -e "${GREEN}3)${NC} ${YELLOW}whitelily${NC} - n8n automation"
        echo ""
        prompt "Choisissez un host (1-3) :"
        read -r choice

        case "$choice" in
            1) HOST="magnolia" ;;
            2) HOST="mimosa" ;;
            3) HOST="whitelily" ;;
            *) error "Choix invalide. Utilisez 1, 2 ou 3" ;;
        esac

        info "Host sélectionné : ${HOST}"
        echo ""
    fi

    # Vérifier que l'host est valide
    if [[ "$HOST" != "magnolia" && "$HOST" != "mimosa" && "$HOST" != "whitelily" ]]; then
        error "Host invalide. Utilisez 'magnolia', 'mimosa' ou 'whitelily'"
    fi

    # Définir le chemin du fichier de secrets
    SECRETS_FILE="secrets/${HOST}.yaml"

    # Variables pour le mode de mise à jour
    UPDATE_MODE="full"
    SECRET_TO_UPDATE=""

    # Vérifier si les secrets existent déjà
    if [[ -f "$SECRETS_FILE" ]] && grep -q "sops:" "$SECRETS_FILE" 2>/dev/null; then
        echo ""
        warning "Secrets existants trouvés pour ${HOST}"
        info "Fichier: $SECRETS_FILE"
        echo ""
        echo -e "${BLUE}Que souhaitez-vous faire ?${NC}"
        echo ""
        echo -e "${GREEN}1)${NC} Régénérer ${RED}TOUS${NC} les secrets (⚠️  perte des secrets existants)"
        echo -e "${GREEN}2)${NC} Régénérer ${YELLOW}UN SEUL${NC} secret (les autres sont conservés)"
        echo -e "${GREEN}3)${NC} Annuler"
        echo ""
        prompt "Votre choix (1-3) :"
        read -r regenerate_choice

        case "$regenerate_choice" in
            1)
                info "Régénération complète de tous les secrets"
                UPDATE_MODE="full"
                # Sauvegarder l'ancien fichier
                backup_file="${SECRETS_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
                cp "$SECRETS_FILE" "$backup_file"
                info "Anciens secrets sauvegardés : $backup_file"
                ;;
            2)
                info "Régénération sélective d'un secret"
                UPDATE_MODE="selective"

                # Menu spécifique selon l'host
                echo ""
                echo -e "${BLUE}Quel secret souhaitez-vous changer pour ${HOST} ?${NC}"
                echo ""

                if [[ "$HOST" == "whitelily" ]]; then
                    echo -e "${GREEN}1)${NC} Mot de passe utilisateur jeremie (SSH)"
                    echo -e "${GREEN}2)${NC} Clé de chiffrement n8n (${RED}⚠️  CRITIQUE${NC})"
                    echo -e "${GREEN}3)${NC} Nom d'utilisateur n8n (basic auth)"
                    echo -e "${GREEN}4)${NC} Mot de passe n8n (basic auth)"
                    echo -e "${GREEN}5)${NC} Mot de passe base de données PostgreSQL"
                    echo -e "${GREEN}6)${NC} Token Cloudflare Tunnel"
                    echo -e "${GREEN}7)${NC} Token GitHub (auto-update)"
                    echo ""
                    prompt "Votre choix (1-7) :"
                    read -r secret_choice

                    case "$secret_choice" in
                        1) SECRET_TO_UPDATE="jeremie_password" ;;
                        2)
                            warning "⚠️  Attention : changer la clé de chiffrement n8n rendra TOUTES vos credentials n8n inaccessibles !"
                            prompt "Êtes-vous sûr de vouloir continuer ? (oui/non) :"
                            read -r confirm
                            if [[ "$confirm" == "oui" ]]; then
                                SECRET_TO_UPDATE="n8n_encryption"
                            else
                                info "Opération annulée"
                                exit 0
                            fi
                            ;;
                        3) SECRET_TO_UPDATE="n8n_user" ;;
                        4) SECRET_TO_UPDATE="n8n_password" ;;
                        5) SECRET_TO_UPDATE="db_password" ;;
                        6) SECRET_TO_UPDATE="cloudflare_token" ;;
                        7) SECRET_TO_UPDATE="github_token" ;;
                        *) error "Choix invalide" ;;
                    esac
                elif [[ "$HOST" == "mimosa" ]]; then
                    echo -e "${GREEN}1)${NC} Mot de passe utilisateur jeremie (SSH)"
                    echo -e "${GREEN}2)${NC} Token Cloudflare Tunnel"
                    echo ""
                    prompt "Votre choix (1-2) :"
                    read -r secret_choice

                    case "$secret_choice" in
                        1) SECRET_TO_UPDATE="jeremie_password" ;;
                        2) SECRET_TO_UPDATE="cloudflare_token" ;;
                        *) error "Choix invalide" ;;
                    esac
                elif [[ "$HOST" == "magnolia" ]]; then
                    echo -e "${GREEN}1)${NC} Mot de passe utilisateur jeremie (SSH)"
                    echo ""
                    prompt "Votre choix (1) :"
                    read -r secret_choice

                    case "$secret_choice" in
                        1) SECRET_TO_UPDATE="jeremie_password" ;;
                        *) error "Choix invalide" ;;
                    esac
                fi

                info "Secret sélectionné pour mise à jour : $SECRET_TO_UPDATE"

                # Sauvegarder l'ancien fichier
                backup_file="${SECRETS_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
                cp "$SECRETS_FILE" "$backup_file"
                info "Anciens secrets sauvegardés : $backup_file"
                ;;
            3)
                info "Opération annulée"
                exit 0
                ;;
            *)
                error "Choix invalide. Utilisez 1, 2 ou 3"
                ;;
        esac
    fi

    step "Génération des secrets pour ${HOST}"

    # Créer un fichier temporaire
    temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT

    # Générer les secrets selon l'host
    case "$HOST" in
        magnolia)
            generate_magnolia_secrets "$temp_file" "$UPDATE_MODE" "$SECRET_TO_UPDATE"
            ;;
        mimosa)
            generate_mimosa_secrets "$temp_file" "$UPDATE_MODE" "$SECRET_TO_UPDATE"
            ;;
        whitelily)
            generate_whitelily_secrets "$temp_file" "$UPDATE_MODE" "$SECRET_TO_UPDATE"
            ;;
    esac

    # Copier le fichier temporaire vers le fichier final
    cp "$temp_file" "$SECRETS_FILE"
    info "Secrets générés"

    # Chiffrer les secrets
    encrypt_secrets "$SECRETS_FILE" "$HOST"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🎉 Secrets créés et chiffrés avec succès !    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    info "Prochaines étapes :"
    echo "1. Vérifiez le fichier : $SECRETS_FILE"
    echo "2. Commitez les changements : git add secrets/${HOST}.yaml && git commit"
    echo "3. Déployez sur l'host : nixos-rebuild switch --flake .#${HOST}"
    echo ""
}

main "$@"
