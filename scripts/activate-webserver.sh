#!/usr/bin/env bash
set -euo pipefail

# Script pour activer le serveur web j12zdotcom après l'installation minimale
# Usage: sudo ./activate-webserver.sh

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Vérifications initiales
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en tant que root (sudo)"

# Vérifier qu'on est sur mimosa
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" != "mimosa" ]]; then
    error "Ce script ne doit être exécuté que sur l'hôte 'mimosa' (hôte actuel: $HOSTNAME)"
fi

header "🌐 Activation du serveur web j12zdotcom"

info "Ce script va :"
echo "  1. Mettre à jour la configuration NixOS vers 'mimosa' (avec serveur web)"
echo "  2. Télécharger les dépendances npm du site web"
echo "  3. Activer tous les services (Caddy, Cloudflare Tunnel, etc.)"
echo ""

# Vérifier la connexion réseau
info "Vérification de la connexion réseau..."
if ! timeout 5 curl -sS --head --max-time 5 https://registry.npmjs.org > /dev/null 2>&1; then
    error "La connexion réseau ne fonctionne pas correctement. Vérifiez votre réseau avant de continuer."
fi
info "Connexion réseau : OK"
echo ""

# Demander confirmation
warning "ATTENTION: Cette opération va télécharger ~200MB de dépendances npm"
read -p "Voulez-vous continuer? (tapez 'oui' pour confirmer): " confirm
[[ "$confirm" != "oui" ]] && error "Activation annulée"

echo ""
header "🚀 Reconstruction du système"

# Se placer dans le répertoire de configuration
cd /etc/nixos || error "Le répertoire /etc/nixos n'existe pas"

# Vérifier que le dépôt git est à jour
info "Mise à jour du dépôt git..."
git fetch origin
git status

# Demander si on veut mettre à jour le dépôt
echo ""
read -p "Voulez-vous mettre à jour le dépôt vers la dernière version? (oui/non, défaut: non): " update_repo
update_repo="${update_repo:-non}"

if [[ "$update_repo" == "oui" ]]; then
    info "Mise à jour du dépôt..."
    CURRENT_BRANCH=$(git branch --show-current)
    git pull origin "$CURRENT_BRANCH"
fi

# Lancer la reconstruction avec la configuration complète "mimosa"
info "Reconstruction du système avec la configuration 'mimosa' (serveur web activé)..."
info "Cette opération peut prendre 5-10 minutes..."
echo ""

# Utiliser nixos-rebuild avec la configuration mimosa
if nixos-rebuild switch --flake ".#mimosa" 2>&1 | tee /tmp/nixos-rebuild.log; then
    echo ""
    header "✨ Activation réussie!"
    echo ""
    info "Le serveur web j12zdotcom est maintenant actif!"
    echo ""
    info "Services activés:"
    echo "  • Caddy (reverse proxy) : https://${HOSTNAME}.local"
    echo "  • Cloudflare Tunnel : https://jeremiealcaraz.com"
    echo "  • Site web j12zdotcom : port 4321"
    echo ""
    info "Pour vérifier l'état des services:"
    echo "  systemctl status caddy"
    echo "  systemctl status cloudflared-tunnel-*"
    echo "  systemctl status j12zdotcom"
    echo ""
    info "Pour voir les logs:"
    echo "  journalctl -u caddy -f"
    echo "  journalctl -u j12zdotcom -f"
    echo ""
else
    echo ""
    error "La reconstruction a échoué. Consultez /tmp/nixos-rebuild.log pour plus de détails."
fi
