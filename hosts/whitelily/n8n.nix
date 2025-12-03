{ config, pkgs, lib, ... }:

let
  # Configuration du domaine n8n
  domain = "n8n.jeremiealcaraz.com";  # ← À adapter selon ton domaine

  # Script pour lancer cloudflared avec le token depuis sops
  cloudflaredTunnelScript = pkgs.writeShellScript "cloudflared-tunnel" ''
    set -euo pipefail

    # Lire le token et extraire la valeur
    # Le secret sops peut contenir soit "token: eyJxxxx" soit juste "eyJxxxx"
    # On gère les deux cas comme pour les secrets n8n
    TOKEN="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cloudflared/token".path} | ${pkgs.findutils}/bin/xargs | ${pkgs.gawk}/bin/awk '{if (NF==2) print $2; else print $0}')"

    exec ${pkgs.cloudflared}/bin/cloudflared tunnel run --token "$TOKEN"
  '';

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
      # Listen on all interfaces to allow podman containers to connect
      listen_addresses = lib.mkForce "0.0.0.0";
    };
    # Allow connections from localhost and podman containers
    authentication = lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      # "local" is for Unix domain socket connections only
      local   all             all                                     peer
      # IPv4 local connections
      host    all             all             127.0.0.1/32            scram-sha-256
      # IPv6 local connections
      host    all             all             ::1/128                 scram-sha-256
      # Allow podman containers to connect (podman default bridge network)
      host    all             all             10.88.0.0/16            scram-sha-256
      # Alternative podman networks
      host    all             all             10.89.0.0/16            scram-sha-256
    '';
  };

  # Service systemd pour configurer le mot de passe PostgreSQL
  # S'exécute en root pour avoir accès aux secrets sops
  systemd.services."postgresql-n8n-setup" = {
    description = "Setup n8n PostgreSQL user with password from sops";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";  # S'exécute en root pour accéder aux secrets sops
    };
    script = ''
      set -euo pipefail

      echo "[n8n-setup] Début de la configuration du mot de passe PostgreSQL"

      # Vérifier que le secret existe
      if [ ! -f /run/secrets/n8n/db_password ]; then
        echo "[n8n-setup] ERREUR: Le secret /run/secrets/n8n/db_password n'existe pas !"
        exit 1
      fi

      # Nettoyer le mot de passe (enlever newlines, guillemets, espaces)
      DB_PASS=$(${pkgs.coreutils}/bin/cat /run/secrets/n8n/db_password | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

      echo "[n8n-setup] Mot de passe lu et nettoyé (longueur: ''${#DB_PASS} caractères)"

      # Attendre que PostgreSQL soit vraiment prêt
      echo "[n8n-setup] Attente que PostgreSQL soit prêt..."
      for i in {1..30}; do
        if ${pkgs.postgresql}/bin/pg_isready -h localhost -U postgres >/dev/null 2>&1; then
          echo "[n8n-setup] PostgreSQL est prêt !"
          break
        fi
        echo "[n8n-setup] Attente... ($i/30)"
        sleep 1
      done

      # Mettre à jour le mot de passe
      echo "[n8n-setup] Configuration du mot de passe pour l'utilisateur n8n"
      ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/psql -tA <<EOF
ALTER USER n8n WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
EOF

      # Configurer les permissions sur le schéma public
      echo "[n8n-setup] Configuration des permissions sur le schéma public"
      ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/psql -d n8n -tA <<EOF
ALTER SCHEMA public OWNER TO n8n;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON SCHEMA public TO n8n;
EOF

      echo "[n8n-setup] Configuration PostgreSQL terminée avec succès !"
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

      # Lire les secrets et nettoyer TOUS les caractères parasites
      # tr -d '\n"' enlève les retours à la ligne ET les guillemets
      # xargs nettoie les espaces blancs
      ENCRYPTION_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."n8n/encryption_key".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs | ${pkgs.gawk}/bin/awk '{if (NF==2) print $2; else print $0}')
      BASIC_USER=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."n8n/basic_user".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs | ${pkgs.gawk}/bin/awk '{if (NF==2) print $2; else print $0}')
      BASIC_PASS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."n8n/basic_pass".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs | ${pkgs.gawk}/bin/awk '{if (NF==2) print $2; else print $0}')
      DB_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."n8n/db_password".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs | ${pkgs.gawk}/bin/awk '{if (NF==2) print $2; else print $0}')

      # Créer le fichier .env SANS guillemets autour des valeurs
      # PostgreSQL n'accepte PAS les guillemets dans le mot de passe !
      cat > /run/n8n/n8n.env <<EOF
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$BASIC_USER
N8N_BASIC_AUTH_PASSWORD=$BASIC_PASS
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=127.0.0.1
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=$DB_PASSWORD
DB_POSTGRESDB_CONNECTION_TIMEOUT=30000
EOF

      chmod 0600 /run/n8n/n8n.env
    '';
  };

  # Container n8n
  virtualisation.oci-containers = {
    backend = "podman";
    containers.n8n = {
      image = "docker.io/n8nio/n8n:next@sha256:e1c87fb78c3d3f58f08263fb4710a270453982945616d5fc4ddb60f4524c51fc";  # Tag next pour les dernières betas
      autoStart = true;
      # Pas de ports mapping avec --network host (le conteneur utilise directement les ports de l'hôte)

      environment = {
        N8N_HOST = domain;
        N8N_PORT = "5678";
        N8N_PROTOCOL = "https";
        WEBHOOK_URL = "https://${domain}/";
        GENERIC_TIMEZONE = "Europe/Paris";
        N8N_LOG_LEVEL = "info";

        # Désactiver la télémétrie
        N8N_DIAGNOSTICS_ENABLED = "false";
        N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
        N8N_TEMPLATES_ENABLED = "true";
        N8N_PUBLIC_API_DISABLED = "false";

        # Configuration reverse proxy (Cloudflare Tunnel → Caddy → n8n)
        # Active trust proxy pour les headers X-Forwarded-*
        N8N_PROXY_HOPS = "1";

        # Configuration des permissions et sécurité
        N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS = "true";
        N8N_RUNNERS_ENABLED = "true";
        N8N_BLOCK_ENV_ACCESS_IN_NODE = "false";
        N8N_GIT_NODE_DISABLE_BARE_REPOS = "true";
      };

      extraOptions = [
        # Utiliser le réseau de l'hôte pour accéder à PostgreSQL sur 127.0.0.1
        "--network=host"
        # Volume pour les données persistantes
        "--volume=/var/lib/n8n:/home/node/.n8n"
        # Fichier d'environnement avec les secrets (contient les variables DB_*)
        # Déplacé de /run/secrets vers /run/n8n pour éviter que sops-nix le supprime
        "--env-file=/run/n8n/n8n.env"
        # Note: Pas de healthcheck Podman, on utilise le timer systemd dédié (n8n-healthcheck.timer)
        # qui vérifie toutes les 5 minutes sans polluer les logs de nixos-rebuild
      ];
    };
  };

  # Ajouter les dépendances au service généré par oci-containers
  systemd.services."podman-n8n" = {
    after = [ "n8n-envfile.service" "postgresql-n8n-setup.service" ];
    requires = [ "n8n-envfile.service" "postgresql-n8n-setup.service" ];
  };

  # Répertoires de données et de backup
  systemd.tmpfiles.rules = [
    # Données n8n, Caddy et Cloudflared
    # n8n tourne en tant qu'utilisateur node (UID 1000) dans le conteneur
    "d /var/lib/n8n 0750 1000 1000 -"
    "d /run/n8n 0700 root root -"  # Pour le fichier n8n.env
    "d /var/log/caddy 0750 caddy caddy -"
    "d /var/lib/cloudflared 0750 cloudflared cloudflared -"
    # Backups
    "d /var/backup 0750 root root -"
    "d /var/backup/postgresql 0750 postgres postgres -"
    "d /var/backup/n8n 0750 root root -"
  ];

  ########################################
  # 4) Caddy en reverse proxy
  ########################################
  services.caddy = {
    enable = true;

    # Configuration globale
    globalConfig = ''
      # API admin accessible uniquement en local (nécessaire pour les reloads)
      admin localhost:2019
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

  ########################################
  # 5) Cloudflare Tunnel
  ########################################
  # Configuration simplifiée avec token
  # Plus besoin de JSON credentials compliqué !
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel for n8n";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "cloudflared";
      Group = "cloudflared";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = "${cloudflaredTunnelScript}";
      # Sécurité
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/cloudflared" ];
    };
  };

  # Créer l'utilisateur cloudflared
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
    home = "/var/lib/cloudflared";
    createHome = true;
  };
  users.groups.cloudflared = {};

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
