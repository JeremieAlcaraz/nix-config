#!/usr/bin/env bash
set -euo pipefail

# Script d'installation NixOS 100% reproductible
# Usage: sudo ./install-nixos.sh [magnolia|mimosa]

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

# Récupérer le nom de l'host (magnolia ou mimosa)
HOST="${1:-}"
if [[ -z "$HOST" ]]; then
    error "Usage: sudo $0 [magnolia|mimosa]"
fi

if [[ "$HOST" != "magnolia" && "$HOST" != "mimosa" ]]; then
    error "Host invalide. Utilisez 'magnolia' (infrastructure Proxmox) ou 'mimosa' (serveur web)"
fi

# Configuration
DISK="/dev/sda"
REPO_URL="https://github.com/JeremieAlcaraz/nix-config.git"

info "Installation de NixOS pour l'host: $HOST"
info "Disque cible: $DISK"

# Demander la branche à utiliser
echo ""
read -p "Branche git à utiliser (main): " BRANCH
BRANCH="${BRANCH:-main}"
info "Branche sélectionnée: $BRANCH"

# Demander le mode d'installation pour mimosa
if [[ "$HOST" == "mimosa" ]]; then
    echo ""
    warning "Mode d'installation pour mimosa:"
    echo "  1. Installation complète (avec le serveur web j12zdotcom)"
    echo "  2. Installation minimale (sans le serveur web - recommandé si problèmes réseau)"
    echo ""
    read -p "Choisissez le mode (1/2, défaut: 1): " INSTALL_MODE
    INSTALL_MODE="${INSTALL_MODE:-1}"

    if [[ "$INSTALL_MODE" == "2" ]]; then
        export NIXOS_MINIMAL_INSTALL="true"
        info "Mode minimal sélectionné - le serveur web sera désactivé pendant l'installation"
        info "Après l'installation, vous pourrez l'activer avec:"
        info "  sudo nixos-rebuild switch"
    else
        info "Mode complet sélectionné - installation du serveur web j12zdotcom"
    fi
fi

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

# 4. Activer les flakes et configurer DNS
info "Étape 4/8: Configuration de Nix et DNS..."

# Configurer des DNS publics fiables pour éviter les erreurs EAI_AGAIN
info "Configuration des DNS publics (Cloudflare et Google)..."

# Retirer la protection immutable du fichier si elle existe
chattr -i /etc/resolv.conf 2>/dev/null || true

# Stopper resolvconf s'il tourne (pour éviter qu'il réécrive /etc/resolv.conf)
if systemctl is-active resolvconf > /dev/null 2>&1; then
    warning "Arrêt temporaire de resolvconf pour configurer les DNS publics..."
    systemctl stop resolvconf 2>/dev/null || true
fi

# Écrire la configuration DNS
cat > /etc/resolv.conf << EOF
# DNS publics temporaires pour l'installation NixOS
# resolvconf a été temporairement désactivé
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Protéger le fichier contre l'écriture par resolvconf
chattr +i /etc/resolv.conf 2>/dev/null || true

info "DNS publics configurés (protégés contre modification)"

# Tester la résolution DNS
info "Test de résolution DNS..."
if ! timeout 5 nslookup registry.npmjs.org > /dev/null 2>&1; then
    warning "La résolution DNS ne fonctionne pas correctement!"
    warning "L'installation risque d'échouer si des téléchargements npm sont nécessaires"
    echo ""
    warning "Pour diagnostiquer le problème réseau, exécutez:"
    warning "  sudo ./diagnose-network.sh"
    echo ""
    read -p "Continuer quand même? (oui/non): " continue_anyway
    if [[ "$continue_anyway" != "oui" ]]; then
        error "Installation annulée. Résolvez les problèmes réseau d'abord."
    fi
else
    success "Résolution DNS fonctionnelle"
fi

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

# Passer la variable d'environnement NIXOS_MINIMAL_INSTALL au build si définie
if [[ "${NIXOS_MINIMAL_INSTALL:-}" == "true" ]]; then
    info "Installation en mode minimal (sans serveur web)..."
    NIXOS_MINIMAL_INSTALL=true nixos-install --flake ".#${HOST}" --no-root-passwd
else
    nixos-install --flake ".#${HOST}" --no-root-passwd
fi

# 8. Finalisation
info "Étape 7/8: Installation terminée!"
info ""
info "=========================================="
info "🎉 Installation réussie!"
info "=========================================="
info ""

if [[ -f /mnt/var/lib/sops-nix/key.txt ]]; then
    info "🔐 Les secrets SOPS ont été déchiffrés avec succès"
    info "Le mot de passe de l'utilisateur 'jeremie' a été configuré via SOPS"
else
    warning "Mot de passe initial de l'utilisateur 'jeremie': nixos"
    warning "⚠️  Changez-le immédiatement avec: passwd"
fi
info ""

# Message spécifique pour l'installation minimale de mimosa
if [[ "$HOST" == "mimosa" && "${NIXOS_MINIMAL_INSTALL:-}" == "true" ]]; then
    info "=========================================="
    info "📝 Installation minimale - Étapes suivantes"
    info "=========================================="
    info ""
    info "Le serveur web j12zdotcom a été désactivé pendant l'installation."
    info "Pour l'activer après le premier boot:"
    info ""
    info "1. Connectez-vous via SSH:"
    info "   ssh jeremie@<IP>"
    info ""
    info "2. Activez le serveur web:"
    info "   sudo nixos-rebuild switch"
    info ""
    info "Le système téléchargera et activera le serveur web."
    info ""
fi

# 9. Arrêt automatique
info "Étape 8/8: Préparation de l'arrêt..."
info ""
warning "⚠️  IMPORTANT: Avant de redémarrer la VM, détachez l'ISO d'installation!"
info ""
info "Depuis l'hôte Proxmox, exécutez (remplacez VMID par le numéro de votre VM):"
info "  qm set VMID --ide2 none"
info ""
info "Ou via l'interface web Proxmox:"
info "  Hardware > CD/DVD Drive > Remove"
info ""
info "Puis redémarrez la VM:"
info "  qm start VMID"
info ""
info "Connexion SSH après le boot:"
info "  ssh jeremie@<IP>"
info ""

# Countdown avant l'arrêt
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
