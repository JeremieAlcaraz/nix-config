#!/usr/bin/env bash
set -euo pipefail

# Script d'installation NixOS all-in-one
# Usage: sudo ./install-nixos.sh [magnolia|mimosa|whitelily]
#
# Ce script fait TOUT :
# - Partitionnement et formatage
# - Génération du hardware-configuration.nix
# - Clone du repo de configuration
# - Génération interactive des secrets si nécessaire
# - Installation de NixOS
# - Arrêt automatique

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
    prompt "Choisissez un host (1-3) :"
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
        *)
            error "Choix invalide. Utilisez 1, 2 ou 3"
            ;;
    esac

    info "Host sélectionné : ${HOST}"
    echo ""
fi

# Vérifier que l'host est valide
if [[ "$HOST" != "magnolia" && "$HOST" != "mimosa" && "$HOST" != "whitelily" ]]; then
    error "Host invalide. Utilisez 'magnolia', 'mimosa' ou 'whitelily'"
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
# Fonction de génération des secrets
# ========================================
generate_secrets() {
    local host="$1"
    local secrets_file="/tmp/secrets-${host}.yaml"

    step "Configuration des secrets pour ${host}"

    info "Génération des secrets..."

    # Secret commun à tous les hosts : mot de passe jeremie
    prompt "Entrez le mot de passe pour l'utilisateur 'jeremie' (SSH) :"
    JEREMIE_HASH=$(mkpasswd -m sha-512)

    case "$host" in
        magnolia)
            # Magnolia : juste le mot de passe jeremie
            cat > "$secrets_file" <<EOF
# Secrets pour magnolia (infrastructure Proxmox)
# Généré automatiquement par install-nixos.sh

jeremie-password-hash: ${JEREMIE_HASH}
EOF
            ;;

        mimosa)
            # Mimosa : mot de passe + token cloudflare
            echo ""
            info "Configuration Cloudflare Tunnel pour mimosa"
            echo "1. Allez sur https://one.dash.cloudflare.com/"
            echo "2. Zero Trust → Access → Tunnels"
            echo "3. Créez un tunnel (ou utilisez un existant)"
            echo "4. Copiez le TOKEN (la longue chaîne après --token)"
            echo ""
            prompt "Collez le token Cloudflare Tunnel :"
            read -r CF_TOKEN

            cat > "$secrets_file" <<EOF
# Secrets pour mimosa (serveur web)
# Généré automatiquement par install-nixos.sh

jeremie-password-hash: ${JEREMIE_HASH}

cloudflare-tunnel-token: "${CF_TOKEN}"
EOF
            ;;

        whitelily)
            # Whitelily : mot de passe + secrets n8n + cloudflare credentials JSON
            echo ""
            info "Configuration n8n pour whitelily"

            # Génération automatique des secrets n8n
            N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
            N8N_BASIC_PASS=$(openssl rand -base64 24)
            DB_PASSWORD=$(openssl rand -base64 32)

            warning "⚠️  IMPORTANT : Clé de chiffrement n8n"
            echo "Cette clé chiffre TOUTES vos credentials n8n."
            echo -e "${YELLOW}N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}${NC}"
            echo "Sauvegardez-la dans un gestionnaire de mots de passe !"
            echo ""
            read -p "Appuyez sur Entrée une fois sauvegardée..."

            echo ""
            prompt "Nom d'utilisateur pour n8n (défaut: admin):"
            read -r N8N_USER
            N8N_USER="${N8N_USER:-admin}"

            echo ""
            prompt "Domaine complet pour n8n (ex: n8n.votredomaine.com):"
            read -r DOMAIN
            [[ -z "$DOMAIN" ]] && error "Le domaine ne peut pas être vide"

            echo ""
            info "Configuration Cloudflare Tunnel"
            echo "1. Allez sur https://one.dash.cloudflare.com/"
            echo "2. Zero Trust → Access → Tunnels"
            echo "3. Créez un tunnel nommé : n8n-whitelily"
            echo "4. Configurez la route publique :"
            echo "   - Hostname: ${DOMAIN}"
            echo "   - Service: http://localhost:80"
            echo "5. Copiez le JSON complet des credentials"
            echo ""
            prompt "Collez le JSON des credentials Cloudflare (puis ligne vide pour terminer) :"
            CLOUDFLARED_CREDS=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                CLOUDFLARED_CREDS+="$line"$'\n'
            done

            # Valider le JSON
            if ! echo "$CLOUDFLARED_CREDS" | jq . &>/dev/null; then
                error "Le JSON des credentials Cloudflare est invalide"
            fi

            cat > "$secrets_file" <<EOF
# Secrets pour whitelily (VM n8n automation)
# Généré automatiquement par install-nixos.sh

jeremie-password-hash: ${JEREMIE_HASH}

