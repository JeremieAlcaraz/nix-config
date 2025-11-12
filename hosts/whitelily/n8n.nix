{ config, pkgs, lib, ... }:

let
  # Configuration du domaine n8n
  domain = "n8n.jeremiealcaraz.com";  # ← À adapter selon ton domaine

in {
  ########################################
  # 1) PostgreSQL pour n8n
  ########################################
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "n8n" ];
    ensureUsers = [{
      name = "n8n";
      ensureDBOwnership = true;
    }];
    settings = {
      max_connections = 100;
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      maintenance_work_mem = "64MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "7864kB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "2621kB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
    };
  };

  # Initialisation du mot de passe PostgreSQL pour l'utilisateur n8n
  systemd.services.postgresql.postStart = lib.mkAfter ''
    $PSQL -tA <<'EOF'
      DO $$
      DECLARE password TEXT;
      BEGIN
        password := trim(both from replace(pg_read_file('/run/secrets/n8n-db-password'), E'\n', '''));
        EXECUTE format('ALTER USER n8n WITH PASSWORD %L', password);
      END $$;
    EOF
  '';

  # Copier le secret dans un emplacement accessible par PostgreSQL
  systemd.services."postgresql-secret-setup" = {
    description = "Setup PostgreSQL password secret for n8n";
    wantedBy = [ "postgresql.service" ];
    before = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
    };
    script = ''
      umask 077
      mkdir -p /run/secrets
      cp ${config.sops.secrets."n8n/db_password".path} /run/secrets/n8n-db-password
      chown postgres:postgres /run/secrets/n8n-db-password
      chmod 0400 /run/secrets/n8n-db-password
    '';
  };

  ########################################
  # 2) Podman pour les containers OCI
  ########################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;  # Pas besoin de l'alias docker
    defaultNetwork.settings.dns_enabled = true;
  };

  ########################################
  # 3) n8n en container (Podman via oci-containers)
  ########################################
  # Créer le fichier d'environnement pour n8n
  systemd.services."n8n-envfile" = {
    description = "Render n8n env file from sops secrets";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-n8n.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      umask 077
      mkdir -p /run/secrets

      # Lire les secrets
      ENCRYPTION_KEY=$(cat ${config.sops.secrets."n8n/encryption_key".path})
      BASIC_USER=$(cat ${config.sops.secrets."n8n/basic_user".path})
      BASIC_PASS=$(cat ${config.sops.secrets."n8n/basic_pass".path})
      DB_PASSWORD=$(cat ${config.sops.secrets."n8n/db_password".path})

      # Créer le fichier .env
      cat > /run/secrets/n8n.env <<EOF
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$BASIC_USER
N8N_BASIC_AUTH_PASSWORD=$BASIC_PASS
DB_POSTGRESDB_PASSWORD=$DB_PASSWORD
EOF

      chmod 0400 /run/secrets/n8n.env
    '';
  };

  # Container n8n
  virtualisation.oci-containers = {
    backend = "podman";
    containers.n8n = {
      image = "docker.io/n8nio/n8n:1.74.1";  # Version épinglée
      autoStart = true;
      ports = [ "127.0.0.1:5678:5678" ];  # Écoute uniquement en local

      environment = {
        N8N_HOST = domain;
        N8N_PORT = "5678";
        N8N_PROTOCOL = "https";
        WEBHOOK_URL = "https://${domain}/";
        GENERIC_TIMEZONE = "Europe/Paris";
        N8N_LOG_LEVEL = "info";

        # Configuration PostgreSQL
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_HOST = "host.containers.internal";  # Accès au host depuis le container
        DB_POSTGRESDB_PORT = "5432";
        DB_POSTGRESDB_DATABASE = "n8n";
        DB_POSTGRESDB_USER = "n8n";

        # Désactiver la télémétrie
        N8N_DIAGNOSTICS_ENABLED = "false";
        N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
        N8N_TEMPLATES_ENABLED = "true";
        N8N_PUBLIC_API_DISABLED = "false";
      };

      extraOptions = [
        # Volume pour les données persistantes
        "--volume=/var/lib/n8n:/home/node/.n8n"
        # Fichier d'environnement avec les secrets
        "--env-file=/run/secrets/n8n.env"
        # Permettre l'accès au PostgreSQL du host
        "--add-host=host.containers.internal:host-gateway"
        # Healthcheck
        "--health-cmd=wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
      ];
    };
  };

  # Répertoire de données n8n
  systemd.tmpfiles.rules = [
    "d /var/lib/n8n 0750 root root -"
  ];

  ########################################
  # 4) Caddy en reverse proxy
  ########################################
  services.caddy = {
    enable = true;

    # Configuration globale
    globalConfig = ''
      # Désactiver la télémétrie
      admin off

      # Logs
      log {
        output file /var/log/caddy/access.log
        format json
      }
    '';

    virtualHosts."${domain}" = {
      # Écoute uniquement en local (Cloudflare Tunnel se connecte ici)
      listenAddresses = [ "127.0.0.1" ];

      extraConfig = ''
        # Compression
        encode zstd gzip

        # Headers de sécurité
        header {
          # Sécurité
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"

          # Cacher Caddy
          -Server
        }

        # Gestion des WebSockets
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }

        # Reverse proxy vers n8n
        reverse_proxy 127.0.0.1:5678 {
          # Support HTTP/2 et HTTP/1.1
          transport http {
            versions h2c 1.1
          }

          # Headers essentiels pour n8n
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}

          # Timeouts pour les webhooks long-running
          flush_interval -1
        }

        # Logs d'accès
        log {
          output file /var/log/caddy/n8n-access.log {
            roll_size 100mb
            roll_keep 5
            roll_keep_for 720h
          }
        }
      '';
    };
  };

  # Créer le répertoire de logs Caddy
  systemd.tmpfiles.rules = [
    "d /var/log/caddy 0750 caddy caddy -"
  ];

  ########################################
  # 5) Cloudflare Tunnel
  ########################################
  services.cloudflared = {
    enable = true;
    tunnels = {
      # Nom du tunnel (à créer côté Cloudflare)
      "n8n-whitelily" = {
        credentialsFile = config.sops.secrets."cloudflared/credentials".path;
        default = "http_status:404";

        ingress = {
          "${domain}" = {
            service = "http://127.0.0.1:80";
          };
        };
      };
    };
  };

  ########################################
  # 6) Backups automatiques
  ########################################

  # Backup PostgreSQL quotidien
  services.postgresqlBackup = {
    enable = true;
    databases = [ "n8n" ];
    startAt = "daily";
    location = "/var/backup/postgresql";
    compression = "gzip";
  };

  # Backup des données n8n
  systemd.services."backup-n8n-data" = {
    description = "Backup n8n data directory";
    script = ''
      set -euo pipefail

      BACKUP_DIR="/var/backup/n8n"
      TIMESTAMP=$(date +%F_%H-%M-%S)

      mkdir -p "$BACKUP_DIR"

      # Backup du répertoire n8n
      ${pkgs.gzip}/bin/gzip -c \
        <(${pkgs.gnutar}/bin/tar -C /var/lib -cf - n8n) \
        > "$BACKUP_DIR/n8n-$TIMESTAMP.tar.gz"

      # Garder seulement les 7 derniers backups
      cd "$BACKUP_DIR"
      ls -t n8n-*.tar.gz | tail -n +8 | xargs -r rm

      echo "Backup n8n completed: n8n-$TIMESTAMP.tar.gz"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers."backup-n8n-data" = {
    description = "Daily n8n data backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Répertoires de backup
  systemd.tmpfiles.rules = [
    "d /var/backup 0750 root root -"
    "d /var/backup/postgresql 0750 postgres postgres -"
    "d /var/backup/n8n 0750 root root -"
  ];

  ########################################
  # 7) Monitoring et maintenance
  ########################################

  # Service de healthcheck n8n
  systemd.services."n8n-healthcheck" = {
    description = "Check n8n health";
    script = ''
      ${pkgs.curl}/bin/curl -f http://127.0.0.1:5678/healthz || {
        echo "n8n healthcheck failed!"
        exit 1
      }
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers."n8n-healthcheck" = {
    description = "Regular n8n healthcheck";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";  # Toutes les 5 minutes
      Persistent = false;
    };
  };
}
