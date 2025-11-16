# Module NixOS pour le backup automatisé n8n
# Fichier : hosts/whitelily/n8n-backup.nix
# 
# Ce module gère le backup automatique de n8n vers Google Drive
# avec logging dans Notion et notifications par email/Slack

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.n8n-backup;
  
  # Script de backup principal
  backupScript = pkgs.writeShellScript "n8n-backup-automated.sh" ''
    set -euo pipefail
    
    # ================================================================
    # SCRIPT DE BACKUP AUTOMATISÉ N8N
    # ================================================================
    
    # Configuration depuis les options du module
    BACKUP_DIR="${cfg.backupDir}"
    RCLONE_CONFIG_PATH="/run/n8n-backup/rclone.conf"
    RCLONE_REMOTE="gdrive"
    GDRIVE_BACKUP_FOLDER="${cfg.gdrivePath}"
    LOG_FILE="${cfg.logFile}"
    
    # Charger les secrets depuis sops-nix
    NOTION_API_KEY=$(cat ${config.sops.secrets."notion/api_token".path})
    NOTION_DATABASE_ID=$(cat ${config.sops.secrets."notion/database_id".path})
    GMAIL_FROM=$(cat ${config.sops.secrets."gmail/from".path})
    GMAIL_TO=$(cat ${config.sops.secrets."gmail/to".path})
    GMAIL_PASSWORD=$(cat ${config.sops.secrets."gmail/app_password".path})
    SLACK_WEBHOOK=$(cat ${config.sops.secrets."slack/webhook_url".path})
    GDRIVE_FOLDER_ID=$(cat ${config.sops.secrets."google_drive/folder_id".path})
    
    # Variables du backup
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_NESTED_DIR="n8n_migration_backup_''${BACKUP_DATE}"
    BACKUP_ARCHIVE="n8n_migration_''${BACKUP_DATE}.tar.gz"
    BACKUP_HASH="''${BACKUP_ARCHIVE}.sha256"
    STATUS="success"
    ERROR_MESSAGE=""
    START_TIME=$(date +%s)
    
    # ----------------------------------------------------------------
    # FONCTIONS UTILITAIRES
    # ----------------------------------------------------------------
    
    log() {
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
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
        
        local duration=$(($(date +%s) - START_TIME))
        local archive_size="N/A"
        if [ -f "$BACKUP_DIR/$BACKUP_ARCHIVE" ]; then
            archive_size=$(ls -lh "$BACKUP_DIR/$BACKUP_ARCHIVE" | awk '{print $5}')
        fi
        
        cat > /tmp/slack_payload.json << EOF
    {
      "attachments": [
        {
          "color": "$color",
          "blocks": [
            {
              "type": "header",
              "text": {
                "type": "plain_text",
                "text": "$emoji Backup n8n - $(hostname)"
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
        
        rm -f /tmp/slack_payload.json
    }
    
    send_error_email() {
        log "📧 Envoi de l'email d'erreur..."
        
        cat > /tmp/email_body.txt << EOF
    Subject: ⚠️ Erreur Backup n8n - $(hostname)
    From: ''${GMAIL_FROM}
    To: ''${GMAIL_TO}
    Content-Type: text/html; charset=UTF-8
    
    <html>
    <body>
    <h2>⚠️ Erreur lors du backup n8n</h2>
    
    <p><strong>Serveur:</strong> $(hostname)</p>
    <p><strong>Date:</strong> $(date +'%Y-%m-%d %H:%M:%S')</p>
    <p><strong>Status:</strong> ❌ ÉCHEC</p>
    
    <h3>Message d'erreur:</h3>
    <pre style="background: #f5f5f5; padding: 10px; border-radius: 5px;">
    ''${ERROR_MESSAGE}
    </pre>
    
    <h3>Dernières lignes du log:</h3>
    <pre style="background: #f5f5f5; padding: 10px; border-radius: 5px;">
    $(tail -20 "$LOG_FILE" 2>/dev/null || echo "Log non disponible")
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
        
        rm -f /tmp/email_body.txt
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
        
        cat > /tmp/notion_payload.json << EOF
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
            "start": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
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
                "content": "$(hostname)"
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
        
        rm -f /tmp/notion_payload.json
    }
    
    send_notifications() {
        local status="$1"
        
        if [ "$status" = "failed" ]; then
            send_error_email
            send_slack_notification "failed"
        else
            local duration=$(($(date +%s) - START_TIME))
            local archive_size=$(ls -lh "$BACKUP_DIR/$BACKUP_ARCHIVE" | awk '{print $5}')
            local gdrive_url="https://drive.google.com/drive/folders/''${GDRIVE_FOLDER_ID}"

            log_to_notion "success" "''${gdrive_url}" "''${archive_size}" "''${duration}"
            send_slack_notification "success"
        fi
    }
    
    # ----------------------------------------------------------------
    # DÉBUT DU BACKUP
    # ----------------------------------------------------------------
    
    log "╔════════════════════════════════════════╗"
    log "║   🔄 BACKUP AUTOMATISÉ N8N            ║"
    log "╚════════════════════════════════════════╝"
    log ""
    log "📅 Date: ''${BACKUP_DATE}"
    log "🖥️  Serveur: $(hostname)"
    log ""
    
    # ----------------------------------------------------------------
    # ÉTAPE 1 : Préparation
    # ----------------------------------------------------------------
    log "[1/14] 📁 Préparation des dossiers..."
    
    cd "$BACKUP_DIR"
    mkdir -p "''${BACKUP_NESTED_DIR}" || error_exit "Impossible de créer le dossier de backup"
    cd "''${BACKUP_NESTED_DIR}"
    
    # ----------------------------------------------------------------
    # ÉTAPE 2 : Variables d'environnement
    # ----------------------------------------------------------------
    log "[2/14] 🔍 Récupération des variables d'environnement..."
    
    if ! ${pkgs.podman}/bin/podman inspect n8n --format='{{range .Config.Env}}{{println .}}{{end}}' > n8n_env_vars.txt 2>/dev/null; then
        error_exit "Impossible de récupérer les variables d'environnement de n8n"
    fi
    
    log "✓ Variables d'environnement récupérées"
    
    # ----------------------------------------------------------------
    # ÉTAPE 3 : Clé d'encryption
    # ----------------------------------------------------------------
    log "[3/14] 🔐 Récupération de la clé d'encryption..."
    
    if [ -f /run/n8n/n8n.env ]; then
        ENCRYPTION_KEY=$(cat /run/n8n/n8n.env | grep "N8N_ENCRYPTION_KEY=" | cut -d= -f2)
    else
        error_exit "Fichier /run/n8n/n8n.env introuvable"
    fi
    
    if [ -z "$ENCRYPTION_KEY" ]; then
        error_exit "Clé d'encryption vide"
    fi
    
    log "✓ Clé récupérée (''${#ENCRYPTION_KEY} caractères)"
    
    # ----------------------------------------------------------------
    # ÉTAPE 4 : Extraction des infos de config
    # ----------------------------------------------------------------
    log "[4/14] ⚙️  Extraction des informations de configuration..."
    
    DB_NAME=$(grep "DB_POSTGRESDB_DATABASE=" n8n_env_vars.txt | cut -d= -f2 || echo "n8n")
    DB_USER=$(grep "DB_POSTGRESDB_USER=" n8n_env_vars.txt | cut -d= -f2 || echo "n8n")
    DB_HOST=$(grep "DB_POSTGRESDB_HOST=" n8n_env_vars.txt | cut -d= -f2 || echo "127.0.0.1")
    DB_PORT=$(grep "DB_POSTGRESDB_PORT=" n8n_env_vars.txt | cut -d= -f2 || echo "5432")
    DB_PASSWORD=$(grep "DB_POSTGRESDB_PASSWORD=" n8n_env_vars.txt | cut -d= -f2 || echo "")
    N8N_HOST=$(grep "N8N_HOST=" n8n_env_vars.txt | cut -d= -f2 || echo "localhost")
    N8N_PROTOCOL=$(grep "N8N_PROTOCOL=" n8n_env_vars.txt | cut -d= -f2 || echo "https")
    N8N_PORT=$(grep "N8N_PORT=" n8n_env_vars.txt | cut -d= -f2 || echo "5678")
    WEBHOOK_URL=$(grep "WEBHOOK_URL=" n8n_env_vars.txt | cut -d= -f2 || echo "")
    TIMEZONE=$(grep "GENERIC_TIMEZONE=" n8n_env_vars.txt | cut -d= -f2 || echo "Europe/Paris")
    NODE_VERSION=$(grep "NODE_VERSION=" n8n_env_vars.txt | cut -d= -f2 || echo "unknown")
    
    log "✓ Configuration extraite"
    
    # ----------------------------------------------------------------
    # ÉTAPE 5 : Arrêt de n8n
    # ----------------------------------------------------------------
    log "[5/14] ⏸️  Arrêt de n8n..."
    
    ${pkgs.systemd}/bin/systemctl stop podman-n8n.service || error_exit "Impossible d'arrêter n8n"
    sleep 2
    
    if ${pkgs.podman}/bin/podman ps 2>/dev/null | grep -q n8n; then
        error_exit "n8n n'est pas complètement arrêté"
    fi
    
    log "✓ n8n arrêté"
    
    # ----------------------------------------------------------------
    # ÉTAPE 6 : Backup PostgreSQL
    # ----------------------------------------------------------------
    log "[6/14] 💾 Backup de la base de données PostgreSQL..."
    
    if ! sudo -u postgres ${pkgs.postgresql}/bin/pg_dump "$DB_NAME" > n8n_database_backup.sql 2>/dev/null; then
        ${pkgs.systemd}/bin/systemctl start podman-n8n.service
        error_exit "Échec du dump PostgreSQL"
    fi
    
    DB_SIZE=$(ls -lh n8n_database_backup.sql | awk '{print $5}')
    log "✓ Base sauvegardée (''${DB_SIZE})"
    
    # ----------------------------------------------------------------
    # ÉTAPE 7 : Backup des fichiers n8n
    # ----------------------------------------------------------------
    log "[7/14] 📦 Backup des fichiers n8n..."
    
    N8N_DATA_PATH=$(${pkgs.podman}/bin/podman inspect n8n 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0].Mounts[] | select(.Destination == "/home/node/.n8n") | .Source' 2>/dev/null || echo "")
    
    if [ -z "$N8N_DATA_PATH" ]; then
        N8N_DATA_PATH="/var/lib/n8n"
    fi
    
    if [ ! -d "$N8N_DATA_PATH" ]; then
        ${pkgs.systemd}/bin/systemctl start podman-n8n.service
        error_exit "Répertoire n8n introuvable: ''${N8N_DATA_PATH}"
    fi
    
    if ! ${pkgs.gnutar}/bin/tar czf n8n_data_real.tar.gz -C "$(dirname "$N8N_DATA_PATH")" "$(basename "$N8N_DATA_PATH")" 2>/dev/null; then
        ${pkgs.systemd}/bin/systemctl start podman-n8n.service
        error_exit "Échec de l'archivage des fichiers n8n"
    fi
    
    DATA_SIZE=$(ls -lh n8n_data_real.tar.gz | awk '{print $5}')
    log "✓ Fichiers sauvegardés (''${DATA_SIZE})"
    
    # ----------------------------------------------------------------
    # ÉTAPE 8 : Création du fichier de configuration
    # ----------------------------------------------------------------
    log "[8/14] 📝 Création du fichier de configuration..."
    
    PG_VERSION=$(sudo -u postgres ${pkgs.postgresql}/bin/psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "unknown")
    
    cat > migration_config.txt << EOF
    # ================================================================
    # CONFIGURATION N8N - BACKUP DU ''${BACKUP_DATE}
    # ================================================================
    # IMPORTANT: Ce fichier contient la clé d'encryption qui est
    #            CRITIQUE pour décrypter les credentials.
    #            Sauvegardez ce fichier dans un gestionnaire de
    #            mots de passe sécurisé !
    # ================================================================
    
    Date backup: ''${BACKUP_DATE}
    Hostname source: $(hostname)
    
    # ----------------------------------------------------------------
    # Base de données PostgreSQL
    # ----------------------------------------------------------------
    DB_TYPE=postgresdb
    DB_HOST=''${DB_HOST}
    DB_PORT=''${DB_PORT}
    DB_NAME=''${DB_NAME}
    DB_USER=''${DB_USER}
    DB_PASSWORD=''${DB_PASSWORD}
    
    # ----------------------------------------------------------------
    # Configuration n8n
    # ----------------------------------------------------------------
    N8N_HOST=''${N8N_HOST}
    N8N_PROTOCOL=''${N8N_PROTOCOL}
    N8N_PORT=''${N8N_PORT}
    WEBHOOK_URL=''${WEBHOOK_URL}
    TIMEZONE=''${TIMEZONE}
    
    # ----------------------------------------------------------------
    # CLÉ D'ENCRYPTION (CRITIQUE - NE PAS PERDRE !)
    # ----------------------------------------------------------------
    # Cette clé est nécessaire pour décrypter les credentials.
    # Elle doit être IDENTIQUE sur la nouvelle installation.
    N8N_ENCRYPTION_KEY=''${ENCRYPTION_KEY}
    
    # ----------------------------------------------------------------
    # Versions des composants
    # ----------------------------------------------------------------
    PostgreSQL: ''${PG_VERSION}
    Node: ''${NODE_VERSION}
    EOF
    
    log "✓ Fichier de configuration créé avec clé d'encryption"
    
    # ----------------------------------------------------------------
    # ÉTAPE 9 : Création du README
    # ----------------------------------------------------------------
    log "[9/14] 📄 Création du README..."
    
    cat > MIGRATION_README.txt << 'EOFREADME'
    # ================================================================
    # README - BACKUP AUTOMATISÉ N8N
    # ================================================================
    
    Backup automatique créé par le module NixOS n8n-backup.
    
    ## Contenu du backup
    
    1. **n8n_database_backup.sql**
       - Dump complet de la base PostgreSQL
       - Contient : workflows, credentials, executions, tags, etc.
    
    2. **n8n_data_real.tar.gz**
       - Fichiers de données n8n
       - Contient : community nodes, configs, SSH keys, binary data
    
    3. **migration_config.txt**
       - Configuration complète avec la clé d'encryption
       - ⚠️  FICHIER CRITIQUE - contient la clé pour décrypter les credentials
    
    4. **n8n_env_vars.txt**
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
    complet dans le document de restauration n8n.
    
    ## 🔍 Vérification de l'intégrité
    
    Un hash SHA256 est fourni pour vérifier l'intégrité du backup :
    
        sha256sum -c n8n_migration_*.tar.gz.sha256
    
    Doit afficher : OK
    EOFREADME
    
    log "✓ README créé"
    
    # ----------------------------------------------------------------
    # ÉTAPE 10 : Redémarrage de n8n
    # ----------------------------------------------------------------
    log "[10/14] ⚡ Redémarrage de n8n..."
    
    ${pkgs.systemd}/bin/systemctl start podman-n8n.service || error_exit "Impossible de redémarrer n8n"
    sleep 3
    
    if ! ${pkgs.podman}/bin/podman ps 2>/dev/null | grep -q n8n; then
        error_exit "n8n n'a pas redémarré correctement"
    fi
    
    log "✓ n8n redémarré"
    
    # ----------------------------------------------------------------
    # ÉTAPE 11 : Création de l'archive et du hash
    # ----------------------------------------------------------------
    log "[11/14] 🗜️  Compression et hash..."
    
    cd "$BACKUP_DIR"
    
    if ! ${pkgs.gnutar}/bin/tar czf "''${BACKUP_ARCHIVE}" "''${BACKUP_NESTED_DIR}/" 2>/dev/null; then
        error_exit "Échec de la compression"
    fi
    
    ${pkgs.coreutils}/bin/sha256sum "''${BACKUP_ARCHIVE}" > "''${BACKUP_HASH}"
    
    ARCHIVE_SIZE=$(ls -lh "''${BACKUP_ARCHIVE}" | awk '{print $5}')
    log "✓ Archive créée (''${ARCHIVE_SIZE})"
    
    # ----------------------------------------------------------------
    # ÉTAPE 12 : Upload vers Google Drive
    # ----------------------------------------------------------------
    log "[12/14] ☁️  Upload vers Google Drive..."
    
    if ! ${pkgs.rclone}/bin/rclone copy "''${BACKUP_ARCHIVE}" "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" --config "$RCLONE_CONFIG_PATH" --progress 2>&1 | tee -a "$LOG_FILE"; then
        error_exit "Échec de l'upload de l'archive vers Google Drive"
    fi
    
    if ! ${pkgs.rclone}/bin/rclone copy "''${BACKUP_HASH}" "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" --config "$RCLONE_CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        log "⚠️ Avertissement: Échec de l'upload du hash"
    fi
    
    log "✓ Upload terminé"
    
    # ----------------------------------------------------------------
    # ÉTAPE 13 : Nettoyage des vieux backups
    # ----------------------------------------------------------------
    log "[13/14] 🧹 Nettoyage des anciens backups..."
    
    cd "$BACKUP_DIR"
    
    # Nettoyage local
    ls -t n8n_migration_*.tar.gz 2>/dev/null | tail -n +$((${toString cfg.retentionLocal} + 1)) | xargs -r rm -f
    ls -t n8n_migration_*.tar.gz.sha256 2>/dev/null | tail -n +$((${toString cfg.retentionLocal} + 1)) | xargs -r rm -f
    rm -rf n8n_migration_backup_* 2>/dev/null
    
    # Nettoyage GDrive
    ${pkgs.rclone}/bin/rclone delete "''${RCLONE_REMOTE}:''${GDRIVE_BACKUP_FOLDER}/" \
        --config "$RCLONE_CONFIG_PATH" \
        --min-age ${toString cfg.retentionGdrive}d \
        2>&1 | tee -a "$LOG_FILE" || log "⚠️ Impossible de nettoyer GDrive"
    
    log "✓ Nettoyage terminé"
    
    # ----------------------------------------------------------------
    # ÉTAPE 14 : Notifications et finalisation
    # ----------------------------------------------------------------
    log "[14/14] 📢 Envoi des notifications..."

    END_TIME=$(date +%s)
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
  options.services.n8n-backup = {
    enable = mkEnableOption "Backup automatisé n8n avec Google Drive et Notion";
    
    backupDir = mkOption {
      type = types.str;
      default = "/var/backups/n8n";
      description = "Répertoire où créer les backups temporaires";
    };
    
    logFile = mkOption {
      type = types.str;
      default = "/var/log/n8n-backup.log";
      description = "Fichier de log du backup";
    };
    
    gdrivePath = mkOption {
      type = types.str;
      default = "backups/n8n";
      description = "Chemin dans Google Drive où stocker les backups";
    };

    schedule = mkOption {
      type = types.str;
      default = "*-*-* 00:00:00";
      description = "Calendrier systemd (format OnCalendar) pour l'exécution du backup";
    };
    
    retentionLocal = mkOption {
      type = types.int;
      default = 7;
      description = "Nombre de backups à garder localement";
    };
    
    retentionGdrive = mkOption {
      type = types.int;
      default = 30;
      description = "Nombre de jours de backups à garder sur Google Drive";
    };
  };
  
  config = mkIf cfg.enable {
    # Déclarer les secrets sops (ils existent déjà, on les référence juste)
    sops.secrets = {
      "google_drive/service_account_json_base64" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "google_drive/folder_id" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "notion/api_token" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "notion/database_id" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "gmail/from" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "gmail/to" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "gmail/app_password" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
      "slack/webhook_url" = {
        sopsFile = ../../secrets/whitelily.yaml;
      };
    };
    
    # Créer le fichier rclone.conf depuis le Service Account JSON
    systemd.services."n8n-backup-rclone-config" = {
      description = "Générer la config rclone pour n8n-backup";
      wantedBy = [ "multi-user.target" ];
      before = [ "n8n-backup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /run/n8n-backup
        
        # Décoder le JSON base64
        SA_JSON=$(${pkgs.coreutils}/bin/base64 -d ${config.sops.secrets."google_drive/service_account_json_base64".path})
        
        # Récupérer le folder_id
        FOLDER_ID=$(cat ${config.sops.secrets."google_drive/folder_id".path})
        
        # Créer la config rclone
        cat > /run/n8n-backup/rclone.conf << EOF
        [gdrive]
        type = drive
        scope = drive
        service_account_credentials = $SA_JSON
        root_folder_id = $FOLDER_ID
        EOF
        
        chmod 600 /run/n8n-backup/rclone.conf
      '';
    };
    
    # Service de backup
    systemd.services."n8n-backup" = {
      description = "Backup automatisé n8n avec upload GDrive et Notion";
      after = [ "network-online.target" "podman-n8n.service" "postgresql.service" "n8n-backup-rclone-config.service" ];
      wants = [ "network-online.target" ];
      requires = [ "n8n-backup-rclone-config.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}";
        User = "root";
        StandardOutput = "append:${cfg.logFile}";
        StandardError = "append:${cfg.logFile}";
        TimeoutStartSec = 1800; # 30 minutes max
      };
    };
    
    # Timer systemd
    systemd.timers."n8n-backup" = {
      description = "Timer pour backup quotidien n8n";
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
