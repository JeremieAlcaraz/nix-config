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

# Vérifications initiales
check_requirements() {
    local missing=()

    # Vérifier les commandes nécessaires
    for cmd in sops age openssl mkpasswd; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Commandes manquantes: ${missing[*]}\nInstallez-les avec: nix-shell -p sops age openssl mkpasswd"
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
    local age_key_file="/var/lib/sops-nix/key.txt"

    if [[ ! -f "$age_key_file" ]]; then
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
                sudo mkdir -p /var/lib/sops-nix
                echo "$AGE_KEY" | sudo tee "$age_key_file" >/dev/null
                sudo chmod 600 "$age_key_file"

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
    fi

    export SOPS_AGE_KEY_FILE="$age_key_file"
}

# Générer les secrets pour magnolia
generate_magnolia_secrets() {
    local secrets_file="$1"

    info "Configuration pour magnolia (infrastructure Proxmox)"
    echo ""

    prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
    JEREMIE_HASH=$(mkpasswd -m sha-512)

    cat > "$secrets_file" <<EOF
# Secrets pour magnolia (infrastructure Proxmox)
# Généré par manage-secrets.sh le $(date '+%Y-%m-%d %H:%M:%S')

jeremie-password-hash: ${JEREMIE_HASH}
EOF
}

# Générer les secrets pour mimosa
generate_mimosa_secrets() {
    local secrets_file="$1"

    info "Configuration pour mimosa (serveur web)"
    echo ""

    # Mot de passe jeremie
    prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
    JEREMIE_HASH=$(mkpasswd -m sha-512)

    # Token Cloudflare
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

    cat > "$secrets_file" <<EOF
# Secrets pour mimosa (serveur web)
# Généré par manage-secrets.sh le $(date '+%Y-%m-%d %H:%M:%S')

jeremie-password-hash: ${JEREMIE_HASH}

cloudflare-tunnel-token: "${CF_TOKEN}"
EOF
}

# Générer les secrets pour whitelily
generate_whitelily_secrets() {
    local secrets_file="$1"

    info "Configuration pour whitelily (n8n automation)"
    echo ""

    # Mot de passe jeremie
    prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
    JEREMIE_HASH=$(mkpasswd -m sha-512)

    # Génération automatique des secrets n8n
    echo ""
    info "Génération des secrets n8n..."
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
    N8N_BASIC_PASS=$(openssl rand -base64 24)
    DB_PASSWORD=$(openssl rand -base64 32)

    warning "⚠️  IMPORTANT : Clé de chiffrement n8n"
    echo "Cette clé chiffre TOUTES vos credentials n8n."
    echo -e "${YELLOW}N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}${NC}"
    echo "Sauvegardez-la dans un gestionnaire de mots de passe !"
    echo ""
    read -p "Appuyez sur Entrée une fois sauvegardée..."

    echo ""
    prompt "Nom d'utilisateur pour n8n (défaut: admin):"
    read -r N8N_USER
    N8N_USER="${N8N_USER:-admin}"

    echo ""
    prompt "Domaine complet pour n8n (ex: n8n.votredomaine.com):"
    read -r DOMAIN
    [[ -z "$DOMAIN" ]] && error "Le domaine ne peut pas être vide"

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
            sed -i "s|domain = \".*\";|domain = \"${DOMAIN}\";|" "hosts/whitelily/n8n.nix"
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

    # Vérifier si les secrets existent déjà
    if [[ -f "$SECRETS_FILE" ]] && grep -q "sops:" "$SECRETS_FILE" 2>/dev/null; then
        echo ""
        warning "Secrets existants trouvés pour ${HOST}"
        info "Fichier: $SECRETS_FILE"
        echo ""
        prompt "Voulez-vous les régénérer ? (oui/non):"
        read -r regenerate

        if [[ "$regenerate" != "oui" ]]; then
            info "Opération annulée"
            exit 0
        fi

        # Sauvegarder l'ancien fichier
        backup_file="${SECRETS_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$SECRETS_FILE" "$backup_file"
        info "Anciens secrets sauvegardés : $backup_file"
    fi

    step "Génération des secrets pour ${HOST}"

    # Créer un fichier temporaire
    temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT

    # Générer les secrets selon l'host
    case "$HOST" in
        magnolia)
            generate_magnolia_secrets "$temp_file"
            ;;
        mimosa)
            generate_mimosa_secrets "$temp_file"
            ;;
        whitelily)
            generate_whitelily_secrets "$temp_file"
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
