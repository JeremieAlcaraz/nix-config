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

# 1. Partitionnement
info "Étape 1/7: Partitionnement du disque..."
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart primary 513MiB 100%

# Attendre que les partitions soient reconnues
sleep 2

# 2. Formatage avec labels STANDARDISÉS
info "Étape 2/7: Formatage des partitions..."
mkfs.vfat -F32 -n ESP "${DISK}1"
mkfs.ext4 -L nixos-root "${DISK}2"

# Attendre que udev reconnaisse les nouveaux labels
udevadm settle
sleep 2

# 3. Montage
info "Étape 3/7: Montage des partitions..."
mount /dev/disk/by-label/nixos-root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/ESP /mnt/boot

# Vérification
lsblk -f

# 4. Activer les flakes
info "Étape 4/7: Configuration de Nix..."
export NIX_CONFIG='experimental-features = nix-command flakes'

# 5. Cloner le repo
info "Étape 5/7: Clonage du dépôt..."
if [[ -d /mnt/etc/nixos ]]; then
    rm -rf /mnt/etc/nixos
fi
git clone --branch "$BRANCH" "$REPO_URL" /mnt/etc/nixos

# 6. Installation
info "Étape 6/7: Installation de NixOS (cela peut prendre plusieurs minutes)..."
cd /mnt/etc/nixos
nixos-install --flake ".#${HOST}" --no-root-passwd

# 7. Finalisation
info "Étape 7/7: Installation terminée!"
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
info "Mot de passe initial de l'utilisateur 'jeremie': nixos"
info "⚠️  Changez-le immédiatement avec: passwd"
info ""
