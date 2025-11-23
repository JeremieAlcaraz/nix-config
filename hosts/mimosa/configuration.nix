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
  # DNS fallback pour les builds Nix (FOD)
  # Tailscale MagicDNS (100.100.100.100) n'est pas accessible dans le sandbox
  # Ajouter Google DNS comme fallback
  networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];

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

  # Nix build settings
  nix.settings = {
    sandbox = true;  # Garder la sandbox activée (sécurité)
    # Certificats SSL pour toutes les Fixed Output Derivations (FOD)
    # Permet à pnpm.fetchDeps et autres FOD de valider les connexions HTTPS
    ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    # Accès DNS pour les FOD (requis car mimosa utilise le DNS Tailscale)
    extra-sandbox-paths = [ "/etc/resolv.conf" ];
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    # openFirewall géré par networking.firewall au-dessus
    openFirewall = false;
  };

}
