{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/tailscale.nix
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "magnolia";  # Infrastructure Proxmox
  networking.useDHCP = true;
  # Désactiver resolvconf (DHCP gère déjà le DNS)
  networking.resolvconf.enable = false;
  users.users.jeremie = {
    # Hash du mot de passe stocké de manière sécurisée dans sops
    # Le fichier de secrets est chiffré et ne peut être déchiffré que par l'hôte
    hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
  };

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
