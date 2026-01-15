#!/usr/bin/env bash
# Script pour rebuilder toutes les configurations et remplir le cache binaire
#
# Usage:
#   ./scripts/rebuild-all.sh              # Rebuild tout et met à jour j12z-site
#   ./scripts/rebuild-all.sh --skip-site  # Rebuild tout sans mettre à jour j12z-site
#   ./scripts/rebuild-all.sh --help       # Affiche l'aide

set -euo pipefail

# Configuration
CONFIG_DIR="/etc/nixos"

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

Rebuild toutes les configurations NixOS et remplit le cache binaire magnolia.

Ce script va :
  1. Synchroniser le repo depuis Gitea (origin)
  2. Mettre à jour j12z-site (optionnel)
  3. Builder mimosa, whitelily, dandelion, minimal pour le cache
  4. Builder et appliquer la config magnolia
  5. Commit et push le flake.lock (si modifié)

OPTIONS:
    --skip-site    Ne pas mettre à jour j12z-site
    --help         Affiche cette aide

EXAMPLES:
    $0                # Rebuild tout et met à jour j12z-site
    $0 --skip-site    # Rebuild tout sans toucher à j12z-site

NOTE:
    Ce script est conçu pour être exécuté sur magnolia.
    Les builds seront automatiquement disponibles via nix-serve sur :5000

EOF
}

# Parse arguments
SKIP_SITE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-site)
            SKIP_SITE=true
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

# Début du script
log_header "🚀 Rebuild All Configurations"

# Étape 1: Sync depuis Gitea (origin)
log_info "Synchronisation depuis origin (Gitea)..."
git fetch origin
git reset --hard origin/main
log_success "Repo synchronisé"

# Étape 2: Update j12z-site (optionnel)
if $SKIP_SITE; then
    log_warning "Mise à jour de j12z-site ignorée (--skip-site)"
else
    log_info "Mise à jour de j12z-site..."
    nix flake update j12z-site
    log_success "j12z-site mis à jour"
fi

# Étape 3: Build toutes les configurations
log_header "🏗️  Building All Configurations for Cache"

echo -e "${BLUE}📦 Building mimosa...${NC}"
if nix build .#nixosConfigurations.mimosa.config.system.build.toplevel; then
    log_success "Mimosa built!"
else
    log_error "Mimosa build failed!"
    exit 1
fi

echo ""
echo -e "${BLUE}📦 Building whitelily...${NC}"
if nix build .#nixosConfigurations.whitelily.config.system.build.toplevel; then
    log_success "Whitelily built!"
else
    log_error "Whitelily build failed!"
    exit 1
fi

echo ""
echo -e "${BLUE}📦 Building dandelion...${NC}"
if nix build .#nixosConfigurations.dandelion.config.system.build.toplevel; then
    log_success "Dandelion built!"
else
    log_error "Dandelion build failed!"
    exit 1
fi

echo ""
echo -e "${BLUE}📦 Building minimal...${NC}"
if nix build .#nixosConfigurations.minimal.config.system.build.toplevel; then
    log_success "Minimal built!"
else
    log_error "Minimal build failed!"
    exit 1
fi

# Étape 4: Build et switch magnolia
log_header "🔨 Building and Switching Magnolia"

if sudo nixos-rebuild switch --flake .#magnolia; then
    log_success "Magnolia configuration applied!"
else
    log_error "Magnolia rebuild failed!"
    exit 1
fi

# Étape 5: Commit et push flake.lock (si modifié)
log_header "📤 Committing Changes"

git add flake.lock

if git diff --cached --quiet; then
    log_info "Pas de changements dans flake.lock, rien à commiter"
else
    log_info "Commit du flake.lock..."
    git commit -m "chore: update flake.lock after full rebuild"

    log_info "Push vers origin (Gitea)..."
    if git push origin main; then
        log_success "flake.lock pushed to origin"
    else
        log_error "Push failed! Fais-le manuellement avec: git push origin main"
    fi
fi

# Résumé final
log_header "✅ ALL DONE!"

echo -e "${GREEN}📊 Cache Status:${NC}"
echo "  • Magnolia:  ${GREEN}✓${NC} Applied + Cached"
echo "  • Mimosa:    ${GREEN}✓${NC} Cached"
echo "  • Whitelily: ${GREEN}✓${NC} Cached"
echo "  • Dandelion: ${GREEN}✓${NC} Cached"
echo "  • Minimal:   ${GREEN}✓${NC} Cached"

if ! $SKIP_SITE; then
    echo "  • j12z-site: ${GREEN}✓${NC} Latest version"
fi

echo ""
echo -e "${CYAN}🌐 Binary Cache:${NC}"
echo "  Toutes les configurations sont disponibles via:"
echo "  http://magnolia:5000 (ou via Tailscale)"
echo ""
echo -e "${CYAN}📝 Next Steps:${NC}"
echo "  Les déploiements sur mimosa/whitelily seront ultra-rapides"
echo "  car ils téléchargeront depuis le cache local ! 🚀"
echo ""
