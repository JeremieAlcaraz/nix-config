#!/usr/bin/env bash
set -euo pipefail

# ========================================
# Script de backup complet n8n
# Crée une structure de backup organisée
# ========================================

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT_DIR="${HOME}/Downloads"
BACKUP_NESTED_DIR="n8n_migration_backup_${BACKUP_DATE}"
BACKUP_ARCHIVE="n8n_migration_${BACKUP_DATE}.tar.gz"
BACKUP_HASH="${BACKUP_ARCHIVE}.sha256"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🔄 BACKUP COMPLET n8n               ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}📅 Date: ${BACKUP_DATE}${NC}"
echo -e "${YELLOW}📁 Destination: ${BACKUP_ROOT_DIR}/${NC}"
echo ""

# Créer le dossier nested
mkdir -p "${BACKUP_ROOT_DIR}/${BACKUP_NESTED_DIR}"
cd "${BACKUP_ROOT_DIR}/${BACKUP_NESTED_DIR}"

# ========================================
# Étape 1 : Récupération des variables d'environnement
# ========================================
echo -e "${BLUE}[1/7]${NC} 🔍 Récupération des variables d'environnement..."

# Vérifier que n8n tourne
if ! sudo podman ps | grep -q n8n; then
    echo -e "${RED}⚠️  ATTENTION: Le container n8n ne semble pas actif${NC}"
    echo "Voulez-vous continuer ? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Backup annulé."
        exit 1
    fi
fi

# Extraire les variables d'environnement
sudo podman inspect n8n --format='{{range .Config.Env}}{{println .}}{{end}}' > n8n_env_vars.txt

echo -e "${GREEN}✓${NC} Variables d'environnement récupérées"

# ========================================
# Étape 2 : Récupération de la clé d'encryption
# ========================================
echo -e "${BLUE}[2/7]${NC} 🔐 Récupération de la clé d'encryption..."

# Plusieurs méthodes pour récupérer la clé
ENCRYPTION_KEY=""

# Méthode 1 : Depuis le fichier de config n8n
if sudo podman exec n8n test -f /home/node/.n8n/config 2>/dev/null; then
    ENCRYPTION_KEY=$(sudo podman exec n8n cat /home/node/.n8n/config 2>/dev/null | grep -o '"encryptionKey":"[^"]*"' | cut -d'"' -f4)
fi

# Méthode 2 : Depuis les variables d'environnement
if [ -z "$ENCRYPTION_KEY" ]; then
    ENCRYPTION_KEY=$(grep "N8N_ENCRYPTION_KEY=" n8n_env_vars.txt | cut -d= -f2 || echo "")
fi

# Méthode 3 : Depuis le fichier env sur l'hôte
if [ -z "$ENCRYPTION_KEY" ] && [ -f /run/n8n/n8n.env ]; then
    ENCRYPTION_KEY=$(sudo grep "N8N_ENCRYPTION_KEY=" /run/n8n/n8n.env | cut -d= -f2 || echo "")
fi

if [ -z "$ENCRYPTION_KEY" ]; then
    echo -e "${RED}⚠️  ERREUR: Impossible de récupérer la clé d'encryption !${NC}"
    echo "Veuillez la saisir manuellement (elle sera sauvegardée dans migration_config.txt) :"
    read -r ENCRYPTION_KEY
fi

echo -e "${GREEN}✓${NC} Clé d'encryption récupérée (${#ENCRYPTION_KEY} caractères)"

# ========================================
# Étape 3 : Arrêt de n8n pour cohérence des données
# ========================================
echo -e "${BLUE}[3/7]${NC} ⏸️  Arrêt de n8n pour garantir la cohérence..."

sudo systemctl stop podman-n8n.service
sleep 2

if sudo podman ps | grep -q n8n; then
    echo -e "${RED}⚠️  n8n n'est pas complètement arrêté !${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} n8n arrêté"

# ========================================
# Étape 4 : Backup de la base PostgreSQL
# ========================================
echo -e "${BLUE}[4/7]${NC} 💾 Backup de la base de données PostgreSQL..."

