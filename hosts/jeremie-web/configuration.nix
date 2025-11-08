{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Console série pour VM Proxmox
  boot.kernelParams = [ "console=ttyS0" ];
  console.earlySetup = true;

  # Système
  time.timeZone = "Europe/Paris";
  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "jeremie-web";
  networking.useDHCP = true;
  # Le firewall sera configuré automatiquement par le module j12z-webserver (ports 80, 443)
  networking.firewall.enable = true;

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
    # Mot de passe initial pour le premier boot (permet de déployer la config)
    # Utilisé uniquement à la création, jamais réécrit par la suite
    # Après le premier déploiement, sudo ne demandera plus de mot de passe (wheelNeedsPassword = false)
    initialPassword = "nixos";
  };

  # Root sans mot de passe (SSH root déjà interdit)
  users.users.root.password = null;

  # Sudo sans mot de passe pour le groupe wheel (sécurisé car SSH par clé uniquement)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # QEMU Guest Agent pour Proxmox
  services.qemuGuest.enable = true;

  # Configuration sops-nix pour la gestion des secrets
# sops = {
  #   defaultSopsFile = ../../secrets/jeremie-web.yaml;
  #   age = {
  #     keyFile = "/var/lib/sops-nix/key.txt";
  #   };
  #   secrets = {
  #     cloudflare-tunnel-token = {
  #       owner = "cloudflared";
  #       group = "cloudflared";
  #       mode = "0400";
  #     };
  #   };
  # };

  # Configuration du site j12zdotcom
  # Le module sera importé via flake.nix
 # services.j12z-webserver = {
  #  enable = true;
   # domain = "jeremiealcaraz.com";
   # email = "hello@jeremiealcaraz.com";
    # Cloudflare Tunnel activé avec sops
   # enableCloudflaredTunnel = false;
   # cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
#  };

  # Configuration Git globale
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "JeremieAlcaraz";
        email = "hello@jeremiealcaraz.com";
      };
    };
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Port pour SSH via Tailscale (par défaut Tailscale gère SSH)
    openFirewall = true;
  };

  # Paquets utiles
  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    htop
  ];
}
