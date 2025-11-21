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
  networking.hostName = "magnolia";  # Infrastructure Proxmox
  networking.useDHCP = true;
  networking.firewall.enable = false;
  # Désactiver resolvconf (DHCP gère déjà le DNS)
  networking.resolvconf.enable = false;

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

  users.mutableUsers = false;

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

  # Si tu utilises l'Option A, définis tout de même l'utilisateur :
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

  # Sudo - Permet au groupe wheel d'exécuter toutes les commandes sans mot de passe
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    defaultSopsFile = ../../secrets/magnolia.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
    };
    secrets = {
      # Hash du mot de passe de l'utilisateur jeremie
      jeremie-password-hash = {
        neededForUsers = true;
      };
    };
  };

  # ZSH activé au niveau système (requis pour users.users.jeremie.shell)
  # La configuration ZSH détaillée est gérée par Home Manager
  programs.zsh.enable = true;

  # Tmux au niveau système
  programs.tmux.enable = true;

  # Shell par défaut pour l'utilisateur jeremie
  users.users.jeremie.shell = pkgs.zsh;

  # Paquets système essentiels
  # Note: git est maintenant géré par modules/git.nix (importé via base.nix)
  environment.systemPackages = with pkgs; [ curl wget ];
}