# Extraction des paramètres DB
DB_NAME=$(grep "DB_POSTGRESDB_DATABASE=" n8n_env_vars.txt | cut -d= -f2 || echo "n8n_db")
DB_USER=$(grep "DB_POSTGRESDB_USER=" n8n_env_vars.txt | cut -d= -f2 || echo "n8n_user")
DB_HOST=$(grep "DB_POSTGRESDB_HOST=" n8n_env_vars.txt | cut -d= -f2 || echo "postgresql")
DB_PORT=$(grep "DB_POSTGRESDB_PORT=" n8n_env_vars.txt | cut -d= -f2 || echo "5432")
DB_PASSWORD=$(grep "DB_POSTGRESDB_PASSWORD=" n8n_env_vars.txt | cut -d= -f2 || echo "")

echo "  Base: ${DB_NAME}"
echo "  Utilisateur: ${DB_USER}"

# Dump PostgreSQL
sudo -u postgres pg_dump "${DB_NAME}" > n8n_database_backup.sql

DB_SIZE=$(ls -lh n8n_database_backup.sql | awk '{print $5}')
echo -e "${GREEN}✓${NC} Base de données sauvegardée (${DB_SIZE})"

# ========================================
# Étape 5 : Backup des fichiers n8n
# ========================================
echo -e "${BLUE}[5/7]${NC} 📦 Backup des fichiers n8n (community nodes, configs)..."

# Trouver le chemin des données
N8N_DATA_PATH=$(sudo podman inspect n8n 2>/dev/null | grep -A 5 "Mounts" | grep "Source" | grep n8n | sed 's/.*"Source": "\(.*\)",/\1/' | head -1)

if [ -z "$N8N_DATA_PATH" ]; then
    N8N_DATA_PATH="/var/lib/n8n"
fi

echo "  Chemin: ${N8N_DATA_PATH}"

# Vérifier que le chemin existe
if [ ! -d "$N8N_DATA_PATH" ]; then
    echo -e "${RED}⚠️  Le répertoire n8n n'existe pas: ${N8N_DATA_PATH}${NC}"
    exit 1
fi

# Backup du répertoire
sudo tar czf n8n_data_real.tar.gz -C "$(dirname "$N8N_DATA_PATH")" "$(basename "$N8N_DATA_PATH")"

DATA_SIZE=$(ls -lh n8n_data_real.tar.gz | awk '{print $5}')
echo -e "${GREEN}✓${NC} Fichiers n8n sauvegardés (${DATA_SIZE})"

# ========================================
# Étape 6 : Création du fichier de configuration
# ========================================
echo -e "${BLUE}[6/7]${NC} 📝 Création du fichier de configuration..."

# Extraction des infos importantes
N8N_HOST=$(grep "N8N_HOST=" n8n_env_vars.txt | cut -d= -f2 || echo "n8n.jeremiealcaraz.com")
N8N_PROTOCOL=$(grep "N8N_PROTOCOL=" n8n_env_vars.txt | cut -d= -f2 || echo "https")
N8N_PORT=$(grep "N8N_PORT=" n8n_env_vars.txt | cut -d= -f2 || echo "5678")
WEBHOOK_URL=$(grep "WEBHOOK_URL=" n8n_env_vars.txt | cut -d= -f2 || echo "https://n8n.jeremiealcaraz.com/")
TIMEZONE=$(grep "GENERIC_TIMEZONE=" n8n_env_vars.txt | cut -d= -f2 || echo "Europe/Berlin")
NODE_VERSION=$(grep "NODE_VERSION=" n8n_env_vars.txt | cut -d= -f2 || echo "22.21.0")

# Version PostgreSQL
PG_VERSION=$(sudo -u postgres psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "15")

