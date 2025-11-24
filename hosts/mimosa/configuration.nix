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

  # Packages système requis pour les builds Nix
  environment.systemPackages = with pkgs; [
    cacert  # Certificats CA requis pour pnpm.fetchDeps et autres FODs
  ];

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
  #
  # Deux configurations disponibles dans flake.nix :
  #   - mimosa      : webserver désactivé (pour installation initiale)
  #   - mimosa-web  : webserver activé (pour production)
  #
  # Basculer entre les deux :
  #   sudo nixos-rebuild switch --flake .#mimosa      # Désactiver le webserver
  #   sudo nixos-rebuild switch --flake .#mimosa-web  # Activer le webserver

  # Nix build settings
  nix.settings = {
    sandbox = true;  # Garder la sandbox activée (sécurité)
    # Certificats SSL pour toutes les Fixed Output Derivations (FOD)
    # Permet à pnpm.fetchDeps et autres FOD de valider les connexions HTTPS
    ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    # Accès DNS pour les FOD (requis car mimosa utilise le DNS Tailscale)
    extra-sandbox-paths = [ "/etc/resolv.conf" ];

    # Binary caches : sources de packages pré-compilés
    # Nix essaie chaque cache dans l'ordre jusqu'à trouver le package
    substituters = [
      "https://cache.nixos.org"  # Cache officiel NixOS (par défaut)
      "http://magnolia:5000"     # Notre cache local via Tailscale
    ];

    # Clés publiques pour vérifier les signatures des packages téléchargés
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "magnolia.cache:7MVdzDOzQsVItEh+ewmU4Ga8TOke40asmXY1p9nQhC0="
    ];
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    # openFirewall géré par networking.firewall au-dessus
    openFirewall = false;
  };

}
