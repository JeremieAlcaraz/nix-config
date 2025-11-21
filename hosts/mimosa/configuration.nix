{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/mimosa.yaml; })
    ../../modules/tailscale.nix  # <--- AJOUTE ÇA
    # ... tes autres imports
  ];

  # Système
  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "mimosa";  # Serveur web
  networking.useDHCP = true;

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    secrets = {
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