# Créer le fichier de config
cat > migration_config.txt << EOF
# ================================================================
# CONFIGURATION N8N - BACKUP DU ${BACKUP_DATE}
# ================================================================
# IMPORTANT: Ce fichier contient la clé d'encryption qui est
#            CRITIQUE pour décrypter les credentials.
#            Sauvegardez ce fichier dans un gestionnaire de
#            mots de passe sécurisé !
# ================================================================

Date backup: ${BACKUP_DATE}
Hostname source: $(hostname)

# ----------------------------------------------------------------
# Base de données PostgreSQL
# ----------------------------------------------------------------
DB_TYPE=postgresdb
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# ----------------------------------------------------------------
# Configuration n8n
# ----------------------------------------------------------------
N8N_HOST=${N8N_HOST}
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_PORT=${N8N_PORT}
WEBHOOK_URL=${WEBHOOK_URL}
TIMEZONE=${TIMEZONE}

# ----------------------------------------------------------------
# CLÉ D'ENCRYPTION (CRITIQUE - NE PAS PERDRE !)
# ----------------------------------------------------------------
# Cette clé est nécessaire pour décrypter les credentials.
# Elle doit être IDENTIQUE sur la nouvelle installation.
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# ----------------------------------------------------------------
# Versions des composants
# ----------------------------------------------------------------
PostgreSQL: ${PG_VERSION}
Node: ${NODE_VERSION}

# ----------------------------------------------------------------
# Community Nodes installés
# ----------------------------------------------------------------
EOF

# Lister les community nodes si disponibles
if sudo test -f "${N8N_DATA_PATH}/nodes/package.json" 2>/dev/null; then
    echo "# Packages détectés dans nodes/package.json:" >> migration_config.txt
    sudo cat "${N8N_DATA_PATH}/nodes/package.json" | grep -A 20 '"dependencies"' >> migration_config.txt 2>/dev/null || echo "# Aucun package détecté" >> migration_config.txt
else
    echo "# Aucun community node détecté" >> migration_config.txt
fi

echo -e "${GREEN}✓${NC} Fichier de configuration créé"

# ========================================
# Création du README de migration
# ========================================
cat > MIGRATION_README.txt << 'EOF'
# ================================================================
# README - BACKUP DE MIGRATION N8N
# ================================================================

Ce backup contient tous les éléments nécessaires pour restaurer
n8n sur une nouvelle installation.

## Contenu du backup

1. **n8n_database_backup.sql** (136 MB)
   - Dump complet de la base PostgreSQL
   - Contient : workflows, credentials, executions, tags, etc.

2. **n8n_data_real.tar.gz** (35 MB)
   - Fichiers de données n8n
   - Contient : community nodes, configs, SSH keys, binary data

3. **migration_config.txt** (500 bytes)
   - Configuration complète avec la clé d'encryption
   - ⚠️  FICHIER CRITIQUE - contient la clé pour décrypter les credentials

4. **n8n_env_vars.txt** (570 bytes)
   - Variables d'environnement du container n8n

5. **MIGRATION_README.txt** (ce fichier)
   - Instructions de restauration

## ⚠️  IMPORTANT : Clé d'encryption

La clé d'encryption dans `migration_config.txt` est ABSOLUMENT
NÉCESSAIRE pour restaurer les credentials. Sans cette clé, vous
perdrez l'accès à tous vos identifiants API, tokens, etc.

➡️  Sauvegardez `migration_config.txt` dans un gestionnaire de
    mots de passe sécurisé (1Password, Bitwarden, etc.)

## 📖 Restauration

Pour restaurer ce backup sur une nouvelle VM, suivez le guide
complet dans le document `n8n-backup-restore-guide.md`, section
"PARTIE 3 : Restauration sur la nouvelle VM".

Points clés :
- Configurer la MÊME clé d'encryption dans sops-nix
- Restaurer la base PostgreSQL
- Restaurer les fichiers n8n
- Ajuster les permissions (UID 1000)
- Vérifier les variables d'environnement

## 🔍 Vérification de l'intégrité

Un hash SHA256 est fourni pour vérifier l'intégrité du backup :

    sha256sum -c n8n_migration_*.tar.gz.sha256

