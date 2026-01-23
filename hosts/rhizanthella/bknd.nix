{ config, pkgs, lib, ... }:

{
  ########################################
  # Podman pour conteneurs OCI
  ########################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # Alias docker -> podman
    defaultNetwork.settings.dns_enabled = true;
  };

  ########################################
  # Service de configuration PostgreSQL pour bknd
  ########################################
  systemd.services."postgresql-bknd-setup" = {
    description = "Setup PostgreSQL user for bknd with password from sops";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
    };
    script = ''
      set -euo pipefail

      echo "[postgresql-bknd-setup] Configuration de l'utilisateur bknd"

      # Lire le mot de passe depuis sops
      DB_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."bknd/db_password".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

      # Vérifier si l'utilisateur existe
      USER_EXISTS=$(${pkgs.postgresql}/bin/psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='bknd'" 2>/dev/null || echo "0")

      if [ "$USER_EXISTS" = "1" ]; then
        echo "[postgresql-bknd-setup] L'utilisateur bknd existe, mise à jour du mot de passe..."
        ${pkgs.postgresql}/bin/psql -c "ALTER USER bknd WITH PASSWORD '$DB_PASSWORD';"
      else
        echo "[postgresql-bknd-setup] Création de l'utilisateur bknd..."
        ${pkgs.postgresql}/bin/psql -c "CREATE USER bknd WITH PASSWORD '$DB_PASSWORD';"
        ${pkgs.postgresql}/bin/psql -c "GRANT ALL PRIVILEGES ON DATABASE bknd TO bknd;"
      fi

      # S'assurer que l'utilisateur est propriétaire de la base
      ${pkgs.postgresql}/bin/psql -c "ALTER DATABASE bknd OWNER TO bknd;" || true

      echo "[postgresql-bknd-setup] Configuration terminée !"
    '';
  };

  ########################################
  # Service de génération du fichier d'environnement bknd
  ########################################
  systemd.services."bknd-envfile" = {
    description = "Generate bknd environment file with database URL";
    after = [ "postgresql-bknd-setup.service" ];
    requires = [ "postgresql-bknd-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      echo "[bknd-envfile] Génération du fichier d'environnement"

      # Lire le mot de passe depuis sops
      DB_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."bknd/db_password".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

      # Créer le répertoire si nécessaire
      mkdir -p /run/bknd

      # Générer le fichier d'environnement
      # DEFAULT_ARGS surcharge les arguments par défaut de l'image (qui pointent vers SQLite)
      DB_URL="postgresql://bknd:$DB_PASSWORD@127.0.0.1:5432/bknd"
      cat > /run/bknd/env << 'ENVFILE'
HOST=0.0.0.0
PORT=1337
ENVFILE
      echo "DEFAULT_ARGS=--db-url $DB_URL" >> /run/bknd/env

      chmod 600 /run/bknd/env

      echo "[bknd-envfile] Fichier d'environnement généré :"
      cat /run/bknd/env
    '';
  };

  ########################################
  # Service de build de l'image bknd avec support PostgreSQL
  ########################################
  systemd.services."bknd-image-build" = {
    description = "Build bknd container image with PostgreSQL support";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";
    };
    path = [ pkgs.podman pkgs.coreutils ];
    script = let
      # Dockerfile personnalisé avec support PostgreSQL
      dockerfile = pkgs.writeText "Dockerfile" ''
        FROM node:24-alpine
        WORKDIR /app
        RUN npm install -g bknd pg
        RUN mkdir -p /data
        ENV HOST=0.0.0.0
        ENV PORT=1337
        EXPOSE 1337
        CMD ["bknd", "run"]
      '';
    in ''
      set -euo pipefail

      echo "[bknd-image-build] Vérification de l'image bknd-pg..."

      # Toujours reconstruire pour s'assurer que PostgreSQL est inclus
      # (on peut ajouter un tag version plus tard pour éviter les rebuilds)

      echo "[bknd-image-build] Build de l'image avec support PostgreSQL..."

      # Créer un contexte de build temporaire
      BUILD_DIR=$(mktemp -d)
      cp ${dockerfile} "$BUILD_DIR/Dockerfile"

      podman build \
        -t localhost/bknd:latest \
        "$BUILD_DIR"

      rm -rf "$BUILD_DIR"

      echo "[bknd-image-build] Build terminé avec support PostgreSQL !"
    '';
  };

  ########################################
  # Conteneur bknd via Podman
  ########################################
  virtualisation.oci-containers = {
    backend = "podman";
    containers.bknd = {
      image = "localhost/bknd:latest";
      autoStart = true;

      # network=host pour accéder à PostgreSQL sur 127.0.0.1
      extraOptions = [ "--network=host" ];

      # Variables d'environnement (incluant DEFAULT_ARGS pour PostgreSQL)
      environmentFiles = [ "/run/bknd/env" ];

      # Le port 1337 est exposé directement via network=host
      # ports = [ "1337:1337" ];  # Pas nécessaire avec network=host

      # Dépendances
      dependsOn = [];
    };
  };

  # S'assurer que le conteneur démarre après le build de l'image et la génération de l'envfile
  systemd.services."podman-bknd" = {
    after = [ "bknd-image-build.service" "bknd-envfile.service" "postgresql.service" ];
    requires = [ "bknd-image-build.service" "bknd-envfile.service" "postgresql.service" ];
  };
}
