# hosts/demo/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/tailscale.nix
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
  networking.hostName = "demo";
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  networking.resolvconf.enable = false;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PubkeyAuthentication = true;
    PermitRootLogin = "no";
  };

  services.openssh.authorizedKeysFiles = [
    "/etc/ssh/authorized_keys.d/%u"
    "~/.ssh/authorized_keys"
  ];

  # Utilisateurs immuables
  users.mutableUsers = false;

  # Clés SSH autorisées pour jeremie
  environment.etc."ssh/authorized_keys.d/jeremie" = {
    text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
    '';
    mode = "0644";
  };

  # Utilisateur jeremie (pas de mot de passe, SSH uniquement)
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    password = null;
  };

  # Sudo sans mot de passe (sécurisé car SSH par clé uniquement)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Configuration sops-nix pour la gestion des secrets communs (Tailscale)
  sops = {
    defaultSopsFile = ../../secrets/common.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  # Fish activé au niveau système (requis pour users.users.jeremie.shell)
  # La configuration Fish détaillée est gérée par Home Manager
  programs.fish.enable = true;

  # ZSH - Commenté (remplacé par Fish)
  # programs.zsh.enable = true;

  programs.tmux.enable = true;

  # Shell par défaut pour jeremie
  users.users.jeremie.shell = pkgs.fish;

  # Paquets système essentiels
  # Note: git est maintenant géré par modules/git.nix (importé via base.nix)
  environment.systemPackages = with pkgs; [ curl wget ];
}
