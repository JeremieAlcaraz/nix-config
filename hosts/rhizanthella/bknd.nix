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
      cat > /run/bknd/env <<EOF
      DB_URL=postgres://bknd:$DB_PASSWORD@127.0.0.1:5432/bknd
      HOST=0.0.0.0
      PORT=1337
      EOF

      chmod 600 /run/bknd/env

      echo "[bknd-envfile] Fichier d'environnement généré"
    '';
  };

  ########################################
  # Service de build de l'image bknd depuis GitHub
  ########################################
  systemd.services."bknd-image-build" = {
    description = "Build bknd container image from GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";  # Le build peut prendre du temps
    };
    path = [ pkgs.git pkgs.podman pkgs.coreutils ];
    script = ''
      set -euo pipefail

      echo "[bknd-image-build] Vérification de l'image bknd..."

      # Vérifier si l'image existe déjà
      if podman image exists bknd:latest; then
        echo "[bknd-image-build] L'image bknd:latest existe déjà"
        exit 0
      fi

      echo "[bknd-image-build] Build de l'image depuis GitHub..."
      podman build \
        -t bknd:latest \
        https://github.com/bknd-io/bknd.git#main:docker

      echo "[bknd-image-build] Build terminé !"
    '';
  };

  ########################################
  # Conteneur bknd via Podman
  ########################################
  virtualisation.oci-containers = {
    backend = "podman";
    containers.bknd = {
      image = "bknd:latest";
      autoStart = true;

      # network=host pour accéder à PostgreSQL sur 127.0.0.1
      extraOptions = [ "--network=host" ];

      # Variables d'environnement (DB_URL est passé via fichier)
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
