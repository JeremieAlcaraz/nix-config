#!/usr/bin/env bash
# Script de diagnostic réseau pour NixOS
# Usage: sudo ./diagnose-network.sh

set -uo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}❌ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
section() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${BLUE}$1${NC}\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

section "📡 Diagnostic réseau NixOS"

# 1. Configuration réseau de base
section "1. Configuration réseau de base"

info "Interfaces réseau:"
ip addr show | grep -E "^[0-9]+:|inet " || error "Impossible de lister les interfaces"
echo ""

info "Routes par défaut:"
ip route show default || error "Pas de route par défaut!"
echo ""

info "Configuration DHCP:"
if command -v dhcpcd &> /dev/null; then
    dhcpcd -U eth0 2>/dev/null || true
fi

# 2. Configuration DNS actuelle
section "2. Configuration DNS"

info "Contenu de /etc/resolv.conf:"
if [[ -f /etc/resolv.conf ]]; then
    cat /etc/resolv.conf

    # Extraire les nameservers
    NAMESERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    if [[ -z "$NAMESERVERS" ]]; then
        error "AUCUN serveur DNS configuré!"
        warning "C'est probablement la cause du problème!"
    else
        success "Serveurs DNS trouvés:"
        echo "$NAMESERVERS"
    fi
else
    error "/etc/resolv.conf n'existe pas!"
fi
echo ""

# 3. Test de connectivité réseau
section "3. Test de connectivité réseau"

info "Ping vers 1.1.1.1 (Cloudflare DNS):"
if ping -c 3 -W 2 1.1.1.1 &> /dev/null; then
    success "Connectivité IP fonctionnelle"
    ping -c 3 -W 2 1.1.1.1 | tail -2
else
    error "Pas de connectivité IP!"
    warning "Vérifiez la configuration réseau de Proxmox"
fi
echo ""

info "Ping vers 8.8.8.8 (Google DNS):"
if ping -c 3 -W 2 8.8.8.8 &> /dev/null; then
    success "Connectivité vers Google DNS OK"
else
    warning "Impossible de joindre Google DNS"
fi
echo ""

# 4. Test de résolution DNS
section "4. Test de résolution DNS"

test_dns() {
    local domain=$1
    local dns_server=$2

    info "Test: $domain via $dns_server"

    if command -v nslookup &> /dev/null; then
        if timeout 5 nslookup "$domain" "$dns_server" &> /dev/null; then
            success "Résolution OK"
            timeout 5 nslookup "$domain" "$dns_server" 2>&1 | grep -A2 "Name:"
        else
            error "Échec de résolution (timeout ou erreur)"
        fi
    elif command -v dig &> /dev/null; then
        if timeout 5 dig +short "@$dns_server" "$domain" &> /dev/null; then
            success "Résolution OK"
            timeout 5 dig +short "@$dns_server" "$domain"
        else
            error "Échec de résolution"
        fi
    else
        warning "nslookup et dig non disponibles"
    fi
    echo ""
}

# Tester avec différents DNS
test_dns "registry.npmjs.org" "1.1.1.1"
test_dns "registry.npmjs.org" "8.8.8.8"

# Tester avec DNS système (si configuré)
if [[ -f /etc/resolv.conf ]]; then
    SYSTEM_DNS=$(grep "^nameserver" /etc/resolv.conf | head -1 | awk '{print $2}')
    if [[ -n "$SYSTEM_DNS" ]]; then
        test_dns "registry.npmjs.org" "$SYSTEM_DNS"
    fi
fi

# 5. Test de latence DNS
section "5. Test de latence DNS"

info "Mesure du temps de résolution (10 requêtes):"
if command -v dig &> /dev/null; then
    echo "Vers 1.1.1.1 (Cloudflare):"
    for i in {1..5}; do
        dig +stats @1.1.1.1 registry.npmjs.org 2>&1 | grep "Query time:" || true
    done

    echo ""
    echo "Vers 8.8.8.8 (Google):"
    for i in {1..5}; do
        dig +stats @8.8.8.8 registry.npmjs.org 2>&1 | grep "Query time:" || true
    done
else
    warning "dig non disponible pour tester la latence"
fi
echo ""

# 6. Test HTTPS vers npm registry
section "6. Test HTTPS vers npm registry"

info "Test de connexion HTTPS vers registry.npmjs.org:"
if command -v curl &> /dev/null; then
    if timeout 10 curl -I https://registry.npmjs.org/ &> /dev/null; then
        success "Connexion HTTPS OK"
        timeout 10 curl -I https://registry.npmjs.org/ 2>&1 | head -5
    else
        error "Impossible de se connecter en HTTPS"
    fi
elif command -v wget &> /dev/null; then
    if timeout 10 wget --spider https://registry.npmjs.org/ &> /dev/null; then
        success "Connexion HTTPS OK"
    else
        error "Impossible de se connecter en HTTPS"
    fi
else
    warning "curl et wget non disponibles"
fi
echo ""

# 7. Vérification Proxmox
section "7. Environnement Proxmox"

info "Détection VM Proxmox:"
if systemctl is-active qemu-guest-agent &> /dev/null || [[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]]; then
    success "VM Proxmox détectée"
    info "Vérifiez la configuration réseau dans Proxmox:"
    info "  - Bridge: vmbr0 ou autre"
    info "  - Modèle: VirtIO (recommandé)"
    info "  - Pare-feu Proxmox: peut bloquer DNS"
else
    warning "Pas de QEMU guest agent détecté"
fi
echo ""

# 8. Recommandations
section "8. 💡 Recommandations"

echo ""
if [[ -z "$(grep "^nameserver" /etc/resolv.conf 2>/dev/null)" ]]; then
    error "PROBLÈME PRINCIPAL: Aucun DNS configuré!"
    echo ""
    info "Solution immédiate:"
    echo "  sudo bash -c 'cat > /etc/resolv.conf <<EOF"
    echo "nameserver 1.1.1.1"
    echo "nameserver 8.8.8.8"
    echo "EOF'"
    echo ""
fi

info "Pour améliorer la stabilité DNS pendant l'installation:"
echo "  1. Utilisez le mode installation minimal (option 2)"
echo "  2. Configurez des DNS publics avant l'installation"
echo "  3. Vérifiez la config réseau Proxmox (bridge, pare-feu)"
echo ""

info "Si le problème persiste:"
echo "  1. Vérifiez les logs Proxmox: /var/log/syslog"
echo "  2. Testez avec un bridge réseau différent"
echo "  3. Désactivez temporairement le pare-feu Proxmox"
echo ""

section "✅ Diagnostic terminé"
