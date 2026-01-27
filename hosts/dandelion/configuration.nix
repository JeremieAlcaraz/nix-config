{ config, pkgs, lib, projectConfig, nixpkgs-unstable, ... }:

let
  # Gitea depuis nixpkgs-unstable pour avoir la dernière version
  unstablePkgs = import nixpkgs-unstable {
    system = "x86_64-linux";
  };

  catppuccinGiteaTheme = pkgs.fetchzip {
    url = "https://github.com/catppuccin/gitea/releases/download/v1.0.1/catppuccin-gitea.tar.gz";
    sha256 = "sha256-et5luA3SI7iOcEIQ3CVIu0+eiLs8C/8mOitYlWQa/uI=";
    stripRoot = false;
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ./gitea-runner.nix
    ./gitea-backup.nix  # Module de backup automatisé Gitea
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/dandelion.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix   # Configuration DNS pour MagicDNS
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
      # Secrets Gitea - accessible par l'utilisateur gitea
      "gitea/admin_password" = { owner = "gitea"; group = "gitea"; mode = "0400"; };
      "gitea/runner_registration_token" = { owner = "root"; group = "root"; mode = "0400"; };
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
    package = unstablePkgs.gitea;  # Dernière version depuis nixpkgs-unstable
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
        DOMAIN = projectConfig.gitForge.gitea.host;
        HTTP_ADDR = "0.0.0.0";  # Écoute sur toutes les interfaces (accessible via Tailscale)
        HTTP_PORT = projectConfig.gitForge.gitea.port;
        ROOT_URL = "${projectConfig.gitForge.gitea.url}/";

        # Configuration SSH
        START_SSH_SERVER = true;
        SSH_DOMAIN = projectConfig.gitForge.gitea.host;
        SSH_PORT = 22;  # Port SSH exposé dans les URLs (le vrai SSH système)
        SSH_LISTEN_PORT = 2222;  # Port d'écoute interne de Gitea
      };

      service = {
        DISABLE_REGISTRATION = true;  # Seul l'admin peut créer des comptes
      };

      actions = {
        ENABLED = true;
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

      # Thèmes UI
      ui = {
        DEFAULT_THEME = "catppuccin-mauve-auto";
        THEMES = "gitea,auto,arc-green,"
          + "catppuccin-blue-auto,catppuccin-flamingo-auto,catppuccin-green-auto,catppuccin-lavender-auto,catppuccin-maroon-auto,catppuccin-mauve-auto,catppuccin-peach-auto,catppuccin-pink-auto,catppuccin-red-auto,catppuccin-rosewater-auto,catppuccin-sapphire-auto,catppuccin-sky-auto,catppuccin-teal-auto,catppuccin-yellow-auto,"
          + "catppuccin-latte-blue,catppuccin-latte-flamingo,catppuccin-latte-green,catppuccin-latte-lavender,catppuccin-latte-maroon,catppuccin-latte-mauve,catppuccin-latte-peach,catppuccin-latte-pink,catppuccin-latte-red,catppuccin-latte-rosewater,catppuccin-latte-sapphire,catppuccin-latte-sky,catppuccin-latte-teal,catppuccin-latte-yellow,"
          + "catppuccin-frappe-blue,catppuccin-frappe-flamingo,catppuccin-frappe-green,catppuccin-frappe-lavender,catppuccin-frappe-maroon,catppuccin-frappe-mauve,catppuccin-frappe-peach,catppuccin-frappe-pink,catppuccin-frappe-red,catppuccin-frappe-rosewater,catppuccin-frappe-sapphire,catppuccin-frappe-sky,catppuccin-frappe-teal,catppuccin-frappe-yellow,"
          + "catppuccin-macchiato-blue,catppuccin-macchiato-flamingo,catppuccin-macchiato-green,catppuccin-macchiato-lavender,catppuccin-macchiato-maroon,catppuccin-macchiato-mauve,catppuccin-macchiato-peach,catppuccin-macchiato-pink,catppuccin-macchiato-red,catppuccin-macchiato-rosewater,catppuccin-macchiato-sapphire,catppuccin-macchiato-sky,catppuccin-macchiato-teal,catppuccin-macchiato-yellow,"
          + "catppuccin-mocha-blue,catppuccin-mocha-flamingo,catppuccin-mocha-green,catppuccin-mocha-lavender,catppuccin-mocha-maroon,catppuccin-mocha-mauve,catppuccin-mocha-peach,catppuccin-mocha-pink,catppuccin-mocha-red,catppuccin-mocha-rosewater,catppuccin-mocha-sapphire,catppuccin-mocha-sky,catppuccin-mocha-teal,catppuccin-mocha-yellow";
      };
    };
  };

  # Catppuccin theme pour Gitea
  systemd.tmpfiles.rules = [
    "d ${config.services.gitea.stateDir}/custom/public 0755 gitea gitea -"
    "d ${config.services.gitea.stateDir}/custom/public/assets 0755 gitea gitea -"
    "L+ ${config.services.gitea.stateDir}/custom/public/assets/css - - - - ${catppuccinGiteaTheme}"
    "d ${config.services.gitea.stateDir}/custom/public/assets/img 0755 gitea gitea -"
    "L+ ${config.services.gitea.stateDir}/custom/public/assets/img/logo.svg - - - - ${../../assets/logo.svg}"
    # CSS personnalisé pour corriger les problèmes de contraste
    "d ${config.services.gitea.stateDir}/custom/public/assets/custom 0755 gitea gitea -"
    "L+ ${config.services.gitea.stateDir}/custom/public/assets/custom/custom.css - - - - ${./gitea-custom/custom.css}"
    # Template personnalisé pour charger le CSS custom
    "d ${config.services.gitea.stateDir}/custom/templates 0755 gitea gitea -"
    "d ${config.services.gitea.stateDir}/custom/templates/custom 0755 gitea gitea -"
    "L+ ${config.services.gitea.stateDir}/custom/templates/custom/header.tmpl - - - - ${./gitea-custom/custom-header.tmpl}"
  ];

  # Firewall : Ouvrir les ports nécessaires
  networking.firewall = {
    allowedTCPPorts = [
      3000  # Gitea HTTP
      22    # SSH (pour git push/pull via SSH)
      2222  # Gitea SSH server interne
    ];
    # Autoriser le DNS interne des réseaux Podman (Gitea Actions)
    # Note: iptables est utilisé sur dandelion, donc on injecte des règles dédiées.
    extraCommands = ''
      iptables -I nixos-fw -i podman+ -p udp --dport 53 -j nixos-fw-accept
      iptables -I nixos-fw -i podman+ -p tcp --dport 53 -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -i podman+ -p udp --dport 53 -j nixos-fw-accept || true
      iptables -D nixos-fw -i podman+ -p tcp --dport 53 -j nixos-fw-accept || true
    '';
  };

  # Paquets système essentiels
  environment.systemPackages = with pkgs; [
    htop
    git
  ];

  ########################################
  # Gitea Backup - Backup automatisé vers Google Drive
  ########################################
  services.gitea-backup = {
    enable = true;
    schedule = "*-*-* 02:00:00";  # Tous les jours à 2h du matin
    retentionLocal = 7;  # Garder 7 backups locaux
    retentionGdrive = 90;  # Garder 90 jours sur Google Drive (plus critique que n8n)
  };

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

      echo "[gitea-setup] Configuration de l'utilisateur admin"

      # Attendre que Gitea soit prêt
      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -f http://127.0.0.1:3000/ >/dev/null 2>&1; then
          echo "[gitea-setup] Gitea est prêt !"
          break
        fi
        echo "[gitea-setup] Attente... ($i/30)"
        sleep 2
      done

      # Lire le mot de passe depuis sops
      ADMIN_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gitea/admin_password".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

      # Note: "admin" est un nom réservé, on utilise "gitadmin"
      ADMIN_USER="gitadmin"
      ADMIN_EMAIL="gitadmin@dandelion.local"
      PSQL="${pkgs.postgresql}/bin/psql"

      ADMIN_EXISTS="$($PSQL -tA -h /run/postgresql -U gitea -d gitea \
        -c "SELECT 1 FROM \"user\" WHERE lower(name)=lower('$ADMIN_USER') LIMIT 1;" 2>/dev/null || true)"
      EMAIL_IN_USE="$($PSQL -tA -h /run/postgresql -U gitea -d gitea \
        -c "SELECT 1 FROM email_address WHERE lower(email)=lower('$ADMIN_EMAIL') LIMIT 1;" 2>/dev/null || true)"

      if [ "$ADMIN_EXISTS" = "1" ]; then
        echo "[gitea-setup] L'utilisateur $ADMIN_USER existe déjà, mise à jour du mot de passe..."
        ${pkgs.gitea}/bin/gitea admin user change-password \
          --username "$ADMIN_USER" \
          --password "$ADMIN_PASSWORD"
      elif [ "$EMAIL_IN_USE" = "1" ]; then
        echo "[gitea-setup] Email $ADMIN_EMAIL déjà utilisé, aucun nouvel utilisateur créé."
        exit 0
      else
        echo "[gitea-setup] Création de l'utilisateur $ADMIN_USER..."
        ${pkgs.gitea}/bin/gitea admin user create \
          --username "$ADMIN_USER" \
          --password "$ADMIN_PASSWORD" \
          --email "$ADMIN_EMAIL" \
          --admin \
          --must-change-password=false
      fi

      echo "[gitea-setup] Configuration admin terminée !"
    '';
    path = [ pkgs.gitea ];
    environment = {
      GITEA_WORK_DIR = config.services.gitea.stateDir;
      GITEA_CUSTOM = "${config.services.gitea.stateDir}/custom";
    };
  };
}
