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
  # Note: mimosa.webserver.enable est activé dans flake.nix pour la config "mimosa"

  # Nix build settings - Permettre aux fixed-output derivations d'accéder au DNS
  # Nécessaire pour pnpm.fetchDeps dans le flake j12zdotcom
  nix.settings = {
    sandbox = true;  # Garder la sandbox activée (sécurité)
    extra-sandbox-paths = [
      "/etc/resolv.conf"  # Accès DNS pour fetcher les dépendances npm
      "/etc/ssl/certs"    # Certificats SSL pour https://registry.npmjs.org
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
