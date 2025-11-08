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
    password = null;
  };

  # Root sans mot de passe (SSH root déjà interdit)
  users.users.root.password = null;

  # Sudo
  security.sudo.enable = true;

  # QEMU Guest Agent pour Proxmox
  services.qemuGuest.enable = true;

  # Configuration du site j12zdotcom
  # Le module sera importé via flake.nix
  services.j12z-webserver = {
    enable = true;
    domain = "jeremiealcaraz.com";
    email = "hello@jeremiealcaraz.com";
    # Si vous utilisez Cloudflare Tunnel, décommentez :
    # enableCloudflaredTunnel = true;
    # cloudflaredTokenFile = "/run/secrets/cloudflare-tunnel-token";
  };

  # Paquets utiles
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
  ];
}
