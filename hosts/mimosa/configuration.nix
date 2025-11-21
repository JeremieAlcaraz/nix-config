{ config, pkgs, ... }:

{
 imports = [
    ./hardware-configuration.nix
    ../../modules/tailscale.nix  # <--- AJOUTE ÇA
    # ... tes autres imports
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Console série pour VM Proxmox
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  console.earlySetup = true;

  # Système
  time.timeZone = "Europe/Paris";
  system.stateVersion = "24.05";

  # Activer les flakes et nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Réseau
  networking.hostName = "mimosa";  # Serveur web
  networking.useDHCP = true;
  # Firewall : SSH + Tailscale + Web (ports gérés par j12z-webserver)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH
    # Les autres ports (80, 443) seront ouverts par j12z-webserver
  };

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PubkeyAuthentication = true;
    PermitRootLogin = "no";
  };

  # Configuration SSH pour l'utilisateur jeremie
  services.openssh.authorizedKeysFiles = [
    "/etc/ssh/authorized_keys.d/%u"
    "~/.ssh/authorized_keys"
  ];

  environment.etc."ssh/authorized_keys.d/jeremie" = {
    text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
    '';
    mode = "0644";
  };

  # Utilisateur
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    # Hash du mot de passe stocké de manière sécurisée dans sops
    # Le fichier de secrets est chiffré et ne peut être déchiffré que par l'hôte
    hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
  };

  # Root sans mot de passe (SSH root déjà interdit)
  users.users.root.password = null;

  # Sudo sans mot de passe pour le groupe wheel (sécurisé car SSH par clé uniquement)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

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
  programs.fish.enable = true;

  # Shell par défaut pour l'utilisateur jeremie
  users.users.jeremie.shell = pkgs.fish;

  # Paquets système essentiels
  # Note: git est maintenant géré par modules/git.nix (importé via base.nix)
  environment.systemPackages = with pkgs; [
    curl
    wget
  ];
}
