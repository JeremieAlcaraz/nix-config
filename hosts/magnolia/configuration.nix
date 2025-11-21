{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/ssh.nix
    ../../modules/tailscale.nix
  ];

  time.timeZone = "Europe/Paris";
  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "magnolia";  # Infrastructure Proxmox
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  # Désactiver resolvconf (DHCP gère déjà le DNS)
  networking.resolvconf.enable = false;

  sshCommon.jeremieHashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

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

}
