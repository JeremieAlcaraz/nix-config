{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/ssh.nix
    ../../modules/tailscale.nix  # <--- AJOUTE ÇA
    # ... tes autres imports
  ];

  # Système
  time.timeZone = "Europe/Paris";
  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "mimosa";  # Serveur web
  networking.useDHCP = true;
  # Firewall : SSH + Tailscale + Web (ports gérés par j12z-webserver)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH
    # Les autres ports (80, 443) seront ouverts par j12z-webserver
  };

  sshCommon = {
    jeremieShell = pkgs.fish;
    jeremieHashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
    enableTmux = false;
  };

  # QEMU Guest Agent pour Proxmox
  services.qemuGuest.enable = true;

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    defaultSopsFile = ../../secrets/mimosa.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
    };
    secrets = {
      # Hash du mot de passe de l'utilisateur jeremie
      jeremie-password-hash = {
        neededForUsers = true;
      };
      # Note: Le secret cloudflare-tunnel-token est défini dans webserver.nix
      # qui est importé uniquement dans la configuration "mimosa" complète
    };
  };

  # Configuration du site j12zdotcom
  # La configuration du serveur web est dans ./webserver.nix
  # Ce fichier est importé uniquement dans la configuration "mimosa" complète (via flake.nix)
  # La configuration "mimosa-minimal" n'importe PAS ce fichier pour éviter
  # les téléchargements npm pendant l'installation initiale
  # Activer/désactiver facilement le serveur web pour éviter les builds durant le boot
  mimosa.webserver.enable = false; # Passer à true pour réactiver le déploiement web

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    # openFirewall géré par networking.firewall au-dessus
    openFirewall = false;
  };

  # Fish activé au niveau système (requis pour users.users.jeremie.shell)
  # La configuration Fish détaillée est gérée par Home Manager
}
