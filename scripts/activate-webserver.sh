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

# Configuration DNS robuste pour améliorer la résilience réseau
info "Configuration DNS robuste pour le téléchargement des dépendances npm..."

# Fonction pour configurer les DNS
configure_dns() {
    local resolv_conf="/etc/resolv.conf"

    # Retirer la protection immutable du fichier si elle existe
    chattr -i "$resolv_conf" 2>/dev/null || true

    # Sauvegarder la configuration actuelle
    cp "$resolv_conf" "${resolv_conf}.backup" 2>/dev/null || true

    # Écrire la configuration DNS avec retry
    cat > "$resolv_conf" << EOF
# DNS publics temporaires pour le téléchargement npm
# Cloudflare: 1.1.1.1, 1.0.0.1
# Google: 8.8.8.8, 8.8.4.4
options timeout:5 attempts:5 rotate
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
}

# Stopper resolvconf s'il tourne (pour éviter qu'il réécrive /etc/resolv.conf)
if systemctl is-active resolvconf > /dev/null 2>&1; then
    warning "Arrêt temporaire de resolvconf pour configurer les DNS publics..."
    systemctl stop resolvconf 2>/dev/null || true
fi

# Configurer DNS
configure_dns

# Configuration Nix avec retry et timeouts augmentés
export NIX_CONFIG='experimental-features = nix-command flakes
connect-timeout = 30
stalled-download-timeout = 300
max-substitution-jobs = 4'

# Variables d'environnement pour améliorer la résilience réseau de npm/pnpm
export npm_config_fetch_retries=5
export npm_config_fetch_retry_factor=3
export npm_config_fetch_retry_mintimeout=10000
export npm_config_fetch_retry_maxtimeout=120000
export npm_config_fetch_timeout=120000

# Configurer npm/pnpm pour plus de résilience aux erreurs réseau
info "Configuration de npm/pnpm avec retry logic..."
cat > /root/.npmrc << EOF
# Configuration npm pour améliorer la résilience réseau
fetch-retries=5
fetch-retry-factor=3
fetch-retry-mintimeout=10000
fetch-retry-maxtimeout=120000
fetch-timeout=120000
maxsockets=5
registry=https://registry.npmjs.org/
EOF

info "Configuration réseau robuste appliquée"
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

# Fonction pour reconstruire avec retry en cas d'erreur réseau
rebuild_with_retry() {
    local max_attempts=3
    local attempt=1
    local wait_time=30

    while [[ $attempt -le $max_attempts ]]; do
        info "Tentative de reconstruction $attempt/$max_attempts..."

        if npm_config_fetch_retries=5 \
           npm_config_fetch_retry_factor=3 \
           npm_config_fetch_retry_mintimeout=10000 \
           npm_config_fetch_retry_maxtimeout=120000 \
           npm_config_fetch_timeout=120000 \
           nixos-rebuild switch --flake ".#mimosa" 2>&1 | tee /tmp/nixos-rebuild.log; then
            return 0
        fi

        # Vérifier si l'erreur est liée au réseau
        if grep -qE "EAI_AGAIN|ETIMEDOUT|ECONNRESET|getaddrinfo" /tmp/nixos-rebuild.log; then
            if [[ $attempt -lt $max_attempts ]]; then
                warning "Erreur réseau détectée (EAI_AGAIN/ETIMEDOUT). Nouvelle tentative dans ${wait_time}s..."
                warning "Ces erreurs sont courantes lors du téléchargement des dépendances npm..."
                sleep "$wait_time"
                # Augmenter le temps d'attente pour la prochaine tentative (backoff exponentiel)
                wait_time=$((wait_time * 2))
                attempt=$((attempt + 1))
            else
                echo ""
                error "Reconstruction échouée après $max_attempts tentatives à cause d'erreurs réseau. Consultez /tmp/nixos-rebuild.log pour plus de détails."
            fi
        else
            # Erreur non-réseau, ne pas réessayer
            echo ""
            error "Reconstruction échouée pour une raison autre que le réseau. Consultez /tmp/nixos-rebuild.log pour plus de détails."
        fi
    done

    return 1
}

# Lancer la reconstruction avec retry
if rebuild_with_retry; then
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
fi