Doit afficher : OK

## 📊 Statistiques du backup

Utilisez ces commandes pour voir le contenu :

    # Voir les fichiers dans l'archive
    tar tzf n8n_migration_*.tar.gz

    # Extraire l'archive
    tar xzf n8n_migration_*.tar.gz

    # Voir le nombre d'éléments dans la base
    grep -c "COPY public.workflow_entity" n8n_database_backup.sql

## 🆘 Support

En cas de problème, consultez la section "Troubleshooting" du
guide complet ou vérifiez les logs :

    journalctl -u podman-n8n.service -n 100

EOF

echo -e "${GREEN}✓${NC} README de migration créé"

# ========================================
# Étape 7 : Compression et hash
# ========================================
echo -e "${BLUE}[7/7]${NC} 🗜️  Compression et création du hash..."

# Retour au dossier parent
cd "${BACKUP_ROOT_DIR}"

# Créer l'archive finale
tar czf "${BACKUP_ARCHIVE}" "${BACKUP_NESTED_DIR}/"

# Créer le hash SHA256
sha256sum "${BACKUP_ARCHIVE}" > "${BACKUP_HASH}"

# Tailles finales
ARCHIVE_SIZE=$(ls -lh "${BACKUP_ARCHIVE}" | awk '{print $5}')
HASH_CONTENT=$(cat "${BACKUP_HASH}")

echo -e "${GREEN}✓${NC} Archive créée (${ARCHIVE_SIZE})"
echo -e "${GREEN}✓${NC} Hash SHA256 généré"

# ========================================
# Redémarrage de n8n
# ========================================
echo ""
echo -e "${YELLOW}⚡ Redémarrage de n8n...${NC}"
sudo systemctl start podman-n8n.service
sleep 3

if sudo podman ps | grep -q n8n; then
    echo -e "${GREEN}✓${NC} n8n redémarré avec succès"
else
    echo -e "${RED}⚠️  Problème au redémarrage de n8n !${NC}"
    echo "Vérifiez les logs : journalctl -u podman-n8n.service -n 50"
fi

# ========================================
# Résumé final
# ========================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ BACKUP TERMINÉ AVEC SUCCÈS       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Fichiers créés :${NC}"
echo ""
echo -e "  ${YELLOW}Archive principale :${NC}"
echo -e "    📦 ${BACKUP_ARCHIVE} (${ARCHIVE_SIZE})"
echo ""
echo -e "  ${YELLOW}Hash d'intégrité :${NC}"
echo -e "    🔐 ${BACKUP_HASH}"
echo ""
echo -e "  ${YELLOW}Contenu du backup (nested) :${NC}"
cd "${BACKUP_NESTED_DIR}"
ls -lh | tail -n +2 | while read -r line; do
    echo -e "    📄 ${line}"
done
cd "${BACKUP_ROOT_DIR}"
echo ""

echo -e "${BLUE}🔐 Hash SHA256 :${NC}"
echo "    ${HASH_CONTENT}"
echo ""

echo -e "${YELLOW}📝 Prochaines étapes :${NC}"
echo ""
echo "  1. Vérifier l'intégrité du backup :"
echo -e "     ${BLUE}cd ~/Downloads && sha256sum -c ${BACKUP_HASH}${NC}"
echo ""
echo "  2. Sauvegarder la clé d'encryption :"
echo -e "     ${BLUE}cat ${BACKUP_NESTED_DIR}/migration_config.txt | grep ENCRYPTION${NC}"
echo ""
echo "  3. Transférer le backup sur votre machine locale (optionnel) :"
echo -e "     ${BLUE}scp $(hostname):~/Downloads/${BACKUP_ARCHIVE}* ~/Downloads/${NC}"
echo ""
echo "  4. Pour restaurer, suivre le guide :"
echo "     Section 'PARTIE 3 : Restauration sur la nouvelle VM'"
echo ""

echo -e "${GREEN}🎉 Backup réussi !${NC}"
echo ""
