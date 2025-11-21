#!/usr/bin/env bash
# Script de déploiement automatique du site j12zdotcom sur mimosa
#
# Usage:
#   ./scripts/deploy-j12zdotcom.sh           # Déploie depuis n'importe quelle machine
#   ./scripts/deploy-j12zdotcom.sh --local   # Force le déploiement local (si sur mimosa)
#   ./scripts/deploy-j12zdotcom.sh --help    # Affiche l'aide

set -euo pipefail

# Configuration
HOST="mimosa"
SITE_DIR="/var/www/j12zdotcom"
BUILD_DIR="/tmp/j12zdotcom-build-$$"
SITE_REPO="https://github.com/JeremieAlcaraz/j12zdotcom.git"
CONFIG_DIR="/etc/nixos"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Déploie le site j12zdotcom sur le serveur mimosa.

OPTIONS:
    --local     Force le déploiement local (assume que tu es sur mimosa)
    --skip-nix  Skip le nixos-rebuild (utile pour tester juste le site)
    --help      Affiche cette aide

EXAMPLES:
    $0                  # Déploie depuis magnolia vers mimosa (via SSH)
    $0 --local          # Déploie localement sur mimosa
    $0 --skip-nix       # Met à jour le site sans rebuilder NixOS

REQUIREMENTS:
    - nodejs_20, pnpm_9, vips (via nix-shell)
    - SSH access to mimosa (si déploiement distant)
    - sudo rights sur mimosa

EOF
}

# Parse arguments
LOCAL_MODE=false
SKIP_NIX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            LOCAL_MODE=true
            shift
            ;;
        --skip-nix)
            SKIP_NIX=true
            shift
            ;;
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

# Détection automatique si on est sur mimosa
CURRENT_HOST=$(hostname)
if [[ "$CURRENT_HOST" == "$HOST" ]]; then
    LOCAL_MODE=true
    log_info "Détection automatique: exécution locale sur mimosa"
fi

# Cleanup à la sortie
cleanup() {
    log_info "Nettoyage..."
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

# Étape 1: Build du site
log_info "🏗️  Building j12zdotcom site..."
rm -rf "$BUILD_DIR"
git clone "$SITE_REPO" "$BUILD_DIR"
cd "$BUILD_DIR"

# Afficher la version qu'on va builder
CURRENT_COMMIT=$(git rev-parse --short HEAD)
log_info "Building commit: $CURRENT_COMMIT"

# Build avec Nix
log_info "Installing dependencies and building..."
if ! nix-shell -p nodejs_20 pnpm_9 vips --run "pnpm install && pnpm build" > /tmp/build.log 2>&1; then
    log_error "Build failed! Check /tmp/build.log for details"
    tail -20 /tmp/build.log
    exit 1
fi

log_success "Build completed successfully"

# Vérifier que le dossier dist existe
if [[ ! -d "dist" ]]; then
    log_error "dist/ directory not found after build!"
    exit 1
fi

# Compter les fichiers
FILE_COUNT=$(find dist -type f | wc -l)
log_info "Built $FILE_COUNT files"

# Étape 2: Déployer les fichiers
log_info "📦 Deploying to $HOST..."

if $LOCAL_MODE; then
    # Déploiement local
    log_info "Déploiement local..."

    # Backup de l'ancien site (au cas où)
    if [[ -d "$SITE_DIR" ]]; then
        BACKUP_DIR="${SITE_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up current site to $BACKUP_DIR"
        sudo cp -r "$SITE_DIR" "$BACKUP_DIR"
    fi

    # Créer le dossier si nécessaire
    sudo mkdir -p "$SITE_DIR"

    # Copier les nouveaux fichiers
    log_info "Copying files to $SITE_DIR..."
    sudo rm -rf "${SITE_DIR:?}"/*
    sudo cp -r dist/* "$SITE_DIR/"

    # Permissions
    sudo chown -R root:root "$SITE_DIR"
    sudo chmod -R 755 "$SITE_DIR"

    log_success "Site deployed locally"
else
    # Déploiement distant via SSH
    log_info "Déploiement distant vers $HOST..."

    # Vérifier la connexion SSH
    if ! ssh -q "$HOST" exit; then
        log_error "Cannot connect to $HOST via SSH"
        exit 1
    fi

    # Créer le dossier distant
    ssh "$HOST" "sudo mkdir -p $SITE_DIR"

    # Rsync avec sudo
    log_info "Uploading files via rsync..."
    if ! rsync -avz --delete --progress \
        dist/ "$HOST:$SITE_DIR/" \
        --rsync-path="sudo rsync" > /tmp/rsync.log 2>&1; then
        log_error "Rsync failed! Check /tmp/rsync.log"
        tail -20 /tmp/rsync.log
        exit 1
    fi

    # Permissions
    ssh "$HOST" "sudo chown -R root:root $SITE_DIR && sudo chmod -R 755 $SITE_DIR"

    log_success "Site deployed to $HOST"
fi

# Étape 3: Rebuild NixOS (optionnel)
if $SKIP_NIX; then
    log_warning "Skipping nixos-rebuild (--skip-nix flag)"
else
    log_info "🔄 Rebuilding NixOS configuration..."

    if $LOCAL_MODE; then
        # Rebuild local
        cd "$CONFIG_DIR"
        if sudo nixos-rebuild switch --flake ".#mimosa" --impure; then
            log_success "NixOS configuration applied"
        else
            log_error "nixos-rebuild failed!"
            exit 1
        fi
    else
        # Rebuild distant
        if ssh "$HOST" "cd $CONFIG_DIR && sudo nixos-rebuild switch --flake '.#mimosa' --impure"; then
            log_success "NixOS configuration applied on $HOST"
        else
            log_error "Remote nixos-rebuild failed!"
            exit 1
        fi
    fi
fi

# Étape 4: Vérifications
log_info "🔍 Running health checks..."

if $LOCAL_MODE; then
    # Checks locaux
    if systemctl is-active --quiet caddy; then
        log_success "Caddy is running"
    else
        log_warning "Caddy is not running!"
    fi

    if systemctl is-active --quiet cloudflared; then
        log_success "Cloudflared is running"
    else
        log_warning "Cloudflared is not running!"
    fi

    # Test HTTP local
    if curl -sf http://localhost > /dev/null; then
        log_success "HTTP endpoint responding"
    else
        log_warning "HTTP endpoint not responding!"
    fi
else
    # Checks distants
    ssh "$HOST" "systemctl is-active --quiet caddy" && log_success "Caddy is running" || log_warning "Caddy is not running!"
    ssh "$HOST" "systemctl is-active --quiet cloudflared" && log_success "Cloudflared is running" || log_warning "Cloudflared is not running!"
fi

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Site commit: $CURRENT_COMMIT"
log_info "Files deployed: $FILE_COUNT"
log_info "Public URL: https://jeremiealcaraz.com"
echo ""
log_info "To check logs:"
if $LOCAL_MODE; then
    echo "  sudo journalctl -u caddy -f"
    echo "  sudo journalctl -u cloudflared -f"
else
    echo "  ssh $HOST 'sudo journalctl -u caddy -f'"
    echo "  ssh $HOST 'sudo journalctl -u cloudflared -f'"
fi
echo ""
