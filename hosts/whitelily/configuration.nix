{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./n8n.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Console série Proxmox
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  console.earlySetup = true;

  time.timeZone = "Europe/Paris";
  system.stateVersion = "25.05";

  # Activer les flakes et nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Réseau
  networking.hostName = "whitelily";  # VM n8n automation
  networking.useDHCP = true;
  # Configuration DNS (resolvconf désactivé, donc configuration manuelle)
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];
  # Firewall activé (Cloudflare Tunnel = trafic sortant uniquement)
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ]; # Aucun port public ouvert

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PubkeyAuthentication = true;
    PermitRootLogin = "no";
  };

  # Clés SSH autorisées
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

  users.mutableUsers = false;

  # Utilisateur jeremie
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    # Hash du mot de passe stocké de manière sécurisée dans sops
    hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
    shell = pkgs.zsh;
  };

  # Root sans mot de passe (SSH root déjà interdit)
  users.users.root.password = null;

  # Sudo - Permet au groupe wheel d'exécuter toutes les commandes sans mot de passe
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    defaultSopsFile = ../../secrets/whitelily.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
    };
    secrets = {
      # Hash du mot de passe de l'utilisateur jeremie
      jeremie-password-hash = {
        neededForUsers = true;
      };
      # Secrets n8n (utilisés dans n8n.nix)
      "n8n/encryption_key" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/basic_user" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/basic_pass" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/db_password" = { owner = "postgres"; group = "postgres"; mode = "0400"; };
      # Cloudflare Tunnel token (simplifié)
      "cloudflared/token" = { owner = "cloudflared"; group = "cloudflared"; mode = "0400"; };
    };
  };

  # ZSH activé au niveau système (requis pour users.users.jeremie.shell)
  # La configuration ZSH détaillée est gérée par Home Manager
  programs.zsh.enable = true;

  # Tmux au niveau système
  programs.tmux.enable = true;

  # Paquets système essentiels
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    restic  # Pour les backups
    gzip
  ];
}
