{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./gateway.nix  # Configuration Caddy + Cloudflare Tunnel
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/hawthorn.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix   # Configuration DNS pour MagicDNS
  ];

  # Système
  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "hawthorn";  # Gateway - Point d'entrée web centralisé
  networking.useDHCP = true;

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    age = {
      # Utiliser UNIQUEMENT la clé age partagée (copiée depuis le Mac)
      keyFile = "/var/lib/sops-nix/key.txt";
      # Désactiver les clés SSH pour forcer l'utilisation de keyFile
      sshKeyPaths = [];
    };
    secrets = {
      # Les secrets spécifiques seront définis dans gateway.nix
    };
  };

  # Paquets système essentiels
  environment.systemPackages = with pkgs; [
    htop
    curl
  ];
}
