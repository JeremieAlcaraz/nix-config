{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkOption optional types;
  cfg = config.sshCommon;

  defaultJeremieKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac";

  jeremiePasswordAttrs =
    if cfg.jeremieHashedPasswordFile != null then
      { hashedPasswordFile = cfg.jeremieHashedPasswordFile; }
    else
      { password = cfg.jeremiePassword; };

  jeremieAuthorizedKeys = [ defaultJeremieKey ] ++ cfg.extraAuthorizedKeys;

in {
  options.sshCommon = {
    sshPort = mkOption {
      type = types.port;
      default = 22;
      description = "Port SSH principal à ouvrir dans le pare-feu.";
    };

    authorizedKeysFiles = mkOption {
      type = types.listOf types.str;
      default = [ "/etc/ssh/authorized_keys.d/%u" "~/.ssh/authorized_keys" ];
      description = "Emplacements des fichiers de clés autorisées pour OpenSSH.";
    };

    extraAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Clés SSH supplémentaires autorisées pour l'utilisateur jeremie.";
    };

    jeremieShell = mkOption {
      type = types.package;
      default = pkgs.zsh;
      description = "Shell par défaut pour l'utilisateur jeremie.";
    };

    jeremiePassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Mot de passe en clair pour l'utilisateur jeremie (par défaut aucun).";
    };

    jeremieHashedPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Fichier contenant le mot de passe haché de l'utilisateur jeremie.";
    };

    extraSshdSettings = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
      description = "Paramètres supplémentaires à fusionner dans services.openssh.settings.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Paquets supplémentaires à installer à côté des utilitaires de base.";
    };

    enableTmux = mkOption {
      type = types.bool;
      default = true;
      description = "Active tmux et l'ajoute aux paquets système.";
    };
  };

  config = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Console série Proxmox
    boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
    console.earlySetup = true;

    # Activer les flakes et nix-command
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    networking.firewall.allowedTCPPorts = [ cfg.sshPort ];

    services.openssh = {
      enable = true;
      settings = mkMerge [
        {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PubkeyAuthentication = true;
          PermitRootLogin = "no";
        }
        cfg.extraSshdSettings
      ];
      authorizedKeysFiles = cfg.authorizedKeysFiles;
    };

    users.mutableUsers = false;

    environment.etc."ssh/authorized_keys.d/jeremie" = {
      text = lib.concatStringsSep "\n" jeremieAuthorizedKeys;
      mode = "0644";
    };

    users.users.jeremie = {
      isNormalUser = true;
      createHome = true;
      home = "/home/jeremie";
      extraGroups = [ "wheel" ];
      shell = cfg.jeremieShell;
    } // jeremiePasswordAttrs;

    # Root sans mot de passe (SSH root déjà interdit)
    users.users.root.password = null;

    # Sudo - Permet au groupe wheel d'exécuter toutes les commandes sans mot de passe
    security.sudo.enable = true;
    security.sudo.wheelNeedsPassword = false;

    programs.tmux.enable = cfg.enableTmux;
    programs.zsh.enable = mkIf (cfg.jeremieShell == pkgs.zsh) true;
    programs.fish.enable = mkIf (cfg.jeremieShell == pkgs.fish) true;

    environment.systemPackages = with pkgs;
      [ curl wget ]
      ++ optional cfg.enableTmux pkgs.tmux
      ++ cfg.extraPackages;
  };
}
