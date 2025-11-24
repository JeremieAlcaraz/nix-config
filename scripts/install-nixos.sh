#!/usr/bin/env bash
set -euo pipefail

# Script d'installation NixOS all-in-one
# Usage: sudo ./install-nixos.sh [magnolia|mimosa|whitelily|minimal]
#
# Ce script installe NixOS :
# - Partitionnement et formatage
# - Génération du hardware-configuration.nix
# - Clone du repo de configuration
# - Installation de NixOS
# - Arrêt automatique
#
# ⚠️  Les secrets ne sont PAS créés pendant l'installation
# Après l'installation, créez les secrets avec :
# sudo ./scripts/manage-secrets.sh [host]

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

prompt() {
    echo -e "${YELLOW}❓ $1${NC}"
}

# Vérifications initiales
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en tant que root (sudo)"
[[ ! -d /sys/firmware/efi ]] && error "Ce script nécessite un système UEFI"

# Récupérer le nom de l'host ou afficher le menu
HOST="${1:-}"

if [[ -z "$HOST" ]]; then
    # Menu interactif
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🌸 Installation NixOS - Sélection de l'host   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Hosts disponibles :${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} ${YELLOW}magnolia${NC}"
    echo -e "   🌸 Infrastructure Proxmox"
    echo -e "   → VM de base pour l'infrastructure"
    echo ""
    echo -e "${GREEN}2)${NC} ${YELLOW}mimosa${NC}"
    echo -e "   🌼 Serveur web (j12zdotcom)"
    echo -e "   → Serveur web avec Cloudflare Tunnel"
    echo ""
    echo -e "${GREEN}3)${NC} ${YELLOW}whitelily${NC}"
    echo -e "   🤍 n8n automation"
    echo -e "   → Stack complète : n8n + PostgreSQL + Caddy + Cloudflare Tunnel"
    echo ""
    echo -e "${GREEN}4)${NC} ${YELLOW}minimal${NC}"
    echo -e "   🔧 VM de démonstration minimale"
    echo -e "   → Configuration basique pour tests et démonstration"
    echo ""
    prompt "Choisissez un host (1-4) :"
    read -r choice

    case "$choice" in
        1)
            HOST="magnolia"
            ;;
        2)
            HOST="mimosa"
            ;;
        3)
            HOST="whitelily"
            ;;
        4)
            HOST="minimal"
            ;;
        *)
            error "Choix invalide. Utilisez 1, 2, 3 ou 4"
            ;;
    esac

    info "Host sélectionné : ${HOST}"
    echo ""
fi

# Vérifier que l'host est valide
if [[ "$HOST" != "magnolia" && "$HOST" != "mimosa" && "$HOST" != "whitelily" && "$HOST" != "minimal" ]]; then
    error "Host invalide. Utilisez 'magnolia', 'mimosa', 'whitelily' ou 'minimal'"
fi

