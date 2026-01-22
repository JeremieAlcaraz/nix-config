# Module NixOS pour le backup automatisé Gitea
# Fichier : hosts/dandelion/gitea-backup.nix
#
# Ce module gère le backup automatique de Gitea vers Google Drive
# avec logging dans Notion et notifications par email/Slack

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitea-backup;

  # Script de backup principal
  backupScript = pkgs.writeShellScript "gitea-backup-automated.sh" ''
    set -euo pipefail

    # ================================================================
    # SCRIPT DE BACKUP AUTOMATISÉ GITEA
    # ================================================================

    # Configuration depuis les options du module
    BACKUP_DIR="${cfg.backupDir}"
    RCLONE_CONFIG_PATH="/run/gitea-backup/rclone.conf"
    RCLONE_REMOTE="gdrive"
    GDRIVE_BACKUP_FOLDER="${cfg.gdrivePath}"
    LOG_FILE="${cfg.logFile}"
    HOSTNAME=$(${pkgs.nettools}/bin/hostname)

    # Charger les secrets depuis sops-nix
    NOTION_API_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."notion/api_token".path})
    NOTION_DATABASE_ID=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."notion/database_id_gitea".path})
    GMAIL_FROM=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gmail/from".path})
    GMAIL_TO=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gmail/to".path})
    GMAIL_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gmail/app_password".path})
    SLACK_WEBHOOK=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."slack/webhook_url".path})
    GDRIVE_FOLDER_ID=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."google_drive/folder_id".path})

    # Variables du backup
    BACKUP_DATE=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
    BACKUP_NESTED_DIR="gitea_backup_''${BACKUP_DATE}"
    BACKUP_ARCHIVE="gitea_backup_''${BACKUP_DATE}.tar.gz"
    BACKUP_HASH="''${BACKUP_ARCHIVE}.sha256"
    STATUS="success"
    ERROR_MESSAGE=""
    START_TIME=$(${pkgs.coreutils}/bin/date +%s)

    # ----------------------------------------------------------------
    # FONCTIONS UTILITAIRES
    # ----------------------------------------------------------------

    log() {
        echo "[$(${pkgs.coreutils}/bin/date +'%Y-%m-%d %H:%M:%S')] $1" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
    }

    error_exit() {
        local message="$1"
        ERROR_MESSAGE="$message"
        STATUS="failed"
        log "❌ ERREUR: $message"
        send_notifications "failed"
        exit 1
    }

    send_slack_notification() {
        local status="$1"
        local emoji="✅"
        local color="good"

        if [ "$status" = "failed" ]; then
            emoji="❌"
            color="danger"
        fi

        local duration=$(($(${pkgs.coreutils}/bin/date +%s) - START_TIME))
        local archive_size="N/A"
        if [ -f "$BACKUP_DIR/$BACKUP_ARCHIVE" ]; then
            archive_size=$(${pkgs.coreutils}/bin/ls -lh "$BACKUP_DIR/$BACKUP_ARCHIVE" | ${pkgs.gawk}/bin/awk '{print $5}')
        fi

        ${pkgs.coreutils}/bin/cat > /tmp/slack_payload.json << EOF
    {
      "attachments": [
        {
          "color": "$color",
          "blocks": [
            {
              "type": "header",
              "text": {
                "type": "plain_text",
                "text": "$emoji Backup Gitea - $HOSTNAME"
              }
            },
            {
              "type": "section",
              "fields": [
                {
                  "type": "mrkdwn",
                  "text": "*Status:*\n$status"
                },
                {
                  "type": "mrkdwn",
                  "text": "*Date:*\n$(date +'%Y-%m-%d %H:%M:%S')"
                },
                {
                  "type": "mrkdwn",
                  "text": "*Taille:*\n$archive_size"
                },
                {
                  "type": "mrkdwn",
                  "text": "*Durée:*\n''${duration}s"
                }
              ]
            }
          ]
        }
      ]
    }
    EOF

        ${pkgs.curl}/bin/curl -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d @/tmp/slack_payload.json \
            || log "⚠️ Échec d'envoi à Slack"

        ${pkgs.coreutils}/bin/rm -f /tmp/slack_payload.json
    }

    send_error_email() {
        log "📧 Envoi de l'email d'erreur..."

        ${pkgs.coreutils}/bin/cat > /tmp/email_body.txt << EOF
    Subject: ⚠️ Erreur Backup Gitea - $HOSTNAME
    From: ''${GMAIL_FROM}
    To: ''${GMAIL_TO}
    Content-Type: text/html; charset=UTF-8

    <html>
    <body>
    <h2>⚠️ Erreur lors du backup Gitea</h2>

    <p><strong>Serveur:</strong> $HOSTNAME</p>
    <p><strong>Date:</strong> $(date +'%Y-%m-%d %H:%M:%S')</p>
    <p><strong>Status:</strong> ❌ ÉCHEC</p>

    <h3>Message d'erreur:</h3>
    <pre style="background: #f5f5f5; padding: 10px; border-radius: 5px;">
    ''${ERROR_MESSAGE}
    </pre>

    <h3>Dernières lignes du log:</h3>
    <pre style="background: #f5f5f5; padding: 10px; border-radius: 5px;">
    $(${pkgs.coreutils}/bin/tail -20 "$LOG_FILE" 2>/dev/null || echo "Log non disponible")
    </pre>

    <p>Veuillez vérifier le serveur.</p>
    </body>
    </html>
    EOF

        ${pkgs.curl}/bin/curl -s --url "smtp://smtp.gmail.com:587" \
            --ssl-reqd \
            --mail-from "''${GMAIL_FROM}" \
            --mail-rcpt "''${GMAIL_TO}" \
            --user "''${GMAIL_FROM}:''${GMAIL_PASSWORD}" \
            --upload-file /tmp/email_body.txt \
            || log "⚠️ Échec d'envoi de l'email"

        ${pkgs.coreutils}/bin/rm -f /tmp/email_body.txt
    }

    log_to_notion() {
        local status="$1"
        local gdrive_url="$2"
        local file_size="$3"
        local duration="$4"

        log "📝 Enregistrement dans Notion..."

        # Mapper le status pour Notion
        local notion_status="completed"
        if [ "$status" = "failed" ]; then
            notion_status="failed"
        fi

        ${pkgs.coreutils}/bin/cat > /tmp/notion_payload.json << EOF
    {
      "parent": { "database_id": "''${NOTION_DATABASE_ID}" },
      "properties": {
        "filename": {
          "title": [
            {
              "text": {
                "content": "''${BACKUP_ARCHIVE}"
              }
            }
          ]
        },
        "date": {
          "date": {
            "start": "$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%S.000Z)"
          }
        },
        "status": {
          "select": {
            "name": "''${notion_status}"
          }
        },
        "server": {
          "rich_text": [
            {
              "text": {
                "content": "$HOSTNAME"
              }
            }
          ]
        },
        "size": {
          "rich_text": [
            {
              "text": {
                "content": "''${file_size}"
              }
            }
          ]
        },
        "duration": {
          "rich_text": [
            {
              "text": {
                "content": "''${duration}s"
              }
            }
          ]
        },
        "gdrive_link": {
          "url": "''${gdrive_url}"
        }
      }
    }
    EOF

        ${pkgs.curl}/bin/curl -X POST "https://api.notion.com/v1/pages" \
            -H "Authorization: Bearer ''${NOTION_API_KEY}" \
            -H "Content-Type: application/json" \
            -H "Notion-Version: 2022-06-28" \
            -d @/tmp/notion_payload.json \
            || log "⚠️ Échec d'envoi à Notion"

        ${pkgs.coreutils}/bin/rm -f /tmp/notion_payload.json
    }

    send_notifications() {
        local status="$1"

        if [ "$status" = "failed" ]; then
            send_error_email
            send_slack_notification "failed"
        else
            local duration=$(($(${pkgs.coreutils}/bin/date +%s) - START_TIME))
            local archive_size=$(${pkgs.coreutils}/bin/ls -lh "$BACKUP_DIR/$BACKUP_ARCHIVE" | ${pkgs.gawk}/bin/awk '{print $5}')
            local gdrive_url="https://drive.google.com/drive/folders/''${GDRIVE_FOLDER_ID}"

            log_to_notion "success" "''${gdrive_url}" "''${archive_size}" "''${duration}"
            send_slack_notification "success"
        fi
    }

    # ----------------------------------------------------------------
    # DÉBUT DU BACKUP
    # ----------------------------------------------------------------

    log "╔════════════════════════════════════════╗"
    log "║   🔄 BACKUP AUTOMATISÉ GITEA          ║"
    log "╚════════════════════════════════════════╝"
    log ""
    log "📅 Date: ''${BACKUP_DATE}"
    log "🖥️  Serveur: $HOSTNAME"
    log ""

    # ----------------------------------------------------------------
    # ÉTAPE 1 : Préparation
    # ----------------------------------------------------------------
    log "[1/14] 📁 Préparation des dossiers..."

    ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR" || error_exit "Impossible de créer le dossier de backup principal"
    cd "$BACKUP_DIR"
    ${pkgs.coreutils}/bin/mkdir -p "''${BACKUP_NESTED_DIR}" || error_exit "Impossible de créer le dossier de backup"
    cd "''${BACKUP_NESTED_DIR}"

    # ----------------------------------------------------------------
    # ÉTAPE 2 : Récupération des informations système
    # ----------------------------------------------------------------
    log "[2/14] 🔍 Récupération des informations système..."

    # Récupérer les versions
    GITEA_VERSION=$(${pkgs.gitea}/bin/gitea --version | ${pkgs.gnugrep}/bin/grep -oP 'version \K[^ ]+' || echo "unknown")
    PG_VERSION=$(${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/psql --version 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '\d+' | ${pkgs.coreutils}/bin/head -1 || echo "unknown")
    NIXOS_GENERATION=$(${pkgs.nix}/bin/nix-env --list-generations --profile /nix/var/nix/profiles/system | ${pkgs.coreutils}/bin/tail -1 || echo "unknown")

    log "✓ Gitea version: ''${GITEA_VERSION}"
    log "✓ PostgreSQL version: ''${PG_VERSION}"
    log "✓ NixOS generation: ''${NIXOS_GENERATION}"

    # ----------------------------------------------------------------
    # ÉTAPE 3 : Arrêt de Gitea
    # ----------------------------------------------------------------
    log "[3/14] ⏸️  Arrêt de Gitea..."

    ${pkgs.systemd}/bin/systemctl stop gitea.service || error_exit "Impossible d'arrêter Gitea"
    ${pkgs.coreutils}/bin/sleep 2

    if ${pkgs.systemd}/bin/systemctl is-active gitea.service >/dev/null 2>&1; then
        error_exit "Gitea n'est pas complètement arrêté"
    fi

    log "✓ Gitea arrêté"

    # ----------------------------------------------------------------
    # ÉTAPE 4 : Backup PostgreSQL
    # ----------------------------------------------------------------
    log "[4/14] 💾 Backup de la base de données PostgreSQL..."

    if ! ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump gitea > gitea_database.sql 2>/dev/null; then
        ${pkgs.systemd}/bin/systemctl start gitea.service
        error_exit "Échec du dump PostgreSQL"
    fi

    DB_SIZE=$(${pkgs.coreutils}/bin/ls -lh gitea_database.sql | ${pkgs.gawk}/bin/awk '{print $5}')
    log "✓ Base sauvegardée (''${DB_SIZE})"

    # ----------------------------------------------------------------
    # ÉTAPE 5 : Backup du répertoire de données
    # ----------------------------------------------------------------
    log "[5/14] 📦 Backup des données Gitea..."

    GITEA_DATA_PATH="/var/lib/gitea"

    if [ ! -d "$GITEA_DATA_PATH" ]; then
        ${pkgs.systemd}/bin/systemctl start gitea.service
        error_exit "Répertoire Gitea introuvable: ''${GITEA_DATA_PATH}"
    fi

    log "   GITEA_DATA_PATH = ''${GITEA_DATA_PATH}"

    # Exclure les logs et indexation
    if ! ${pkgs.gnutar}/bin/tar czf gitea_data.tar.gz \
        --exclude='log/*' \
        --exclude='indexers/*' \
        -C /var/lib gitea; then
        rc=$?
        ${pkgs.systemd}/bin/systemctl start gitea.service
        error_exit "Échec de l'archivage des données Gitea (tar exit code ''${rc})"
    fi

    DATA_SIZE=$(${pkgs.coreutils}/bin/ls -lh gitea_data.tar.gz | ${pkgs.gawk}/bin/awk '{print $5}')
    log "✓ Données sauvegardées (''${DATA_SIZE})"

    # ----------------------------------------------------------------
    # ÉTAPE 6 : Backup de la configuration
    # ----------------------------------------------------------------
    log "[6/14] ⚙️  Backup de la configuration..."

    CONFIG_FILE="/var/lib/gitea/custom/conf/app.ini"

    if [ -f "$CONFIG_FILE" ]; then
        ${pkgs.coreutils}/bin/cp "$CONFIG_FILE" gitea_config.ini
        log "✓ Configuration sauvegardée"
    else
        log "⚠️ Avertissement: app.ini introuvable"
    fi

    # ----------------------------------------------------------------
    # ÉTAPE 7 : Backup des clés SSH
    # ----------------------------------------------------------------
    log "[7/14] 🔑 Backup des clés SSH..."

    SSH_PATH="/var/lib/gitea/.ssh"

    if [ -d "$SSH_PATH" ]; then
        ${pkgs.gnutar}/bin/tar czf gitea_ssh_keys.tar.gz -C /var/lib/gitea .ssh/
        SSH_SIZE=$(${pkgs.coreutils}/bin/ls -lh gitea_ssh_keys.tar.gz | ${pkgs.gawk}/bin/awk '{print $5}')
        log "✓ Clés SSH sauvegardées (''${SSH_SIZE})"
    else
        log "⚠️ Avertissement: répertoire .ssh introuvable"
    fi

    # ----------------------------------------------------------------
    # ÉTAPE 8 : Redémarrage de Gitea
    # ----------------------------------------------------------------
    log "[8/14] ⚡ Redémarrage de Gitea..."

    ${pkgs.systemd}/bin/systemctl start gitea.service || error_exit "Impossible de redémarrer Gitea"
    ${pkgs.coreutils}/bin/sleep 3

    if ! ${pkgs.systemd}/bin/systemctl is-active gitea.service >/dev/null 2>&1; then
        error_exit "Gitea n'a pas redémarré correctement"
    fi

    log "✓ Gitea redémarré"

    # ----------------------------------------------------------------
    # ÉTAPE 9 : Création du fichier de configuration de restauration
    # ----------------------------------------------------------------
    log "[9/14] 📝 Création du fichier de configuration..."

    ${pkgs.coreutils}/bin/cat > restore_config.txt << EOF
    # ================================================================
    # CONFIGURATION GITEA - BACKUP DU ''${BACKUP_DATE}
    # ================================================================

    Date backup: ''${BACKUP_DATE}
    Hostname source: $HOSTNAME

    # ----------------------------------------------------------------
    # Versions
    # ----------------------------------------------------------------
    Gitea version: ''${GITEA_VERSION}
    PostgreSQL version: ''${PG_VERSION}
    NixOS generation: ''${NIXOS_GENERATION}

    # ----------------------------------------------------------------
    # Base de données PostgreSQL
    # ----------------------------------------------------------------
    DB_TYPE=postgres
    DB_HOST=/run/postgresql
    DB_NAME=gitea
    DB_USER=gitea

    # ----------------------------------------------------------------
    # Chemins des données
    # ----------------------------------------------------------------
    GITEA_DATA_PATH=/var/lib/gitea
    GITEA_CONFIG_PATH=/var/lib/gitea/custom/conf/app.ini
    GITEA_SSH_PATH=/var/lib/gitea/.ssh
    EOF

    log "✓ Fichier de configuration créé"

    # ----------------------------------------------------------------
    # ÉTAPE 10 : Création du README de restauration
    # ----------------------------------------------------------------
    log "[10/14] 📄 Création du README de restauration..."

    ${pkgs.coreutils}/bin/cat > RESTORE_README.md << 'EOFREADME'
    # ================================================================
    # README - BACKUP AUTOMATISÉ GITEA
    # ================================================================

    Backup automatique créé par le module NixOS gitea-backup.

    ## Contenu du backup

    1. **gitea_database.sql**
       - Dump complet de la base PostgreSQL Gitea
       - Contient : repos, users, issues, PRs, webhooks, etc.

    2. **gitea_data.tar.gz**
       - Fichiers de données Gitea (/var/lib/gitea)
       - Contient : repos Git, avatars, LFS, attachments
       - Exclut : logs, indexation

    3. **gitea_config.ini**
       - Configuration app.ini complète
       - Généré par NixOS (à réintégrer dans la config)

    4. **gitea_ssh_keys.tar.gz**
       - Clés SSH du serveur Gitea
       - Important pour garder les fingerprints

    5. **restore_config.txt**
       - Métadonnées du backup (versions, paths, config)

    6. **RESTORE_README.md** (ce fichier)
       - Instructions de restauration

    7. **restore_script.sh**
       - Script de restauration automatique

    ## 📖 Restauration

    ### Méthode automatique (recommandée)

    1. Extraire le backup :
       ```bash
       tar xzf gitea_backup_XXXXXX.tar.gz
       cd gitea_backup_XXXXXX/
       ```

    2. Exécuter le script de restauration :
       ```bash
       sudo ./restore_script.sh
       ```

    ### Méthode manuelle

    1. **Arrêter Gitea** :
       ```bash
       sudo systemctl stop gitea.service
       ```

    2. **Créer la base de données** (si elle n'existe pas) :
       ```bash
       sudo -u postgres createdb gitea
       sudo -u postgres createuser gitea
       sudo -u postgres psql -c "GRANT ALL ON DATABASE gitea TO gitea;"
       ```

    3. **Restaurer le dump SQL** :
       ```bash
       sudo -u postgres psql gitea < gitea_database.sql
       ```

    4. **Restaurer les données** :
       ```bash
       sudo tar xzf gitea_data.tar.gz -C /var/lib/
       sudo chown -R gitea:gitea /var/lib/gitea
       ```

    5. **Restaurer les clés SSH** :
       ```bash
       sudo tar xzf gitea_ssh_keys.tar.gz -C /var/lib/gitea/
       sudo chown -R gitea:gitea /var/lib/gitea/.ssh
       ```

    6. **Vérifier app.ini** :
       - Comparer gitea_config.ini avec la config NixOS actuelle
       - Adapter si nécessaire dans configuration.nix

    7. **Démarrer Gitea** :
       ```bash
       sudo systemctl start gitea.service
       ```

    8. **Vérifier** :
       ```bash
       sudo systemctl status gitea.service
       curl http://localhost:3000/
       ```

    ## 🔍 Vérification de l'intégrité

    Un hash SHA256 est fourni pour vérifier l'intégrité du backup :

        sha256sum -c gitea_backup_*.tar.gz.sha256

    Doit afficher : OK

    ## ⚠️ Notes importantes

    - Ce backup contient tous vos repos Git (CRITIQUE)
    - Les clés SSH du serveur sont sauvegardées pour garder les fingerprints
    - La configuration app.ini est générée par NixOS, à adapter dans la config
    - Tester la restauration sur une VM avant la production !
    EOFREADME

    log "✓ README de restauration créé"

    # ----------------------------------------------------------------
    # ÉTAPE 11 : Création du script de restauration
    # ----------------------------------------------------------------
    log "[11/14] 🔧 Création du script de restauration..."

    ${pkgs.coreutils}/bin/cat > restore_script.sh << 'EOFRESTORE'
    #!/usr/bin/env bash
    # Script de restauration automatique Gitea
    # Généré automatiquement lors du backup

    set -euo pipefail

    echo "╔════════════════════════════════════════╗"
    echo "║   🔄 RESTAURATION GITEA               ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Vérifier que le script est exécuté en root
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Ce script doit être exécuté en tant que root"
        exit 1
    fi

    # Vérifier que nous sommes dans le bon répertoire
    if [ ! -f "gitea_database.sql" ]; then
        echo "❌ Fichier gitea_database.sql introuvable"
        echo "   Exécutez ce script depuis le répertoire de backup extrait"
        exit 1
    fi

    echo "[1/8] ⏸️  Arrêt de Gitea..."
    systemctl stop gitea.service || true
    sleep 2

    echo "[2/8] 🗄️  Vérification de la base PostgreSQL..."
    if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw gitea; then
        echo "   Création de la base de données gitea..."
        sudo -u postgres createdb gitea
        sudo -u postgres createuser gitea || true
        sudo -u postgres psql -c "GRANT ALL ON DATABASE gitea TO gitea;"
    fi

    echo "[3/8] 💾 Restauration de la base de données..."
    sudo -u postgres psql gitea < gitea_database.sql
    echo "✓ Base restaurée"

    echo "[4/8] 📦 Restauration des données Gitea..."
    tar xzf gitea_data.tar.gz -C /var/lib/
    chown -R gitea:gitea /var/lib/gitea
    echo "✓ Données restaurées"

    echo "[5/8] 🔑 Restauration des clés SSH..."
    if [ -f "gitea_ssh_keys.tar.gz" ]; then
        tar xzf gitea_ssh_keys.tar.gz -C /var/lib/gitea/
        chown -R gitea:gitea /var/lib/gitea/.ssh
        chmod 700 /var/lib/gitea/.ssh
        chmod 600 /var/lib/gitea/.ssh/* || true
        echo "✓ Clés SSH restaurées"
    else
        echo "⚠️  Pas de clés SSH à restaurer"
    fi

    echo "[6/8] ⚙️  Vérification de la configuration..."
    if [ -f "gitea_config.ini" ]; then
        echo "   📄 Configuration disponible dans gitea_config.ini"
        echo "   ⚠️  Comparez avec votre configuration NixOS actuelle"
    fi

    echo "[7/8] ⚡ Démarrage de Gitea..."
    systemctl start gitea.service
    sleep 3

    echo "[8/8] ✅ Vérification..."
    if systemctl is-active gitea.service >/dev/null 2>&1; then
        echo "✓ Gitea est démarré"
        echo ""
        echo "╔════════════════════════════════════════╗"
        echo "║   ✅ RESTAURATION TERMINÉE            ║"
        echo "╚════════════════════════════════════════╝"
        echo ""
        echo "Testez l'accès : curl http://localhost:3000/"
    else
        echo "❌ Gitea n'a pas démarré correctement"
        echo "   Vérifiez les logs : journalctl -u gitea -n 50"
        exit 1
    fi
    EOFRESTORE

    ${pkgs.coreutils}/bin/chmod +x restore_script.sh
    log "✓ Script de restauration créé"

    # ----------------------------------------------------------------
    # ÉTAPE 12 : Création de l'archive et du hash
    # ----------------------------------------------------------------
    log "[12/14] 🗜️  Compression et hash..."

    cd "$BACKUP_DIR"

    if ! ${pkgs.gnutar}/bin/tar czf "''${BACKUP_ARCHIVE}" "''${BACKUP_NESTED_DIR}/" 2>/dev/null; then
        error_exit "Échec de la compression"
    fi

    ${pkgs.coreutils}/bin/sha256sum "''${BACKUP_ARCHIVE}" > "''${BACKUP_HASH}"

    ARCHIVE_SIZE=$(${pkgs.coreutils}/bin/ls -lh "''${BACKUP_ARCHIVE}" | ${pkgs.gawk}/bin/awk '{print $5}')
    log "✓ Archive créée (''${ARCHIVE_SIZE})"

    # ----------------------------------------------------------------
    # ÉTAPE 13 : Upload vers Google Drive
    # ----------------------------------------------------------------
    log "[13/14] ☁️  Upload vers Google Drive..."

    if ! ${pkgs.rclone}/bin/rclone copy "''${BACKUP_ARCHIVE}" "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" --config "$RCLONE_CONFIG_PATH" --progress 2>&1 | tee -a "$LOG_FILE"; then
        error_exit "Échec de l'upload de l'archive vers Google Drive"
    fi

    if ! ${pkgs.rclone}/bin/rclone copy "''${BACKUP_HASH}" "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" --config "$RCLONE_CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        log "⚠️ Avertissement: Échec de l'upload du hash"
    fi

    log "✓ Upload terminé"

    # ----------------------------------------------------------------
    # ÉTAPE 14 : Nettoyage des vieux backups
    # ----------------------------------------------------------------
    log "[14/14] 🧹 Nettoyage des anciens backups..."

    cd "$BACKUP_DIR"

    # Nettoyage local
    ${pkgs.coreutils}/bin/ls -t gitea_backup_*.tar.gz 2>/dev/null | ${pkgs.coreutils}/bin/tail -n +$((${toString cfg.retentionLocal} + 1)) | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm -f
    ${pkgs.coreutils}/bin/ls -t gitea_backup_*.tar.gz.sha256 2>/dev/null | ${pkgs.coreutils}/bin/tail -n +$((${toString cfg.retentionLocal} + 1)) | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm -f
    ${pkgs.coreutils}/bin/rm -rf gitea_backup_* 2>/dev/null || true

    # Nettoyage GDrive
    ${pkgs.rclone}/bin/rclone delete "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" \
        --config "$RCLONE_CONFIG_PATH" \
        --min-age ${toString cfg.retentionGdrive}d \
        2>&1 | tee -a "$LOG_FILE" || log "⚠️ Impossible de nettoyer GDrive"

    log "✓ Nettoyage terminé"

    # ----------------------------------------------------------------
    # FINALISATION : Notifications
    # ----------------------------------------------------------------
    log "📢 Envoi des notifications..."

    END_TIME=$(${pkgs.coreutils}/bin/date +%s)
    DURATION=$((END_TIME - START_TIME))
    GDRIVE_URL="https://drive.google.com/drive/folders/''${GDRIVE_FOLDER_ID}"

    send_notifications "success"

    log ""
    log "╔════════════════════════════════════════╗"
    log "║   ✅ BACKUP TERMINÉ AVEC SUCCÈS       ║"
    log "╚════════════════════════════════════════╝"
    log ""
    log "📊 Statistiques:"
    log "   • Taille: ''${ARCHIVE_SIZE}"
    log "   • Durée: ''${DURATION}s"
    log "   • Fichier: ''${BACKUP_ARCHIVE}"
    log "   • Google Drive: ''${GDRIVE_URL}"
    log ""
    log "✅ Backup et notifications envoyés avec succès!"

    exit 0
  '';

in {
  options.services.gitea-backup = {
    enable = mkEnableOption "Backup automatisé Gitea avec Google Drive et Notion";

    backupDir = mkOption {
      type = types.str;
      default = "/var/backups/gitea";
      description = "Répertoire où créer les backups temporaires";
    };

    logFile = mkOption {
      type = types.str;
      default = "/var/log/gitea-backup.log";
      description = "Fichier de log du backup";
    };

    gdrivePath = mkOption {
      type = types.str;
      default = "gitea";
      description = "Chemin dans Google Drive où stocker les backups (relatif au folder_id)";
    };

    schedule = mkOption {
      type = types.str;
      default = "*-*-* 02:00:00";
      description = "Calendrier systemd (format OnCalendar) pour l'exécution du backup";
    };

    retentionLocal = mkOption {
      type = types.int;
      default = 7;
      description = "Nombre de backups à garder localement";
    };

    retentionGdrive = mkOption {
      type = types.int;
      default = 90;
      description = "Nombre de jours de backups à garder sur Google Drive";
    };
  };

  config = mkIf cfg.enable {
    # Déclarer les secrets sops
    sops.secrets = {
      "google_drive/client_id" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "google_drive/client_secret" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "google_drive/token" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "google_drive/folder_id" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "notion/api_token" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "notion/database_id_gitea" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "gmail/from" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "gmail/to" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "gmail/app_password" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
      "slack/webhook_url" = {
        sopsFile = ../../secrets/dandelion.yaml;
      };
    };

    # Créer le fichier rclone.conf avec OAuth
    systemd.services."gitea-backup-rclone-config" = {
      description = "Générer la config rclone pour gitea-backup";
      wantedBy = [ "multi-user.target" ];
      before = [ "gitea-backup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /run/gitea-backup

        # Récupérer les credentials OAuth
        CLIENT_ID=$(cat ${config.sops.secrets."google_drive/client_id".path})
        CLIENT_SECRET=$(cat ${config.sops.secrets."google_drive/client_secret".path})
        TOKEN=$(cat ${config.sops.secrets."google_drive/token".path})
        FOLDER_ID=$(cat ${config.sops.secrets."google_drive/folder_id".path})

        # Créer la config rclone avec OAuth
        cat > /run/gitea-backup/rclone.conf << EOF
[gdrive]
type = drive
scope = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
token = $TOKEN
root_folder_id = $FOLDER_ID
EOF

        chmod 600 /run/gitea-backup/rclone.conf
      '';
    };

    # Service de backup
    systemd.services."gitea-backup" = {
      description = "Backup automatisé Gitea avec upload GDrive et Notion";
      after = [ "network-online.target" "gitea.service" "postgresql.service" "gitea-backup-rclone-config.service" ];
      wants = [ "network-online.target" ];
      requires = [ "gitea-backup-rclone-config.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}";
        User = "root";
        StandardOutput = "append:${cfg.logFile}";
        StandardError = "append:${cfg.logFile}";
        TimeoutStartSec = 1800; # 30 minutes max
      };

      path = with pkgs; [
        gzip
      ];
    };

    # Timer systemd
    systemd.timers."gitea-backup" = {
      description = "Timer pour backup quotidien Gitea";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };

    # Créer les répertoires et fichiers nécessaires
    systemd.tmpfiles.rules = [
      "d ${cfg.backupDir} 0755 root root -"
      "f ${cfg.logFile} 0644 root root -"
    ];
  };
}
