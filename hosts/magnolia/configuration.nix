{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/magnolia.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix   # Configuration DNS pour MagicDNS
    ../../modules/home-manager/nix-serve.nix
    ../../modules/home-manager/github-actions.nix  # Clés SSH pour GitHub Actions

    ../../modules/home-manager/deployment.nix      # Clé SSH pour déploiement et GitHub
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "magnolia";  # Infrastructure Proxmox
  networking.useDHCP = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };
}