n8n:
  encryption_key: "${N8N_ENCRYPTION_KEY}"
  basic_user: "${N8N_USER}"
  basic_pass: "${N8N_BASIC_PASS}"
  db_password: "${DB_PASSWORD}"

cloudflared:
  credentials: |
    ${CLOUDFLARED_CREDS}
EOF

            # Sauvegarder le domaine pour la configuration
            echo "$DOMAIN" > /tmp/whitelily-domain.txt

            info "Résumé de la configuration n8n :"
            echo "  • Domaine          : ${DOMAIN}"
            echo "  • Utilisateur      : ${N8N_USER}"
            echo "  • Mot de passe     : ${N8N_BASIC_PASS}"
            echo "  • Clé chiffrement  : ${N8N_ENCRYPTION_KEY}"
            echo ""
            warning "Sauvegardez ces informations !"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
    esac

    info "Fichier de secrets créé : $secrets_file"

    # Copier vers le système cible plus tard
    export SECRETS_FILE="$secrets_file"
}

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

# Toujours demander si on veut regénérer les secrets
SECRETS_PATH="/mnt/etc/nixos/secrets/${HOST}.yaml"

echo ""
if [[ -f "$SECRETS_PATH" ]] && ! grep -q "REMPLACER_PAR" "$SECRETS_PATH" 2>/dev/null; then
    info "Secrets existants trouvés pour ${HOST}"
    prompt "Voulez-vous les regénérer ? (oui/non, défaut: non):"
    read -r regenerate_secrets

    if [[ "$regenerate_secrets" != "oui" ]]; then
        info "Utilisation des secrets existants"
        SKIP_SECRET_GENERATION=true
    fi
fi

if [[ "${SKIP_SECRET_GENERATION:-false}" != "true" ]]; then
    warning "Génération interactive des secrets pour ${HOST}"
    info "Vous allez définir le mot de passe SSH pour cet host"
    echo ""

    # Installer les outils nécessaires temporairement
    nix-shell -p sops age openssl mkpasswd jq --run "$(declare -f generate_secrets error info warning step prompt); generate_secrets ${HOST}"

    # Chiffrer les secrets avec sops
    if [[ -f "$SECRETS_FILE" ]]; then
        info "Chiffrement des secrets avec sops..."

        # Copier la clé age si elle existe
        if [[ -f /var/lib/sops-nix/key.txt ]]; then
            mkdir -p /mnt/var/lib/sops-nix
            cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
            chmod 600 /mnt/var/lib/sops-nix/key.txt

            SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops encrypt "$SECRETS_FILE" > "$SECRETS_PATH"

            # Vérifier que c'est bien chiffré
            if grep -q "sops:" "$SECRETS_PATH"; then
                info "Secrets chiffrés avec succès"
            else
                error "Échec du chiffrement des secrets"
            fi
        else
            warning "Clé age non trouvée, copie du fichier non chiffré"
            warning "ATTENTION : Les secrets ne sont PAS chiffrés !"
            cp "$SECRETS_FILE" "$SECRETS_PATH"
        fi

        # Si whitelily, mettre à jour le domaine dans n8n.nix
        if [[ "$HOST" == "whitelily" ]] && [[ -f /tmp/whitelily-domain.txt ]]; then
            DOMAIN=$(cat /tmp/whitelily-domain.txt)
            sed -i "s|domain = \".*\";|domain = \"${DOMAIN}\";|" "/mnt/etc/nixos/hosts/whitelily/n8n.nix"
            info "Domaine mis à jour dans n8n.nix : ${DOMAIN}"
        fi
    fi
else
    info "Secrets existants trouvés pour ${HOST}"

    # Copier la clé age si elle existe
    if [[ -f /var/lib/sops-nix/key.txt ]]; then
        mkdir -p /mnt/var/lib/sops-nix
        cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
        chmod 600 /mnt/var/lib/sops-nix/key.txt
        info "Clé sops copiée"
    fi
fi

# ========================================
# Étape 7 : Installation de NixOS
# ========================================
step "Étape 7/7 : Installation de NixOS"

cd /mnt/etc/nixos

info "Installation en cours (cela peut prendre plusieurs minutes)..."
nixos-install --flake ".#${HOST}" --no-root-passwd

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
    info "🔐 Les secrets SOPS ont été déchiffrés"
else
    warning "Clé sops non trouvée"
fi

echo ""
info "Prochaines étapes :"
echo "1. Détacher l'ISO : qm set <VMID> --ide2 none"
echo "2. Redémarrer la VM : qm start <VMID>"
echo "3. Se connecter : ssh jeremie@<IP>"
echo ""

if [[ "$HOST" == "whitelily" ]]; then
    echo -e "${YELLOW}📝 Pour whitelily (n8n) :${NC}"
    echo "   Accédez à https://$(cat /tmp/whitelily-domain.txt 2>/dev/null || echo 'votre-domaine.com')"
    echo ""
fi

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
