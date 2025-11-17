#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 🔄 restore-n8n.sh - Script de restauration interactif pour Whitelily
# ==============================================================================
# Prérequis : sops, rclone, fzf, jq, postgresql, podman
# Usage : sudo nix-shell -p sops rclone fzf jq --run ./scripts/restore-n8n.sh
# ==============================================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEMP_DIR="/tmp/n8n-restore-$(date +%s)"
SECRETS_FILE="secrets/whitelily.yaml"
RESTORE_PATH="/var/lib/n8n"
DB_NAME="n8n"
DB_USER="n8n"
SERVICE_NAME="podman-n8n"

# Indiquer à sops où est la clé age du système sur Whitelily
export SOPS_AGE_KEY_FILE="/var/lib/sops-nix/key.txt"

log() { echo -e "${BLUE}[RESTORE]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# 1. Vérifications initiales
if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être exécuté en tant que root (sudo)"
fi

if [[ ! -f "$SOPS_AGE_KEY_FILE" ]]; then
    error "Clé Age introuvable à l'emplacement : $SOPS_AGE_KEY_FILE"
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
    # Essayer de trouver le fichier si on n'est pas à la racine
    if [[ -f "../$SECRETS_FILE" ]]; then
        SECRETS_FILE="../$SECRETS_FILE"
    elif [[ -f "/etc/nixos/$SECRETS_FILE" ]]; then
        SECRETS_FILE="/etc/nixos/$SECRETS_FILE"
    else
        error "Fichier secrets/whitelily.yaml introuvable."
    fi
fi

# 2. Génération configuration Rclone temporaire via Sops
log "🔓 Déchiffrement des accès Google Drive..."
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Extraction des secrets (fallback awk si yq manquant)
SECRETS_CONTENT=$(sops -d "$SECRETS_FILE")
CLIENT_ID=$(echo "$SECRETS_CONTENT" | grep "client_id:" | head -1 | sed 's/.*: "\(.*\)"/\1/' | tr -d '"')
CLIENT_SECRET=$(echo "$SECRETS_CONTENT" | grep "client_secret:" | head -1 | sed 's/.*: "\(.*\)"/\1/' | tr -d '"')
# Le token est souvent sur plusieurs lignes ou complexe, on prend la ligne brute
TOKEN=$(echo "$SECRETS_CONTENT" | grep "token:" | head -1 | sed "s/.*token: '\(.*\)'/\1/") 
if [[ -z "$TOKEN" ]]; then
     # Tentative format double quotes
     TOKEN=$(echo "$SECRETS_CONTENT" | grep "token:" | head -1 | sed 's/.*token: "\(.*\)"/\1/')
fi
FOLDER_ID=$(echo "$SECRETS_CONTENT" | grep "folder_id:" | head -1 | sed 's/.*: "\(.*\)"/\1/' | tr -d '"')

# Création config rclone
cat > "$TEMP_DIR/rclone.conf" <<EOF
[gdrive]
type = drive
scope = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
token = $TOKEN
root_folder_id = $FOLDER_ID
EOF

# 3. Listing et Sélection (FZF)
log "☁️  Récupération de la liste des backups..."

# Liste les 5 derniers fichiers .tar.gz, triés par date (plus récent en haut)
# format: path, size, modification time
SELECTED_FILE=$(rclone --config "$TEMP_DIR/rclone.conf" lsf gdrive:backups/n8n \
    --files-only \
    --include "*.tar.gz" \
    --sort-by t \
    --format "pt" \
    | head -n 5 \
    | fzf --header="🔽 SÉLECTIONNEZ LE BACKUP À RESTAURER (Enter)" \
          --prompt="Backup > " \
          --height=40% \
          --layout=reverse \
          --border \
    | awk '{print $1}')

if [[ -z "$SELECTED_FILE" ]]; then
    error "Aucun backup sélectionné. Annulation."
fi

success "Backup sélectionné : $SELECTED_FILE"

# 4. Téléchargement
log "⬇️  Téléchargement de l'archive..."
rclone --config "$TEMP_DIR/rclone.conf" copy "gdrive:backups/n8n/$SELECTED_FILE" "$TEMP_DIR/" --progress

ARCHIVE_PATH="$TEMP_DIR/$SELECTED_FILE"

# 5. Extraction de l'archive principale
log "📦 Extraction de l'archive principale..."
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"

# Trouver le dossier extrait (nom variable selon date)
EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "n8n_migration_backup_*" | head -1)
if [[ -z "$EXTRACTED_DIR" ]]; then
    error "Dossier de backup introuvable dans l'archive."
fi

# Vérifier le contenu critique
if [[ ! -f "$EXTRACTED_DIR/n8n_database_backup.sql" ]] || [[ ! -f "$EXTRACTED_DIR/n8n_data_real.tar.gz" ]]; then
    error "Archive corrompue : fichiers SQL ou Data manquants."
fi

warn "⚠️  ATTENTION : Vous êtes sur le point d'écraser la base de données et les fichiers n8n actuels."
warn "⚠️  Une fois lancé, ce processus est irréversible."
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (taper 'restore') : " CONFIRM
if [[ "$CONFIRM" != "restore" ]]; then
    error "Annulation."
fi

# 6. Arrêt du service
log "🛑 Arrêt de n8n..."
systemctl stop "$SERVICE_NAME"

# 7. Restauration Base de Données
log "🗄️  Restauration de PostgreSQL..."

# On utilise sudo -u postgres pour éviter les soucis de password
if sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" >/dev/null; then
    log "  - Base existante supprimée"
else
    error "Impossible de supprimer la base"
fi

if sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" >/dev/null; then
    log "  - Nouvelle base créée"
else
    error "Impossible de créer la base"
fi

log "  - Import du dump SQL (patience)..."
if sudo -u postgres psql -d "$DB_NAME" < "$EXTRACTED_DIR/n8n_database_backup.sql" >/dev/null; then
    success "Base de données restaurée"
else
    error "Échec de l'import SQL"
fi

# 8. Restauration Fichiers
log "📂 Restauration des fichiers (/var/lib/n8n)..."

# Nettoyage dossier existant (sécurité)
rm -rf "${RESTORE_PATH:?}/"*
rm -rf "${RESTORE_PATH:?}/".* 2>/dev/null || true

# Extraction des données
tar -xzf "$EXTRACTED_DIR/n8n_data_real.tar.gz" -C "/var/lib"

# 9. Permissions
log "👤 Correction des permissions..."
# UID 1000 est l'user standard du container n8n (node)
chown -R 1000:1000 "$RESTORE_PATH"
chmod -R 750 "$RESTORE_PATH"

# 10. Redémarrage
log "⚡ Redémarrage de n8n..."
systemctl start "$SERVICE_NAME"

# Vérification simple
log "⏳ Attente du démarrage (10s)..."
sleep 10
if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Service n8n redémarré avec succès !"
else
    warn "Le service n8n semble avoir des problèmes. Vérifiez 'systemctl status $SERVICE_NAME'"
fi

echo ""
echo "==================================================="
echo "🎉 Restauration terminée !"
echo "👉 Vérifiez les logs : journalctl -u $SERVICE_NAME -f"
echo "👉 Clé d'encryption utilisée : voir $EXTRACTED_DIR/migration_config.txt (dans le dossier temp si besoin)"
echo "==================================================="