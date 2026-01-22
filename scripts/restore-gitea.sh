#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 🔄 restore-gitea.sh - Script de restauration interactif pour Dandelion
# ==============================================================================
# Prérequis : sops, rclone, fzf, jq, yq-go, postgresql
# Usage : sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-gitea.sh
# ==============================================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEMP_DIR="/tmp/gitea-restore-$(date +%s)"
SECRETS_FILE="secrets/dandelion.yaml"
RESTORE_PATH="/var/lib/gitea"
DB_NAME="gitea"
DB_USER="gitea"
SERVICE_NAME="gitea"

# Indiquer à sops où est la clé age du système sur Dandelion
export SOPS_AGE_KEY_FILE="/var/lib/sops-nix/key.txt"

log() { echo -e "${BLUE}[RESTORE]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   🔄 RESTAURATION GITEA               ║"
echo "╚════════════════════════════════════════╝"
echo ""

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
        error "Fichier secrets/dandelion.yaml introuvable."
    fi
fi

# 2. Génération configuration Rclone temporaire via Sops
log "🔓 Déchiffrement des accès Google Drive..."
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Extraction propre avec yq (nécessite le package yq-go)
SECRETS_CONTENT=$(sops -d "$SECRETS_FILE")
CLIENT_ID=$(echo "$SECRETS_CONTENT" | yq '.google_drive.client_id // ""' -r)
CLIENT_SECRET=$(echo "$SECRETS_CONTENT" | yq '.google_drive.client_secret // ""' -r)
TOKEN=$(echo "$SECRETS_CONTENT" | yq '.google_drive.token // ""' -r)
FOLDER_ID=$(echo "$SECRETS_CONTENT" | yq '.google_drive.folder_id // ""' -r)

# Vérification que les secrets sont bien là
if [[ -z "$CLIENT_ID" ]] || [[ -z "$TOKEN" ]]; then
    error "Impossible d'extraire les identifiants Google Drive (client_id ou token vide)."
fi

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

# On récupère "Temps;Nom" (--format "tp"), on trie du plus récent au plus vieux, et on garde le nom
# Utilisation de 'sort' car 'rclone lsf' ne supporte pas le tri natif
SELECTED_FILE=$(rclone --config "$TEMP_DIR/rclone.conf" lsf gdrive:gitea \
    --files-only \
    --include "*.tar.gz" \
    --format "tp" \
    | sort -r \
    | head -n 10 \
    | cut -d';' -f2 \
    | fzf --header="🔽 SÉLECTIONNEZ LE BACKUP À RESTAURER (Enter)" \
          --prompt="Backup > " \
          --height=40% \
          --layout=reverse \
          --border)

if [[ -z "$SELECTED_FILE" ]]; then
    error "Aucun backup sélectionné. Annulation."
fi

success "Backup sélectionné : $SELECTED_FILE"

# 4. Téléchargement
log "⬇️  Téléchargement de l'archive..."
rclone --config "$TEMP_DIR/rclone.conf" copy "gdrive:gitea/$SELECTED_FILE" "$TEMP_DIR/" --progress

ARCHIVE_PATH="$TEMP_DIR/$SELECTED_FILE"

# 5. Vérification du hash (si disponible)
HASH_FILE="${SELECTED_FILE}.sha256"
log "🔍 Vérification de l'intégrité..."
if rclone --config "$TEMP_DIR/rclone.conf" ls "gdrive:gitea/$HASH_FILE" >/dev/null 2>&1; then
    rclone --config "$TEMP_DIR/rclone.conf" copy "gdrive:gitea/$HASH_FILE" "$TEMP_DIR/" --quiet
    cd "$TEMP_DIR"
    if sha256sum -c "$HASH_FILE" >/dev/null 2>&1; then
        success "Intégrité vérifiée (SHA256 OK)"
    else
        warn "Le hash SHA256 ne correspond pas. Archive peut-être corrompue."
        read -p "Continuer quand même ? (y/N) : " HASH_CONFIRM
        if [[ "$HASH_CONFIRM" != "y" ]]; then
            error "Annulation."
        fi
    fi
else
    warn "Fichier hash introuvable, vérification ignorée."
fi

# 6. Extraction de l'archive principale
log "📦 Extraction de l'archive principale..."
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"

# Trouver le dossier extrait (nom variable selon date)
EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "gitea_backup_*" | head -1)
if [[ -z "$EXTRACTED_DIR" ]]; then
    error "Dossier de backup introuvable dans l'archive."
fi

# Vérifier le contenu critique
if [[ ! -f "$EXTRACTED_DIR/gitea_database.sql" ]] || [[ ! -f "$EXTRACTED_DIR/gitea_data.tar.gz" ]]; then
    error "Archive corrompue : fichiers SQL ou Data manquants."
fi

# Afficher les métadonnées du backup
if [[ -f "$EXTRACTED_DIR/restore_config.txt" ]]; then
    echo ""
    log "📋 Informations du backup :"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -E "^(Date backup|Hostname source|Gitea version|PostgreSQL version)" "$EXTRACTED_DIR/restore_config.txt" || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

warn "⚠️  ATTENTION : Vous êtes sur le point d'écraser la base de données et les fichiers Gitea actuels."
warn "⚠️  Une fois lancé, ce processus est irréversible."
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (taper 'restore') : " CONFIRM
if [[ "$CONFIRM" != "restore" ]]; then
    error "Annulation."
