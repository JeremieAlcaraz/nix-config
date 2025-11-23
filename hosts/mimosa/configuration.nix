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
  # Ce fichier est importé uniquement dans la configuration "mimosa" complète (via flake.nix)
  # La configuration "mimosa-minimal" n'importe PAS ce fichier pour éviter
  # les téléchargements npm pendant l'installation initiale
  # Note: mimosa.webserver.enable est activé dans flake.nix pour la config "mimosa"

  # Nix build settings
  nix.settings = {
    sandbox = true;  # Garder la sandbox activée (sécurité)
    # Note: Les Fixed Output Derivations (FOD) comme pnpm.fetchDeps ont accès au réseau
    # Les certificats SSL viennent de cacert dans systemPackages et nativeBuildInputs de fetchDeps
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    # openFirewall géré par networking.firewall au-dessus
    openFirewall = false;
  };

}
