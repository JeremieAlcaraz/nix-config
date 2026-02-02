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

Le résultat sera copié en: nixos-installer-ttyS0-YYYY-MM-DD.iso
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
    CURRENT_REV="none"
fi

# Vérifier la version du flake principal si --sync
if [[ "$MODE" == "--sync" ]]; then
    if [[ -f "../flake.lock" ]]; then
        MAIN_REV=$(jq -r '.nodes.nixpkgs.locked.rev' ../flake.lock)
        MAIN_DATE=$(jq -r '.nodes.nixpkgs.locked.lastModified' ../flake.lock)
        MAIN_DATE_READABLE=$(date -d @"$MAIN_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$MAIN_DATE" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")

        info "Version flake principal: $MAIN_REV ($MAIN_DATE_READABLE)"

        if [[ "$CURRENT_REV" != "none" ]] && [[ "$CURRENT_REV" == "$MAIN_REV" ]]; then
            info "ISO déjà synchronisée avec le flake principal ✅"
        else
            warning "Gap détecté entre ISO et flake principal (ou première initialisation)"
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
nix build .#nixosConfigurations.iso-installer-ttyS0.config.system.build.isoImage \
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

BASE_ISO="result/iso/nixos-installer-ttyS0.iso"
if [[ -f "$BASE_ISO" ]]; then
    info "ISO créée avec succès !"
    info "Source: $BASE_ISO"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🎉 ISO prête !                                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    info "Temps d'installation attendu: ~2-3 minutes ✅"

else
    error "ISO introuvable après le build"
fi

# ========================================
# Commit des changements (si nécessaire)
# ========================================
# Si on a modifié le flake.lock, proposer de committer
if git diff --quiet flake.lock 2>/dev/null; then
    info "Aucun changement à committer"
else
    echo ""
    step "Commit des changements"
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

# Générer un nom d'ISO avec la date
BUILD_DATE=$(date '+%Y-%m-%d')
ISO_NAME_DATED="nixos-installer-ttyS0-${BUILD_DATE}.iso"
DATED_ISO="./${ISO_NAME_DATED}"

info "Copie locale de l'ISO : $DATED_ISO"
cp "$BASE_ISO" "$DATED_ISO"

ISO_SIZE=$(du -h "$DATED_ISO" | cut -f1)
ISO_PATH=$(realpath "$DATED_ISO")
info "Taille: $ISO_SIZE"
info "Chemin: $ISO_PATH"

# ========================================
# Étape 5 : Copier l'ISO
# ========================================
echo ""
step "Étape 5/7 : Copier l'ISO"

info "Nom de l'ISO : $ISO_NAME_DATED"

echo -e "${YELLOW}Où voulez-vous copier l'ISO ?${NC}"
echo ""
echo -e "${GREEN}1)${NC} Mac - marigold (~/Downloads/$ISO_NAME_DATED)"
echo -e "${GREEN}2)${NC} Proxmox - muscari (root@192.168.1.50:/var/lib/vz/template/iso/)"
echo -e "${GREEN}3)${NC} Les deux"
echo -e "${GREEN}4)${NC} Ignorer (ne pas copier)"
echo ""
read -p "Choix (1-4): " COPY_CHOICE

COPIED_TO_MAC=false
COPIED_TO_PROXMOX=false

case "$COPY_CHOICE" in
    1)
        info "Copie vers Mac (marigold)..."
        scp "$DATED_ISO" jeremie@marigold:~/Downloads/$ISO_NAME_DATED
        info "✅ Copié vers marigold:~/Downloads/$ISO_NAME_DATED"
        COPIED_TO_MAC=true
        ;;
    2)
        # Scanner Proxmox pour les anciennes ISO avant de copier
        info "Scan des ISO existantes sur Proxmox..."
        EXISTING_ISOS=$(ssh root@192.168.1.50 "ls -1t /var/lib/vz/template/iso/nixos-installer-ttyS0-*.iso 2>/dev/null" || echo "")

        if [[ -n "$EXISTING_ISOS" ]]; then
            ISO_COUNT=$(echo "$EXISTING_ISOS" | wc -l)
            echo ""
            warning "Trouvé $ISO_COUNT ISO(s) existante(s) :"
            echo "$EXISTING_ISOS" | nl -w2 -s'. '
            echo ""
            echo -e "${YELLOW}Voulez-vous nettoyer les anciennes ISO ? (oui/non)${NC}"
            echo -e "${CYAN}(Recommandé : garder les 2-3 plus récentes)${NC}"
            read -r CLEANUP_OLD_ISOS

            if [[ "$CLEANUP_OLD_ISOS" == "oui" ]]; then
                echo ""
                info "Nettoyage des anciennes ISO..."
                # Garder les 2 plus récentes, supprimer les autres
                OLD_ISOS=$(echo "$EXISTING_ISOS" | tail -n +3)
                if [[ -n "$OLD_ISOS" ]]; then
                    echo "$OLD_ISOS" | while read iso; do
                        ssh root@192.168.1.50 "rm -f '$iso'" && info "Supprimé : $(basename $iso)"
                    done
                    info "✅ Anciennes ISO nettoyées (gardé les 2 plus récentes)"
                else
                    info "Seulement 2 ISO ou moins, pas de nettoyage nécessaire"
                fi
            fi
        fi

        echo ""
        info "Copie vers Proxmox..."
        scp "$DATED_ISO" root@192.168.1.50:/var/lib/vz/template/iso/$ISO_NAME_DATED
        info "✅ Copié vers root@192.168.1.50:/var/lib/vz/template/iso/$ISO_NAME_DATED"
        COPIED_TO_PROXMOX=true
        ;;
    3)
        info "Copie vers Mac (marigold)..."
        scp "$DATED_ISO" jeremie@marigold:~/Downloads/$ISO_NAME_DATED
        info "✅ Copié vers marigold:~/Downloads/$ISO_NAME_DATED"
        COPIED_TO_MAC=true

        echo ""
        # Scanner Proxmox pour les anciennes ISO
        info "Scan des ISO existantes sur Proxmox..."
        EXISTING_ISOS=$(ssh root@192.168.1.50 "ls -1t /var/lib/vz/template/iso/nixos-installer-ttyS0-*.iso 2>/dev/null" || echo "")

        if [[ -n "$EXISTING_ISOS" ]]; then
            ISO_COUNT=$(echo "$EXISTING_ISOS" | wc -l)
            echo ""
            warning "Trouvé $ISO_COUNT ISO(s) existante(s) :"
            echo "$EXISTING_ISOS" | nl -w2 -s'. '
            echo ""
            echo -e "${YELLOW}Voulez-vous nettoyer les anciennes ISO ? (oui/non)${NC}"
            echo -e "${CYAN}(Recommandé : garder les 2-3 plus récentes)${NC}"
            read -r CLEANUP_OLD_ISOS

            if [[ "$CLEANUP_OLD_ISOS" == "oui" ]]; then
                echo ""
                info "Nettoyage des anciennes ISO..."
                # Garder les 2 plus récentes, supprimer les autres
                OLD_ISOS=$(echo "$EXISTING_ISOS" | tail -n +3)
                if [[ -n "$OLD_ISOS" ]]; then
                    echo "$OLD_ISOS" | while read iso; do
                        ssh root@192.168.1.50 "rm -f '$iso'" && info "Supprimé : $(basename $iso)"
                    done
                    info "✅ Anciennes ISO nettoyées (gardé les 2 plus récentes)"
                else
                    info "Seulement 2 ISO ou moins, pas de nettoyage nécessaire"
                fi
            fi
        fi

        echo ""
        info "Copie vers Proxmox..."
        scp "$DATED_ISO" root@192.168.1.50:/var/lib/vz/template/iso/$ISO_NAME_DATED
        info "✅ Copié vers root@192.168.1.50:/var/lib/vz/template/iso/$ISO_NAME_DATED"
        COPIED_TO_PROXMOX=true
        ;;
    4)
        info "Copie ignorée"
        ;;
    *)
        warning "Choix invalide, copie ignorée"
        ;;
