#!/usr/bin/env bash
set -euo pipefail

# Script d'installation NixOS all-in-one
# Usage: sudo ./install-nixos.sh [host|--list|--help]
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

# Prompt helper
prompt() {
    echo -e "${YELLOW}❓ $1${NC}"
}

# Chemins relatifs et catalogues
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOSTS_ROOT="${REPO_ROOT}/hosts"
INSTALL_HOSTS_FILE="${SCRIPT_DIR}/install-hosts.tsv"

declare -A METADATA_TARGET=()
declare -A METADATA_LABEL=()
declare -A METADATA_DESC=()
declare -A METADATA_HIDDEN=()

declare -A INSTALL_TARGET=()
declare -A INSTALL_LABEL=()
declare -A INSTALL_DESC=()
declare -A INSTALL_HIDDEN=()
declare -A INSTALL_EXISTS=()

declare -a METADATA_ORDER=()
declare -a AUTO_HOSTS=()
declare -a MENU_ORDER=()
declare -a VISIBLE_HOST_IDS=()

usage() {
    echo ""
    echo -e "${CYAN}Usage:${NC} sudo ./scripts/install-nixos.sh [host|--list|--help]"
    echo "Sans argument, un menu interactif liste les hôtes décrits dans ${INSTALL_HOSTS_FILE}."
    echo "Utilisez ${YELLOW}--list${NC} pour afficher toutes les cibles (y compris les masquées) ou ${YELLOW}--help${NC} pour ce message."
    echo ""
}

