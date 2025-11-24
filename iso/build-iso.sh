#!/usr/bin/env bash
set -euo pipefail

# Script de build automatisé de l'ISO NixOS
# Usage: ./build-iso.sh [--update|--sync]
#
# Options:
#   --update  : Met à jour vers la dernière version de nixpkgs
#   --sync    : Synchronise avec la version du flake principal (défaut)
#   --help    : Affiche cette aide

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

# Aide
if [[ "${1:-}" == "--help" ]]; then
    cat << EOF
${CYAN}═══════════════════════════════════════════════${NC}
${BLUE}  🏗️  Builder ISO NixOS à jour${NC}
${CYAN}═══════════════════════════════════════════════${NC}

Usage: $0 [OPTIONS]

Options:
  --update    Met à jour vers la dernière version de nixpkgs
  --sync      Synchronise avec le flake principal (défaut)
  --help      Affiche cette aide

Exemples:
  $0                  # Sync avec flake principal
  $0 --sync           # Même chose (explicite)
  $0 --update         # Dernière version nixpkgs

Le résultat sera dans: result/iso/nixos-minimal-ttyS0.iso
EOF
    exit 0
fi

MODE="${1:---sync}"

# Vérifier qu'on est dans le bon dossier
if [[ ! -f "flake.nix" ]]; then
    error "Ce script doit être exécuté depuis le dossier iso/"
fi

# Banner
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       🏗️  Build ISO NixOS à jour                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ========================================
# Étape 1 : Vérifier la version actuelle
# ========================================
step "Étape 1/4 : Vérification des versions"

if [[ -f flake.lock ]]; then
    CURRENT_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock 2>/dev/null || echo "unknown")
    CURRENT_DATE=$(jq -r '.nodes.nixpkgs.locked.lastModified' flake.lock 2>/dev/null || echo "0")

    if [[ "$CURRENT_DATE" != "0" ]]; then
        CURRENT_DATE_READABLE=$(date -d @"$CURRENT_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$CURRENT_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
        info "Version actuelle ISO: $CURRENT_REV ($CURRENT_DATE_READABLE)"
    else
        info "Version actuelle ISO: $CURRENT_REV"
    fi
else
    warning "Pas de flake.lock trouvé, première initialisation"
fi

# Vérifier la version du flake principal si --sync
if [[ "$MODE" == "--sync" ]]; then
    if [[ -f "../flake.lock" ]]; then
        MAIN_REV=$(jq -r '.nodes.nixpkgs.locked.rev' ../flake.lock)
        MAIN_DATE=$(jq -r '.nodes.nixpkgs.locked.lastModified' ../flake.lock)
        MAIN_DATE_READABLE=$(date -d @"$MAIN_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$MAIN_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")

        info "Version flake principal: $MAIN_REV ($MAIN_DATE_READABLE)"

        if [[ "$CURRENT_REV" == "$MAIN_REV" ]]; then
            info "ISO déjà synchronisée avec le flake principal ✅"
        else
            warning "Gap détecté entre ISO et flake principal"
        fi
    else
        error "Flake principal introuvable (../flake.lock)"
    fi
fi

# ========================================
# Étape 2 : Mise à jour du flake
# ========================================
step "Étape 2/4 : Mise à jour nixpkgs"

if [[ "$MODE" == "--sync" ]]; then
    info "Mode: Synchronisation avec flake principal"

    MAIN_REV=$(jq -r '.nodes.nixpkgs.locked.rev' ../flake.lock)

    info "Mise à jour vers: $MAIN_REV"
    nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$MAIN_REV"

elif [[ "$MODE" == "--update" ]]; then
    info "Mode: Mise à jour vers la dernière version"

    nix flake update

else
    error "Mode invalide: $MODE (utilisez --sync ou --update)"
fi

# Vérifier la nouvelle version
NEW_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
NEW_DATE=$(jq -r '.nodes.nixpkgs.locked.lastModified' flake.lock)
NEW_DATE_READABLE=$(date -d @"$NEW_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$NEW_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")

info "Nouvelle version: $NEW_REV ($NEW_DATE_READABLE)"

# ========================================
# Étape 3 : Build de l'ISO
# ========================================
step "Étape 3/4 : Build de l'ISO"

warning "Cela peut prendre 5-15 minutes selon votre machine..."
echo ""

START_TIME=$(date +%s)

# Build avec logs
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage \
    --print-build-logs

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_TIME_MIN=$((BUILD_TIME / 60))
BUILD_TIME_SEC=$((BUILD_TIME % 60))

info "Build terminé en ${BUILD_TIME_MIN}m ${BUILD_TIME_SEC}s"

# ========================================
# Étape 4 : Vérification
# ========================================
step "Étape 4/4 : Vérification du résultat"

if [[ -f result/iso/nixos-minimal-ttyS0.iso ]]; then
    ISO_SIZE=$(du -h result/iso/nixos-minimal-ttyS0.iso | cut -f1)
    ISO_PATH=$(realpath result/iso/nixos-minimal-ttyS0.iso)

    info "ISO créée avec succès !"
    info "Taille: $ISO_SIZE"
    info "Chemin: $ISO_PATH"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🎉 ISO prête !                                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    info "Prochaines étapes:"
    echo ""
    echo -e "${YELLOW}1.${NC} Copier l'ISO vers Downloads:"
    echo "   ${CYAN}cp result/iso/nixos-minimal-ttyS0.iso ~/Downloads/${NC}"
    echo ""
    echo -e "${YELLOW}2.${NC} Uploader sur Proxmox:"
    echo "   ${CYAN}scp ~/Downloads/nixos-minimal-ttyS0.iso root@proxmox:/var/lib/vz/template/iso/${NC}"
    echo ""
    echo -e "${YELLOW}3.${NC} Attacher à une VM:"
    echo "   ${CYAN}qm set <VMID> --ide2 local:iso/nixos-minimal-ttyS0.iso,media=cdrom${NC}"
    echo ""
    echo -e "${YELLOW}4.${NC} Installer minimal:"
    echo "   ${CYAN}sudo ./scripts/install-nixos.sh minimal${NC}"
    echo ""

    info "Temps d'installation attendu: ~2-3 minutes ✅"

else
    error "ISO introuvable après le build"
fi

# Si on a modifié le flake.lock, proposer de committer
if git diff --quiet flake.lock 2>/dev/null; then
    info "Aucun changement à committer"
else
    echo ""
    warning "flake.lock a été modifié"
    echo ""
    echo -e "${YELLOW}Voulez-vous committer les changements ? (oui/non)${NC}"
    read -r COMMIT_CHOICE

    if [[ "$COMMIT_CHOICE" == "oui" ]]; then
        git add flake.lock
        git commit -m "chore(iso): update nixpkgs to $NEW_REV"
        info "Changements committés ✅"

        echo ""
        echo -e "${YELLOW}Voulez-vous pousser vers le remote ? (oui/non)${NC}"
        read -r PUSH_CHOICE

        if [[ "$PUSH_CHOICE" == "oui" ]]; then
            git push
            info "Changements poussés ✅"
        fi
    else
        info "Changements non committés (vous pouvez le faire manuellement plus tard)"
    fi
fi
