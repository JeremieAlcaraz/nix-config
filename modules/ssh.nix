# ============================================================================
# Module commun "ssh.nix"
# ---------------------------------------------------------------------------
# Centralise la configuration d'accès (boot/SSH/utilisateurs) utilisée sur
# l'ensemble des hôtes. Les hôtes peuvent surcharger les attributs définis ici
# si nécessaire (mot de passe, règles de firewall supplémentaires, etc.).
# ============================================================================

{ config, lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  console.earlySetup = true;

  services.qemuGuest.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkDefault [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      # Permet le forwarding de l'agent SSH pour utiliser les clés du client
      AllowAgentForwarding = true;
    };
  };

  users.mutableUsers = lib.mkDefault false;

  users.users.jeremie = {
    isNormalUser = true;
    createHome = true;
    home = "/home/jeremie";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # Clé SSH du Mac de Jérémie
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
      # Clé de déploiement de Magnolia (pour déployer sur d'autres hôtes)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/86QE9e0ymSz67B8ShU9V5smHpdLKF+KH8tUaYudxi magnolia-deploy@github"
    ];
  };

  users.users.root.password = lib.mkDefault null;

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
