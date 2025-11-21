# hosts/demo/configuration.nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

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
  networking.firewall.enable = false;
  networking.resolvconf.enable = false;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PubkeyAuthentication = true;
    PermitRootLogin = "no";
  };

  # Utilisateurs immuables
  users.mutableUsers = false;

  # Utilisateur jeremie (pas de mot de passe, SSH uniquement)
  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
    ];
  };

  # Sudo sans mot de passe (sécurisé car SSH par clé uniquement)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # ZSH activé au niveau système
  programs.zsh.enable = true;
  programs.tmux.enable = true;

  # Shell par défaut pour jeremie
  users.users.jeremie.shell = pkgs.zsh;

  # Paquets système essentiels
  # Note: git est maintenant géré par modules/git.nix (importé via base.nix)
  environment.systemPackages = with pkgs; [ curl wget ];
}
