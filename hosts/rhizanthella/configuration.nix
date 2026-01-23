{ config, pkgs, lib, projectConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./bknd.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/rhizanthella.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix   # Configuration DNS pour MagicDNS
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "rhizanthella";  # VM bknd - Backend-as-a-Service
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
      # Secrets bknd - accessible par root pour générer l'envfile
      "bknd/db_password" = { owner = "postgres"; group = "postgres"; mode = "0400"; };
    };
  };

  ########################################
  # PostgreSQL pour bknd
  ########################################
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "bknd" ];
    # L'utilisateur bknd est créé par postgresql-bknd-setup avec mot de passe
    # (ensureUsers ne supporte pas les mots de passe)

    settings = {
      listen_addresses = lib.mkForce "*";
    };

    # Authentification par mot de passe pour les connexions TCP
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
      host    bknd            bknd            100.64.0.0/10           md5
    '';
  };

  ########################################
  # Backup PostgreSQL basique
  ########################################
  services.postgresqlBackup = {
    enable = true;
    databases = [ "bknd" ];
    startAt = "*-*-* 03:00:00";  # Tous les jours à 3h du matin
    location = "/var/backup/postgresql";
    compression = "zstd";
  };

  # Firewall : limiter l'exposition aux interfaces Tailscale
  networking.firewall = {
    interfaces."tailscale0".allowedTCPPorts = [ 1337 5432 ];
  };

  # Paquets système essentiels
  environment.systemPackages = with pkgs; [
    htop
    git
  ];
}