list_install_hosts() {
    if [[ ${#MENU_ORDER[@]} -eq 0 ]]; then
        error "Aucun host disponible (répertoire ${HOSTS_ROOT} vide ou catalogue invalide)."
    fi
    echo ""
    echo -e "${BLUE}Hosts reconnus pour l'installation :${NC}"
    for id in "${MENU_ORDER[@]}"; do
        local label="${INSTALL_LABEL[$id]:-$id}"
        local desc="${INSTALL_DESC[$id]}"
        local hidden="${INSTALL_HIDDEN[$id]:-false}"
        local marker=""
        if [[ "${hidden,,}" == "true" ]]; then
            marker=" (masqué)"
        fi
        echo -e "  ${YELLOW}${id}${marker}${NC} → ${label}"
        [[ -n "$desc" ]] && echo "       ${desc}"
    done
    echo ""
}

load_install_catalog() {
    METADATA_TARGET=()
    METADATA_LABEL=()
    METADATA_DESC=()
    METADATA_HIDDEN=()
    INSTALL_TARGET=()
    INSTALL_LABEL=()
    INSTALL_DESC=()
    INSTALL_HIDDEN=()
    INSTALL_EXISTS=()
    METADATA_ORDER=()
    AUTO_HOSTS=()
    MENU_ORDER=()
    VISIBLE_HOST_IDS=()

    if [[ ! -d "$HOSTS_ROOT" ]]; then
        error "Répertoire des hosts introuvable : ${HOSTS_ROOT}"
    fi

    if [[ -f "$INSTALL_HOSTS_FILE" ]]; then
        while IFS=$'\t' read -r id target label description hidden tailscale_ip; do
            [[ -z "$id" || "${id:0:1}" == "#" ]] && continue
            METADATA_ORDER+=("$id")
            METADATA_TARGET["$id"]="${target:-$id}"
            METADATA_LABEL["$id"]="${label:-$id}"
            METADATA_DESC["$id"]="${description:-}"
            METADATA_HIDDEN["$id"]="${hidden:-false}"
        done < <(sed 's/\r$//' "$INSTALL_HOSTS_FILE")
    fi

    set +e
    local nullglob_backup
    nullglob_backup="$(shopt -p nullglob)"
    set -e

    shopt -s nullglob
    for host_path in "${HOSTS_ROOT}"/*; do
        [[ -d "$host_path" ]] || continue
        local host_name
        host_name="$(basename "$host_path")"
        [[ -f "${host_path}/configuration.nix" ]] || continue
        INSTALL_TARGET["$host_name"]="${METADATA_TARGET[$host_name]:-$host_name}"
        INSTALL_LABEL["$host_name"]="${METADATA_LABEL[$host_name]:-$host_name}"
        INSTALL_DESC["$host_name"]="${METADATA_DESC[$host_name]:-}"
        INSTALL_HIDDEN["$host_name"]="${METADATA_HIDDEN[$host_name]:-false}"
        INSTALL_EXISTS["$host_name"]=1
        AUTO_HOSTS+=("$host_name")
    done

    if [[ -n "$nullglob_backup" ]]; then
        eval "$nullglob_backup"
    else
        shopt -u nullglob
    fi

    for id in "${METADATA_ORDER[@]}"; do
        [[ -n "${INSTALL_EXISTS[$id]:-}" ]] && continue
        local target="${METADATA_TARGET[$id]:-$id}"
        INSTALL_TARGET["$id"]="$target"
        INSTALL_LABEL["$id"]="${METADATA_LABEL[$id]:-$id}"
        INSTALL_DESC["$id"]="${METADATA_DESC[$id]:-}"
        INSTALL_HIDDEN["$id"]="${METADATA_HIDDEN[$id]:-false}"
        INSTALL_EXISTS["$id"]=1
        if [[ "$target" != "$id" && -z "${INSTALL_EXISTS[$target]:-}" ]]; then
            warning "La cible ${id} référence l'hôte ${target} qui n'existe pas sous ${HOSTS_ROOT}"
        fi
    done

    for id in "${METADATA_ORDER[@]}"; do
        [[ -n "${INSTALL_EXISTS[$id]:-}" ]] && MENU_ORDER+=("$id")
    done

    for host_name in "${AUTO_HOSTS[@]}"; do
        if [[ ! " ${MENU_ORDER[*]} " =~ " ${host_name} " ]]; then
            MENU_ORDER+=("$host_name")
        fi
    done

    for id in "${MENU_ORDER[@]}"; do
        local hidden="${INSTALL_HIDDEN[$id]:-false}"
        if [[ "${hidden,,}" == "true" ]]; then
            continue
        fi
        VISIBLE_HOST_IDS+=("$id")
    done

    if [[ ${#MENU_ORDER[@]} -eq 0 ]]; then
        error "Aucun host valide trouvé dans ${HOSTS_ROOT}"
    fi
}

select_host_interactively() {
    if [[ ${#VISIBLE_HOST_IDS[@]} -eq 0 ]]; then
        error "Aucun host visible disponible. Utilisez --list pour voir les cibles cachées."
    fi

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     🌸 Installation NixOS - Sélection de l'host   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Hosts disponibles :${NC}"
    echo ""

    for idx in "${!VISIBLE_HOST_IDS[@]}"; do
        local id="${VISIBLE_HOST_IDS[idx]}"
        local label="${INSTALL_LABEL[$id]:-$id}"
        local desc="${INSTALL_DESC[$id]}"
        echo -e "${GREEN}$((idx+1)))${NC} ${YELLOW}${label}${NC}"
        [[ -n "$desc" ]] && echo "   ${desc}"
        echo ""
    done

    prompt "Choisissez un host (1-${#VISIBLE_HOST_IDS[@]}) :"
    read -r choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#VISIBLE_HOST_IDS[@]} )); then
        error "Choix invalide. Utilisez un numéro entre 1 et ${#VISIBLE_HOST_IDS[@]}."
    fi

    HOST="${VISIBLE_HOST_IDS[choice-1]}"
    echo ""
}

HOST_ARG="${1:-}"
load_install_catalog

case "$HOST_ARG" in
    -h|--help)
        usage
        exit 0
        ;;
    -l|--list)
        list_install_hosts
        exit 0
        ;;
    "")
        select_host_interactively
        ;;
    *)
        HOST="${HOST_ARG,,}"
        ;;
esac

if [[ -z "${HOST:-}" ]]; then
    select_host_interactively
fi

if [[ -z "${INSTALL_EXISTS[$HOST]:-}" ]]; then
    error "Host '${HOST}' inconnu. Utilisez --list pour voir les cibles disponibles."
fi

HOST_DIR="${INSTALL_TARGET[$HOST]:-$HOST}"

info "Host sélectionné : ${HOST}"

[[ $EUID -ne 0 ]] && error "Ce script doit être exécuté en tant que root (sudo)"
[[ ! -d /sys/firmware/efi ]] && error "Ce script nécessite un système UEFI"

# Configuration
DISK="/dev/sda"
GITEA_HOST="dandelion"  # Résolu via DNS (la VM n'a pas encore Tailscale)
REPO_URL="${NIX_CONFIG_REPO_URL:-http://${GITEA_HOST}:3000/jeremiealcaraz/nix-config.git}"

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

# Remplacer les UUID par des labels stables pour éviter les problèmes au reboot
# (le disque root est formaté avec -L nixos-root et l'ESP avec -n ESP)
sed -i 's|/dev/disk/by-uuid/[0-9a-f-]\{36\}";.*# root|/dev/disk/by-label/nixos-root";|' /mnt/etc/nixos/hardware-configuration.nix
# Remplacement par label pour la partition root ext4 (UUID 8 groupes hexadécimaux)
ROOT_UUID=$(blkid -s UUID -o value "${DISK}2" 2>/dev/null || true)
if [[ -n "$ROOT_UUID" ]]; then
    sed -i "s|/dev/disk/by-uuid/${ROOT_UUID}|/dev/disk/by-label/nixos-root|g" /mnt/etc/nixos/hardware-configuration.nix
    info "UUID root remplacé par /dev/disk/by-label/nixos-root"
fi

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
# Note: mimosa-bootstrap utilise le même dossier que mimosa
HOST_DIR="${HOST}"
if [[ "${HOST}" == "mimosa-bootstrap" ]]; then
    HOST_DIR="mimosa"
fi

info "Placement de hardware-configuration.nix pour ${HOST}..."
mkdir -p "/mnt/etc/nixos/hosts/${HOST_DIR}"
cp /tmp/hardware-configuration.nix "/mnt/etc/nixos/hosts/${HOST_DIR}/hardware-configuration.nix"
info "Hardware configuration placée dans hosts/${HOST_DIR}/"

# ========================================
# Push du hardware-configuration.nix vers Gitea (optionnel)
# ========================================
echo ""
prompt "Voulez-vous push le hardware-configuration.nix vers Gitea ? (oui/non, défaut: non):"
read -r push_to_gitea

if [[ "$push_to_gitea" == "oui" ]]; then
    echo ""
    info "Pour push vers Gitea, vous avez besoin d'un token d'accès."
    info "Créez-le dans Gitea : Settings > Applications > Generate New Token"
    echo ""
    prompt "Token Gitea (ne sera pas affiché) :"
    read -rs GITEA_TOKEN
    echo ""

    if [[ -n "$GITEA_TOKEN" ]]; then
        cd /mnt/etc/nixos

        # Configuration git pour le commit
        git config user.email "installer@nix-config.local"
        git config user.name "NixOS Installer"

        # Ajouter et commiter le hardware-configuration.nix
        git add "hosts/${HOST_DIR}/hardware-configuration.nix"

        if git diff --cached --quiet; then
            info "Aucun changement à commiter (hardware-configuration.nix identique)"
        else
            git commit -m "Add hardware-configuration.nix for ${HOST}

Generated during NixOS installation on $(date '+%Y-%m-%d %H:%M')"

            # Push avec le token
            GITEA_PUSH_URL="http://jeremiealcaraz:${GITEA_TOKEN}@${GITEA_HOST}:3000/jeremiealcaraz/nix-config.git"

            if git push "$GITEA_PUSH_URL" "${BRANCH}"; then
                info "hardware-configuration.nix pushé vers Gitea avec succès"
            else
                warning "Échec du push vers Gitea (vérifiez le token et la connectivité)"
                warning "Le fichier est toujours présent localement"
            fi
        fi

        cd /
    else
        info "Aucun token fourni, push ignoré"
    fi
else
    info "Push vers Gitea ignoré"
fi

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
# Note: mimosa-bootstrap utilise les secrets de mimosa
SECRETS_HOST="${HOST_DIR}"
SECRETS_PATH="/mnt/etc/nixos/secrets/${SECRETS_HOST}.yaml"
if [[ -f "$SECRETS_PATH" ]] && grep -q "sops:" "$SECRETS_PATH" 2>/dev/null; then
    info "Secrets existants trouvés dans le repo (chiffrés)"
    info "Vous pourrez les mettre à jour plus tard avec manage-secrets.sh"
else
    # Sinon, copier le fichier d'exemple comme placeholder
    if [[ -f "/mnt/etc/nixos/secrets/${SECRETS_HOST}.yaml.example" ]]; then
        cp "/mnt/etc/nixos/secrets/${SECRETS_HOST}.yaml.example" "$SECRETS_PATH"
        info "Fichier d'exemple copié (contient des placeholders)"
    else
        warning "Aucun fichier de secrets trouvé pour ${SECRETS_HOST}"
        warning "L'installation va continuer mais les secrets devront être créés après"
    fi
fi

# ========================================
# Étape 7 : Installation de NixOS
# ========================================
step "Étape 7/7 : Installation de NixOS"

cd /mnt/etc/nixos

info "Installation en cours (cela peut prendre plusieurs minutes)..."
info "Mode verbose activé pour voir les détails du téléchargement..."
nixos-install --flake ".#${HOST}" --no-root-passwd -v

if [[ "${HOST}" == "mimosa-bootstrap" ]]; then
    echo ""
    info "ℹ️  Installation bootstrap - Le webserver j12zdotcom n'est PAS installé"
    info "Pour activer le webserver en mode production après l'installation :"
    info "  1. Rebootez et connectez-vous"
    info "  2. cd /etc/nixos"
    info "  3. sudo nixos-rebuild switch --flake .#mimosa"
    echo ""
    info "Note : L'activation du webserver téléchargera et compilera j12zdotcom (~8GB RAM requis)"
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
echo "   ${YELLOW}./scripts/manage-secrets.sh ${SECRETS_HOST}${NC}"
echo ""
echo -e "${CYAN}5.${NC} Déployer la configuration :"
if [[ "${HOST}" == "mimosa-bootstrap" ]]; then
    echo "   ${YELLOW}# Pour passer en production avec webserver :${NC}"
    echo "   ${YELLOW}nixos-rebuild switch --flake .#mimosa${NC}"
    echo ""
    echo "   ${YELLOW}# OU pour rester en mode bootstrap :${NC}"
    echo "   ${YELLOW}nixos-rebuild switch --flake .#${HOST}${NC}"
else
    echo "   ${YELLOW}nixos-rebuild switch --flake .#${HOST}${NC}"
fi
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
