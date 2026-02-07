#!/usr/bin/env bash
# Script de diagnostic réseau pour l'ISO d'installation
# Usage: sudo /etc/installer/scripts/diagnose-network.sh

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        🔧 Diagnostic Réseau - NixOS Installer     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Interfaces réseau
echo -e "${YELLOW}1. Interfaces réseau disponibles :${NC}"
ip addr show | grep -E "^[0-9]+:|inet " --color=never
echo ""

# 2. Routes
echo -e "${YELLOW}2. Table de routage :${NC}"
ip route show
echo ""

# 3. DNS
echo -e "${YELLOW}3. Configuration DNS (/etc/resolv.conf) :${NC}"
cat /etc/resolv.conf 2>/dev/null || echo "Fichier introuvable"
echo ""

# 4. Test de connectivité
echo -e "${YELLOW}4. Tests de connectivité :${NC}"

# Ping gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [[ -n "$GATEWAY" ]]; then
    echo -n "   - Gateway ($GATEWAY): "
    if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ ÉCHEC${NC}"
    fi
else
    echo "   - Gateway: Aucune route par défaut trouvée"
fi

# Ping DNS public
echo -n "   - DNS public (1.1.1.1): "
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ ÉCHEC${NC}"
fi

# Résolution DNS
echo -n "   - Résolution DNS (nixos.org): "
if nslookup nixos.org >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ ÉCHEC${NC}"
fi

# Ping externe
echo -n "   - Connectivité externe (nixos.org): "
if ping -c 1 -W 3 nixos.org >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ ÉCHEC${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

# 5. Recommandations
echo -e "${YELLOW}💡 Recommandations :${NC}"
echo ""
echo "Si la connectivité échoue :"
echo "  1. Vérifier le câble réseau (VM : bridge mode actif ?)"
echo "  2. Redémarrer le service réseau : systemctl restart network"
echo "  3. Vérifier DHCP : dhclient -v"
echo "  4. Configuration manuelle IP :"
echo "     ip addr add 192.168.1.100/24 dev eth0"
echo "     ip route add default via 192.168.1.1"
echo "     echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
echo ""
