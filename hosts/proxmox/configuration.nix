{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Console série Proxmox
  boot.kernelParams = [ "console=ttyS0" ];
  console.earlySetup = true;

  time.timeZone = "Europe/Paris";
  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "nixos";
  networking.useDHCP = true;
  networking.firewall.enable = false;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PubkeyAuthentication = true;
    PermitRootLogin = "no";
  };

  # 👉 Choisis UNE des 2 options ci-dessous (A ou B). Laisse l’autre commentée.

  ## === Option A: /etc/ssh/authorized_keys.d/jeremie (recommandée) ===
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

  ## === Option B: ~/.ssh/authorized_keys (alternative classique) ===
  # users.users.jeremie = {
  #   isNormalUser = true;
  #   createHome = true;
  #   home = "/home/jeremie";
  #   extraGroups = [ "wheel" ];
  #   password = null;
  #   openssh.authorizedKeys.keys = [
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
  #   ];
  # };

  # Si tu utilises l’Option A, définis tout de même l’utilisateur :
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$vwZmaAkvi9Sjgv60$HVIr50fg9sFmFrgJ7CCtEhey0m7OBLepLDWAa1PcdZSX3WrK24DWs48IQpHi85u4yYwjG0xHwC4waXzb3IqLB1";
  };

  # Root sans mot de passe (SSH root déjà interdit)
  users.users.root.password = null;

  # Sudo
  security.sudo.enable = true;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Paquets utiles
  environment.systemPackages = with pkgs; [ vim git curl wget htop ];

  programs.tmux.enable = true;
}
