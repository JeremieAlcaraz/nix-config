#!/usr/bin/env bash
# Script pour déployer toutes les configurations NixOS sur les machines distantes
#
# Usage:
#   ./scripts/deploy-all.sh       # Déploie sur toutes les machines
#   ./scripts/deploy-all.sh --help # Affiche l'aide

set -euo pipefail

# Configuration
CONFIG_DIR="/etc/nixos"
HOSTS=("mimosa" "whitelily" "dandelion" "hawthorn" "myosotis")
SSH_TIMEOUT=5

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonctions d'affichage
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Déploie toutes les configurations NixOS sur les machines distantes.

Ce script va :
  1. Vérifier la connectivité de chaque machine
  2. Déployer séquentiellement sur mimosa, whitelily, dandelion, hawthorn, myosotis
  3. Skip les machines hors ligne avec un warning
  4. Fail si une machine est accessible mais le déploiement échoue

Le script utilise le cache binaire de magnolia pour des déploiements rapides.

OPTIONS:
    --help         Affiche cette aide

EXAMPLES:
    $0             # Déploie sur toutes les machines accessibles

NOTE:
    - Ce script est conçu pour être exécuté sur magnolia
    - Lance 'ra' avant pour rebuilder et remplir le cache
    - Les machines offline seront skippées automatiquement

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Vérifier qu'on est bien sur magnolia
CURRENT_HOST=$(hostname)
if [[ "$CURRENT_HOST" != "magnolia" ]]; then
    log_warning "Ce script est conçu pour être exécuté sur magnolia"
    log_warning "Host actuel: $CURRENT_HOST"
    read -p "Continuer quand même ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Annulé"
        exit 0
    fi
fi

# Vérifier qu'on est dans le bon dossier
if [[ ! -f "flake.nix" ]]; then
    log_error "flake.nix non trouvé. Es-tu dans /etc/nixos ?"
    exit 1
fi

# Arrays pour tracker les résultats
DEPLOYED=()
SKIPPED=()
FAILED=()

# Début du script
log_header "🚀 Deploy All Configurations"

# Check de connectivité et déploiement
for host in "${HOSTS[@]}"; do
    echo ""
    echo -e "${BLUE}🌐 Checking $host...${NC}"

    # Test de connectivité SSH
    if timeout $SSH_TIMEOUT ssh -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
        log_success "$host is online"

        echo -e "${BLUE}📦 Deploying to $host...${NC}"

        # Déploiement
        # On SSH vers la machine cible et on rebuild localement
        # Cela utilise automatiquement les substituters configurés (magnolia:5000)
        if ssh "$host" bash << 'ENDSSH'
set -euo pipefail
cd /etc/nixos
sudo git fetch origin
sudo git reset --hard origin/main
sudo nixos-rebuild switch --flake ".#$(hostname)"
ENDSSH
        then
            log_success "$host deployed successfully!"
            DEPLOYED+=("$host")
        else
            log_error "$host deployment failed!"
            FAILED+=("$host")
            # On fail immédiatement si le déploiement échoue
            log_error "Déploiement échoué sur $host. Arrêt du script."
            exit 1
        fi
    else
        log_warning "$host is offline or unreachable"
        log_info "Skipping $host..."
        SKIPPED+=("$host")
    fi
done

# Résumé final
log_header "✅ Deployment Summary"

if [ ${#DEPLOYED[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Deployed successfully:${NC}"
    for host in "${DEPLOYED[@]}"; do
        echo "  • $host"
    done
    echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Skipped (offline):${NC}"
    for host in "${SKIPPED[@]}"; do
        echo "  • $host"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed:${NC}"
    for host in "${FAILED[@]}"; do
        echo "  • $host"
    done
    echo ""
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🌐 Binary Cache:${NC}"
echo "  Cache utilisé depuis: http://magnolia:5000"
echo ""

# Exit code basé sur les résultats
if [ ${#FAILED[@]} -gt 0 ]; then
    exit 1
elif [ ${#DEPLOYED[@]} -eq 0 ]; then
    log_warning "Aucune machine n'a été déployée"
    exit 0
else
    log_success "All accessible machines deployed successfully!"
    exit 0
fi
