{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Console série pour VM Proxmox
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  console.earlySetup = true;

  # Système
  time.timeZone = "Europe/Paris";
  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "mimosa";  # Serveur web
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
      # Token Cloudflare Tunnel (optionnel, décommenter si utilisé)
      cloudflare-tunnel-token = {
        owner = "cloudflared";
        group = "cloudflared";
        mode = "0400";
      };
    };
  };

  # Configuration du site j12zdotcom
  # Le module sera importé via flake.nix
  # Note: peut être désactivé pendant l'installation avec NIXOS_MINIMAL_INSTALL=true
  services.j12z-webserver = {
    enable = builtins.getEnv "NIXOS_MINIMAL_INSTALL" != "true";
    domain = "jeremiealcaraz.com";
    email = "hello@jeremiealcaraz.com";
    # Cloudflare Tunnel activé avec sops
    enableCloudflaredTunnel = true;
    cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
  };

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

  # Configuration Fish shell
  programs.fish = {
    enable = true;
  };

  # Configuration Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
    };
  };

  # Message de bienvenue personnalisé
  programs.fish.interactiveShellInit = ''
    echo ""
    echo "🌼 Mimosa - Serveur web"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  '';

  # Shell par défaut pour l'utilisateur jeremie
  users.users.jeremie.shell = pkgs.fish;

  # Paquets utiles
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    tree
  ];
}