esac

# ========================================
# Étape 6 : Nettoyage local
# ========================================
if [[ "$COPIED_TO_MAC" == true ]] || [[ "$COPIED_TO_PROXMOX" == true ]]; then
    echo ""
    step "Étape 6/7 : Nettoyage local"

    echo -e "${YELLOW}Voulez-vous supprimer l'ISO locale ? (oui/non)${NC}"
    echo -e "${CYAN}Note: Le Nix store sera conservé pour les futurs builds${NC}"
    read -r CLEANUP_CHOICE

    if [[ "$CLEANUP_CHOICE" == "oui" ]]; then
        info "Suppression de l'ISO locale..."
        rm -rf result
        info "✅ ISO supprimée (Nix store conservé)"
        echo ""
        info "Pour rebuilder plus tard, relancez simplement ./build-iso.sh"
    else
        info "ISO conservée dans: $ISO_PATH"
    fi
fi

# ========================================
# Étape 7 : Résumé final
# ========================================
echo ""
step "Étape 7/7 : Résumé"

if [[ "$COPIED_TO_MAC" == true ]]; then
    info "📦 ISO disponible sur Mac (marigold) : ~/Downloads/$ISO_NAME_DATED"
fi

if [[ "$COPIED_TO_PROXMOX" == true ]]; then
    info "📦 ISO disponible sur Proxmox : /var/lib/vz/template/iso/$ISO_NAME_DATED"
fi

# ========================================
# Prochaines étapes
# ========================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     📝 Prochaines étapes                           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$COPIED_TO_PROXMOX" == true ]]; then
    info "Pour utiliser l'ISO sur Proxmox:"
    echo ""
    echo -e "${YELLOW}1.${NC} Attacher à une VM:"
    echo "   ${CYAN}qm set <VMID> --ide2 local:iso/$ISO_NAME_DATED,media=cdrom${NC}"
    echo ""
    echo -e "${YELLOW}2.${NC} Démarrer et installer:"
    echo "   ${CYAN}qm start <VMID>${NC}"
    echo ""
    echo -e "${YELLOW}3.${NC} Dans l'ISO, lancer l'installation:"
    echo "   ${CYAN}sudo ./scripts/install-nixos.sh${NC}"
    echo ""
fi

if [[ "$COPIED_TO_MAC" == true ]] && [[ "$COPIED_TO_PROXMOX" == false ]]; then
    info "Pour utiliser l'ISO :"
    echo ""
    echo -e "${YELLOW}Option 1 :${NC} Uploader sur Proxmox (Web UI)"
    echo "   ${CYAN}Datacenter → Storage → local → Upload${NC}"
    echo "   ${CYAN}Sélectionner ~/Downloads/$ISO_NAME_DATED${NC}"
    echo ""
    echo -e "${YELLOW}Option 2 :${NC} Copier en ligne de commande"
    echo "   ${CYAN}scp ~/Downloads/$ISO_NAME_DATED root@192.168.1.50:/var/lib/vz/template/iso/${NC}"
    echo ""
fi
