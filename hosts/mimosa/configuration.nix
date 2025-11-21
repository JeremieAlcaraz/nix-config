{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/tailscale.nix  # <--- AJOUTE ÇA
    # ... tes autres imports
  ];

  # Système
  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "mimosa";  # Serveur web
  networking.useDHCP = true;

  # Utilisateur
  users.users.jeremie = {
    # Hash du mot de passe stocké de manière sécurisée dans sops
    # Le fichier de secrets est chiffré et ne peut être déchiffré que par l'hôte
    hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
  };

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    defaultSopsFile = ../../secrets/mimosa.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
    };
    secrets = {
      # Hash du mot de passe de l'utilisateur jeremie
      jeremie-password-hash = {
        neededForUsers = true;
      };
      # Note: Le secret cloudflare-tunnel-token est défini dans webserver.nix
      # qui est importé uniquement dans la configuration "mimosa" complète
    };
  };

  # Configuration du site j12zdotcom
  # La configuration du serveur web est dans ./webserver.nix
  # Ce fichier est importé uniquement dans la configuration "mimosa" complète (via flake.nix)
  # La configuration "mimosa-minimal" n'importe PAS ce fichier pour éviter
  # les téléchargements npm pendant l'installation initiale
  # Activer/désactiver facilement le serveur web pour éviter les builds durant le boot
  mimosa.webserver.enable = false; # Passer à true pour réactiver le déploiement web

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    # openFirewall géré par networking.firewall au-dessus
    openFirewall = false;
  };

}