# Configuration
DISK="/dev/sda"
REPO_URL="https://github.com/JeremieAlcaraz/nix-config.git"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🌸 Installation NixOS - ${HOST}${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

info "Installation de NixOS pour l'host: $HOST"
info "Disque cible: $DISK"

# Demander la branche
echo ""
read -p "Branche git à utiliser (main): " BRANCH
BRANCH="${BRANCH:-main}"
info "Branche sélectionnée: $BRANCH"

# Vérifier que le disque existe
[[ ! -b "$DISK" ]] && error "Le disque $DISK n'existe pas"

# Demander confirmation
echo ""
warning "ATTENTION: Toutes les données sur $DISK seront EFFACÉES!"
read -p "Continuer? (tapez 'oui'): " confirm
[[ "$confirm" != "oui" ]] && error "Installation annulée"

# ========================================
# Étape 1 : Nettoyage du disque
# ========================================
step "Étape 1/7 : Nettoyage du disque"

# Désactiver swap
if grep -q "$DISK" /proc/swaps 2>/dev/null; then
    warning "Désactivation du swap..."
    swapoff "${DISK}"* 2>/dev/null || true
fi

# Démonter toutes les partitions
for part in "${DISK}"*[0-9]; do
    if mountpoint -q "$part" 2>/dev/null || grep -q "$part" /proc/mounts 2>/dev/null; then
        warning "Démontage de $part..."
        umount -f "$part" 2>/dev/null || true
    fi
done

if mountpoint -q /mnt 2>/dev/null; then
    umount -R /mnt 2>/dev/null || true
fi

wipefs -af "$DISK" 2>/dev/null || true
partprobe "$DISK" 2>/dev/null || true
sleep 1

# ========================================
# Étape 2 : Partitionnement
# ========================================
step "Étape 2/7 : Partitionnement du disque"

parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart primary 513MiB 100%

partprobe "$DISK" 2>/dev/null || true
sleep 2

# ========================================
# Étape 3 : Formatage
# ========================================
step "Étape 3/7 : Formatage des partitions"

mkfs.vfat -F32 -n ESP "${DISK}1"
mkfs.ext4 -L nixos-root "${DISK}2"

udevadm settle
sleep 2

# ========================================
# Étape 4 : Montage
# ========================================
step "Étape 4/7 : Montage des partitions"

mount /dev/disk/by-label/nixos-root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/ESP /mnt/boot

lsblk -f

# ========================================
# Étape 5 : Génération hardware-configuration
# ========================================
step "Étape 5/7 : Génération de la configuration matérielle"

nixos-generate-config --root /mnt
info "Configuration matérielle générée"

# Sauvegarder hardware-configuration.nix avant de cloner
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix
info "Hardware configuration sauvegardée temporairement"

# ========================================
# Étape 6 : Clone du repo et configuration
# ========================================
step "Étape 6/7 : Clonage du dépôt et configuration"

# Configuration Nix
export NIX_CONFIG='experimental-features = nix-command flakes'

# Clone du repo
info "Clonage du dépôt..."
if [[ -d /mnt/etc/nixos ]]; then
    rm -rf /mnt/etc/nixos
fi
git clone --branch "$BRANCH" "$REPO_URL" /mnt/etc/nixos

# Copier le hardware-configuration.nix au bon endroit
info "Placement de hardware-configuration.nix pour ${HOST}..."
mkdir -p "/mnt/etc/nixos/hosts/${HOST}"
cp /tmp/hardware-configuration.nix "/mnt/etc/nixos/hosts/${HOST}/hardware-configuration.nix"
info "Hardware configuration placée dans hosts/${HOST}/"

# Vérifier et configurer la clé age pour sops
if [[ ! -f /var/lib/sops-nix/key.txt ]]; then
    echo ""
    warning "Clé age sops non trouvée"
    info "Pour chiffrer les secrets, vous pouvez fournir votre clé age maintenant"
    echo ""
    prompt "Voulez-vous fournir la clé age ? (oui/non, défaut: non):"
    read -r provide_age_key

    if [[ "$provide_age_key" == "oui" ]]; then
        echo ""
        info "Collez votre clé age (format: AGE-SECRET-KEY-1...)"
        info "La clé ne sera PAS affichée pour des raisons de sécurité"
        echo ""
        prompt "Clé age :"
        read -rs AGE_KEY  # -s pour masquer la saisie
        echo ""  # Nouvelle ligne après la saisie masquée

        if [[ -n "$AGE_KEY" ]]; then
            # Créer le répertoire et le fichier
            mkdir -p /var/lib/sops-nix
            echo "$AGE_KEY" > /var/lib/sops-nix/key.txt
            chmod 600 /var/lib/sops-nix/key.txt

            # Vérifier que la clé a le bon format
            if grep -q "AGE-SECRET-KEY-1" /var/lib/sops-nix/key.txt; then
                info "Clé age configurée avec succès"

                # Copier aussi dans le système cible
                mkdir -p /mnt/var/lib/sops-nix
                cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
                chmod 600 /mnt/var/lib/sops-nix/key.txt
            else
                warning "Format de clé invalide, la clé ne sera pas utilisée"
                rm -f /var/lib/sops-nix/key.txt
            fi
        else
            info "Aucune clé fournie, les secrets ne seront pas chiffrés"
        fi
    else
        info "Installation sans chiffrement sops"
    fi
fi

# ========================================
# Gestion des secrets (toujours reportée)
# ========================================
step "Gestion des secrets"

info "Les secrets ne sont PAS créés pendant l'installation"
warning "⚠️  Séparation des responsabilités : build/install ≠ gestion des secrets"
echo ""
echo -e "${YELLOW}Après l'installation, vous devrez créer les secrets avec :${NC}"
echo ""
echo "  ${CYAN}cd /etc/nixos${NC}"
echo "  ${CYAN}sudo ./scripts/manage-secrets.sh ${HOST}${NC}"
echo ""
echo -e "${YELLOW}Puis déployer la configuration :${NC}"
echo "  ${CYAN}sudo nixos-rebuild switch --flake .#${HOST}${NC}"
echo ""

# Copier la clé age si elle existe pour une utilisation future
if [[ -f /var/lib/sops-nix/key.txt ]]; then
    mkdir -p /mnt/var/lib/sops-nix
    cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
    chmod 600 /mnt/var/lib/sops-nix/key.txt
    info "Clé age copiée (prête pour manage-secrets.sh)"
fi

# Si des secrets existent déjà dans le repo, les utiliser
SECRETS_PATH="/mnt/etc/nixos/secrets/${HOST}.yaml"
if [[ -f "$SECRETS_PATH" ]] && grep -q "sops:" "$SECRETS_PATH" 2>/dev/null; then
    info "Secrets existants trouvés dans le repo (chiffrés)"
    info "Vous pourrez les mettre à jour plus tard avec manage-secrets.sh"
else
    # Sinon, copier le fichier d'exemple comme placeholder
    if [[ -f "/mnt/etc/nixos/secrets/${HOST}.yaml.example" ]]; then
        cp "/mnt/etc/nixos/secrets/${HOST}.yaml.example" "$SECRETS_PATH"
        info "Fichier d'exemple copié (contient des placeholders)"
    else
        warning "Aucun fichier de secrets trouvé pour ${HOST}"
        warning "L'installation va continuer mais les secrets devront être créés après"
    fi
fi

# ========================================
# Étape 7 : Installation de NixOS
# ========================================
step "Étape 7/7 : Installation de NixOS"

cd /mnt/etc/nixos

info "Installation en cours (cela peut prendre plusieurs minutes)..."
nixos-install --flake ".#${HOST}" --no-root-passwd

if [[ "${HOST}" == "mimosa" ]]; then
    echo ""
    info "ℹ️  Le webserver j12zdotcom est DÉSACTIVÉ par défaut"
    info "Pour l'activer après l'installation :"
    info "  1. Éditez /etc/nixos/flake.nix"
    info "  2. Changez: mimosa.webserver.enable = false → true"
    info "  3. sudo nixos-rebuild switch --flake .#mimosa"
fi

# ========================================
# Finalisation
# ========================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🎉 Installation réussie !${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

info "Host installé : ${HOST}"

if [[ -f /mnt/var/lib/sops-nix/key.txt ]]; then
    info "🔐 Clé age copiée (prête pour la gestion des secrets)"
else
    warning "Clé age non trouvée"
fi

echo ""
warning "⚠️  IMPORTANT : Les secrets ne sont PAS encore configurés"
echo ""
info "Prochaines étapes :"
echo ""
echo -e "${CYAN}1.${NC} Détacher l'ISO : ${YELLOW}qm set <VMID> --ide2 none${NC}"
echo -e "${CYAN}2.${NC} Redémarrer la VM : ${YELLOW}qm start <VMID>${NC}"
echo -e "${CYAN}3.${NC} Se connecter en root : ${YELLOW}ssh root@<IP>${NC}"
echo ""
echo -e "${CYAN}4.${NC} Créer les secrets :"
echo "   ${YELLOW}cd /etc/nixos${NC}"
echo "   ${YELLOW}./scripts/manage-secrets.sh ${HOST}${NC}"
echo ""
echo -e "${CYAN}5.${NC} Déployer la configuration :"
echo "   ${YELLOW}nixos-rebuild switch --flake .#${HOST}${NC}"
echo ""
echo -e "${CYAN}6.${NC} Se reconnecter avec l'utilisateur normal :"
echo "   ${YELLOW}ssh jeremie@<IP>${NC}"
echo ""

# Arrêt automatique
info "La VM va s'éteindre dans 10 secondes..."
info "Appuyez sur Ctrl+C pour annuler."
for i in {10..1}; do
    echo -ne "${YELLOW}⏱️  Arrêt dans ${i}s...${NC}\r"
    sleep 1
done
echo ""

info "🔌 Arrêt de la VM..."
sync
poweroff
