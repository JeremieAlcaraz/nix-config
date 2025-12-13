{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/dandelion.yaml; })
    ../../modules/tailscale.nix
    ../../modules/tailscale-dns.nix   # Configuration DNS pour MagicDNS
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "dandelion";  # VM Gitea - serveur Git auto-hébergé
  networking.useDHCP = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    age = {
      # Utiliser UNIQUEMENT la clé age partagée (copiée depuis le Mac)
      keyFile = "/var/lib/sops-nix/key.txt";
      # Désactiver les clés SSH pour forcer l'utilisation de keyFile
      sshKeyPaths = [];
    };
    secrets = {
      # Secrets Gitea
      "gitea/admin_password" = { owner = "root"; group = "root"; mode = "0400"; };
    };
  };

  ########################################
  # PostgreSQL pour Gitea
  ########################################
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "gitea" ];
    ensureUsers = [{
      name = "gitea";
      ensureDBOwnership = true;
    }];
  };

  ########################################
  # Gitea - Serveur Git auto-hébergé
  ########################################
  services.gitea = {
    enable = true;
    appName = "Dandelion";  # Nom affiché sur la page d'accueil

    # Base de données
    database = {
      type = "postgres";
      host = "/run/postgresql";  # Socket Unix pour PostgreSQL local
      name = "gitea";
      user = "gitea";
    };

    # Configuration du serveur
    settings = {
      server = {
        DOMAIN = "dandelion";
        HTTP_ADDR = "0.0.0.0";  # Écoute sur toutes les interfaces (accessible via Tailscale)
        HTTP_PORT = 3000;
        ROOT_URL = "http://dandelion:3000/";
      };

      service = {
        DISABLE_REGISTRATION = true;  # Seul l'admin peut créer des comptes
      };

      # Timeouts pour les gros miroirs GitHub
      "git.timeout" = {
        DEFAULT = 3600;
        MIGRATE = 3600;
        MIRROR = 3600;
        CLONE = 3600;
        PULL = 3600;
        GC = 3600;
      };

      # Configuration des logs
      log = {
        LEVEL = "Info";
      };

      # Désactiver la télémétrie
      metrics = {
        ENABLED = false;
      };

      # Configuration des sessions
      session = {
        PROVIDER = "db";  # Stocker les sessions en base de données
      };
    };
  };

  # Firewall : Ouvrir les ports nécessaires
  networking.firewall = {
    allowedTCPPorts = [
      3000  # Gitea HTTP
      22    # SSH (pour git push/pull via SSH)
    ];
  };

  # Paquets système essentiels
  environment.systemPackages = with pkgs; [
    htop
    git
  ];

  # Service systemd pour créer l'utilisateur admin Gitea avec mot de passe depuis sops
  # Ce service s'exécute après le premier démarrage de Gitea
  systemd.services."gitea-admin-setup" = {
    description = "Setup Gitea admin user with password from sops";
    after = [ "gitea.service" ];
    requires = [ "gitea.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "gitea";
    };
    script = ''
      set -euo pipefail

      echo "[gitea-setup] Vérification de l'utilisateur admin"

      # Attendre que Gitea soit prêt
      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -f http://127.0.0.1:3000/ >/dev/null 2>&1; then
          echo "[gitea-setup] Gitea est prêt !"
          break
        fi
        echo "[gitea-setup] Attente... ($i/30)"
        sleep 2
      done

      # Vérifier si l'admin existe déjà
      if ${pkgs.gitea}/bin/gitea admin user list --admin | ${pkgs.gnugrep}/bin/grep -q "^admin$" 2>/dev/null; then
        echo "[gitea-setup] L'utilisateur admin existe déjà"
      else
        echo "[gitea-setup] Création de l'utilisateur admin"

        # Lire le mot de passe depuis sops
        ADMIN_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gitea/admin_password".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

        # Créer l'utilisateur admin
        ${pkgs.gitea}/bin/gitea admin user create \
          --username admin \
          --password "$ADMIN_PASSWORD" \
          --email admin@dandelion.local \
          --admin \
          --must-change-password=false

        echo "[gitea-setup] Utilisateur admin créé avec succès !"
      fi
    '';
    path = [ pkgs.gitea ];
    environment = {
      GITEA_WORK_DIR = config.services.gitea.stateDir;
      GITEA_CUSTOM = "${config.services.gitea.stateDir}/custom";
    };
  };
}
