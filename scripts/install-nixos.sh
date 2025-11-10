#!/usr/bin/env bash
set -euo pipefail

# Script d'installation NixOS 100% reproductible
# Usage: sudo ./install-nixos.sh [proxmox|jeremie-web]

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Vérifications initiales
[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en tant que root (sudo)"
[[ ! -d /sys/firmware/efi ]] && error "Ce script nécessite un système UEFI"

# Récupérer le nom de l'host (proxmox ou jeremie-web)
HOST="${1:-}"
if [[ -z "$HOST" ]]; then
    error "Usage: sudo $0 [proxmox|jeremie-web]"
fi

if [[ "$HOST" != "proxmox" && "$HOST" != "jeremie-web" ]]; then
    error "Host invalide. Utilisez 'proxmox' ou 'jeremie-web'"
fi

# Configuration
DISK="/dev/sda"
REPO_URL="https://github.com/JeremieAlcaraz/nix-config.git"
BRANCH="main"

info "Installation de NixOS pour l'host: $HOST"
info "Disque cible: $DISK"

# Vérifier que le disque existe
[[ ! -b "$DISK" ]] && error "Le disque $DISK n'existe pas"

# Demander confirmation
warning "ATTENTION: Toutes les données sur $DISK seront EFFACÉES!"
read -p "Êtes-vous sûr de vouloir continuer? (tapez 'oui' pour confirmer): " confirm
[[ "$confirm" != "oui" ]] && error "Installation annulée"

# 0. Nettoyage du disque (évite les erreurs "partition in use")
info "Étape 0/8: Nettoyage du disque..."

# Désactiver le swap s'il est actif sur ce disque
if grep -q "$DISK" /proc/swaps 2>/dev/null; then
    warning "Désactivation du swap sur $DISK..."
    swapoff "${DISK}"* 2>/dev/null || true
fi

# Démonter toutes les partitions du disque cible
for part in "${DISK}"*[0-9]; do
    if mountpoint -q "$part" 2>/dev/null || grep -q "$part" /proc/mounts 2>/dev/null; then
        warning "Démontage de $part..."
        umount -f "$part" 2>/dev/null || true
    fi
done

# Démonter /mnt et ses sous-montages si nécessaire
if mountpoint -q /mnt 2>/dev/null; then
    warning "Démontage de /mnt..."
    umount -R /mnt 2>/dev/null || true
fi

# Effacer toutes les signatures de système de fichiers (empêche le kernel de les reconnaître)
warning "Effacement des signatures de système de fichiers..."
wipefs -af "$DISK" 2>/dev/null || true

# S'assurer que le kernel oublie l'ancienne table de partitions
partprobe "$DISK" 2>/dev/null || true
sleep 1

# 1. Partitionnement
info "Étape 1/7: Partitionnement du disque..."
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart primary 513MiB 100%

# Forcer le kernel à relire la nouvelle table de partitions
partprobe "$DISK" 2>/dev/null || true

# Attendre que les partitions soient reconnues
sleep 2

# 2. Formatage avec labels STANDARDISÉS
info "Étape 2/8: Formatage des partitions..."
mkfs.vfat -F32 -n ESP "${DISK}1"
mkfs.ext4 -L nixos-root "${DISK}2"

# Attendre que udev reconnaisse les nouveaux labels
udevadm settle
sleep 2

# 3. Montage
info "Étape 3/8: Montage des partitions..."
mount /dev/disk/by-label/nixos-root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/ESP /mnt/boot

# Vérification
lsblk -f

# 4. Activer les flakes
info "Étape 4/8: Configuration de Nix..."
export NIX_CONFIG='experimental-features = nix-command flakes'

# 5. Cloner le repo
info "Étape 5/8: Clonage du dépôt..."
if [[ -d /mnt/etc/nixos ]]; then
    rm -rf /mnt/etc/nixos
fi
git clone --branch "$BRANCH" "$REPO_URL" /mnt/etc/nixos

# 6. Copier la clé SOPS dans le système cible si elle existe
if [[ -f /var/lib/sops-nix/key.txt ]]; then
    info "Copie de la clé SOPS dans le système cible..."
    mkdir -p /mnt/var/lib/sops-nix
    cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
    chmod 600 /mnt/var/lib/sops-nix/key.txt
else
    warning "Aucune clé SOPS trouvée dans /var/lib/sops-nix/key.txt. Les secrets chiffrés ne seront PAS déchiffrés pendant l'installation."
fi

# 7. Installation
info "Étape 6/8: Installation de NixOS (cela peut prendre plusieurs minutes)..."
cd /mnt/etc/nixos
nixos-install --flake ".#${HOST}" --no-root-passwd

# 8. Finalisation
info "Étape 7/8: Installation terminée!"
info ""
info "=========================================="
info "🎉 Installation réussie!"
info "=========================================="
info ""
info "Prochaines étapes:"
info "1. Retirer l'ISO d'installation dans Proxmox"
info "2. Redémarrer la VM: reboot"
info "3. Se connecter via SSH: ssh jeremie@<IP>"
info ""
info "Pour trouver l'IP après le boot:"
info "  ip a"
info ""
if [[ -f /mnt/var/lib/sops-nix/key.txt ]]; then
    info "🔐 Les secrets SOPS ont été déchiffrés avec succès"
    info "Le mot de passe de l'utilisateur 'jeremie' a été configuré via SOPS"
else
    warning "Mot de passe initial de l'utilisateur 'jeremie': nixos"
    warning "⚠️  Changez-le immédiatement avec: passwd"
fi
info ""