fi

# 7. Arrêt du service
log "🛑 Arrêt de Gitea..."
systemctl stop "$SERVICE_NAME"
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    error "Gitea n'est pas complètement arrêté"
fi

# 8. Restauration Base de Données
log "🗄️  Restauration de PostgreSQL..."

# Vérifier si la database existe
DB_EXISTS=$(sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME" && echo "yes" || echo "no")

if [[ "$DB_EXISTS" == "yes" ]]; then
    log "  - Base existante trouvée, suppression..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" >/dev/null || error "Impossible de supprimer la base"
fi

log "  - Création de la base..."
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_USER"; then
    sudo -u postgres createuser "$DB_USER" 2>/dev/null || true
fi

sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" >/dev/null || error "Impossible de créer la base"

log "  - Import du dump SQL (patience, cela peut prendre plusieurs minutes)..."
if sudo -u postgres psql -d "$DB_NAME" < "$EXTRACTED_DIR/gitea_database.sql" >/dev/null 2>&1; then
    success "Base de données restaurée"
else
    error "Échec de l'import SQL (voir les logs ci-dessus)"
fi

# 9. Restauration Fichiers
log "📂 Restauration des données Gitea (/var/lib/gitea)..."

# Backup de sécurité des données actuelles
if [[ -d "$RESTORE_PATH" ]]; then
    BACKUP_TIMESTAMP=$(date +%s)
    log "  - Sauvegarde des données actuelles -> ${RESTORE_PATH}.backup-${BACKUP_TIMESTAMP}"
    mv "$RESTORE_PATH" "${RESTORE_PATH}.backup-${BACKUP_TIMESTAMP}"
fi

# Extraction des données
log "  - Extraction des données (patience)..."
mkdir -p /var/lib
tar -xzf "$EXTRACTED_DIR/gitea_data.tar.gz" -C "/var/lib"

success "Données restaurées"

# 10. Restauration des clés SSH
if [[ -f "$EXTRACTED_DIR/gitea_ssh_keys.tar.gz" ]]; then
    log "🔑 Restauration des clés SSH..."
    tar -xzf "$EXTRACTED_DIR/gitea_ssh_keys.tar.gz" -C "$RESTORE_PATH"
    chmod 700 "$RESTORE_PATH/.ssh" 2>/dev/null || true
    chmod 600 "$RESTORE_PATH/.ssh/"* 2>/dev/null || true
    success "Clés SSH restaurées"
else
    warn "Pas de clés SSH trouvées dans le backup"
fi

# 11. Permissions
log "👤 Correction des permissions..."
chown -R "$DB_USER:$DB_USER" "$RESTORE_PATH"
chmod 750 "$RESTORE_PATH"

# 12. Vérification de la configuration
if [[ -f "$EXTRACTED_DIR/gitea_config.ini" ]]; then
    log "⚙️  Configuration disponible dans le backup"
    if [[ -f "$RESTORE_PATH/custom/conf/app.ini" ]]; then
        log "  - Comparaison avec la config actuelle..."
        if diff -q "$EXTRACTED_DIR/gitea_config.ini" "$RESTORE_PATH/custom/conf/app.ini" >/dev/null 2>&1; then
            success "Configuration identique"
        else
            warn "Configuration différente ! Vérifiez si des ajustements sont nécessaires."
            warn "Backup config: $EXTRACTED_DIR/gitea_config.ini"
            warn "Config actuelle: $RESTORE_PATH/custom/conf/app.ini"
        fi
    fi
fi

# 13. Redémarrage
log "⚡ Redémarrage de Gitea..."
systemctl start "$SERVICE_NAME"

# Vérification simple
log "⏳ Attente du démarrage (10s)..."
sleep 10

if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Service Gitea redémarré avec succès !"
else
    warn "Le service Gitea semble avoir des problèmes. Vérifiez 'systemctl status $SERVICE_NAME'"
fi

# 14. Tests de vérification
echo ""
log "🧪 Vérifications post-restauration..."

# Test HTTP
if curl -f http://localhost:3000/ >/dev/null 2>&1; then
    success "HTTP accessible (port 3000)"
else
    warn "HTTP inaccessible, vérifiez les logs"
fi

# Test SSH
if ssh -p 2222 -o StrictHostKeyChecking=no -o ConnectTimeout=3 -T gitea@localhost 2>&1 | grep -q "Hi there"; then
    success "SSH accessible (port 2222)"
else
    warn "SSH inaccessible, vérifiez les clés et la config"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   ✅ RESTAURATION TERMINÉE            ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📊 Résumé :"
echo "  • Backup restauré : $SELECTED_FILE"
echo "  • Database : $DB_NAME"
echo "  • Données : $RESTORE_PATH"
echo "  • Service : $SERVICE_NAME"
echo ""
echo "📝 Prochaines étapes :"
echo "  1. Vérifiez les logs : journalctl -u $SERVICE_NAME -f"
echo "  2. Testez l'accès web : http://$(hostname):3000/"
echo "  3. Testez un git clone via SSH"
echo "  4. Vérifiez la configuration : cat $RESTORE_PATH/custom/conf/app.ini"
echo ""
echo "💾 Backup de sécurité des anciennes données conservé :"
echo "  ${RESTORE_PATH}.backup-* (supprimez manuellement si tout fonctionne)"
echo ""
