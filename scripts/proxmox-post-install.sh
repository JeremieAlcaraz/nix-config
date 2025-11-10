#!/usr/bin/env bash
set -euo pipefail

# Script compagnon pour l'hôte Proxmox
# Usage: ./proxmox-post-install.sh <VMID>
#
# Ce script:
# 1. Attend que la VM s'éteigne (après l'installation)
# 2. Détache l'ISO d'installation
# 3. Redémarre la VM

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

# Vérifications
[[ $# -ne 1 ]] && error "Usage: $0 <VMID>"
VMID="$1"

# Vérifier que la VM existe
qm status "$VMID" &>/dev/null || error "La VM $VMID n'existe pas"

info "Surveillance de la VM $VMID..."
info "En attente de l'arrêt de la VM (après l'installation)..."

# Attendre que la VM s'éteigne
while true; do
    STATUS=$(qm status "$VMID" | awk '{print $2}')
    if [[ "$STATUS" == "stopped" ]]; then
        info "VM arrêtée détectée!"
        break
    fi
    echo -ne "${YELLOW}⏳ État actuel: $STATUS - vérification dans 5s...${NC}\r"
    sleep 5
done
echo ""

# Petite pause pour s'assurer que tout est bien arrêté
sleep 2

# Détacher l'ISO
info "Détachement de l'ISO d'installation..."
qm set "$VMID" --ide2 none || warning "Impossible de détacher l'ISO (peut-être déjà détachée)"

# Redémarrer la VM
info "Redémarrage de la VM..."
qm start "$VMID"

info ""
info "=========================================="
info "🎉 Post-installation terminée!"
info "=========================================="
info ""
info "La VM $VMID démarre sur le système NixOS installé."
info ""
info "Pour vous connecter:"
info "  1. Trouvez l'IP de la VM (console Proxmox ou DHCP)"
info "  2. ssh jeremie@<IP>"
info ""
