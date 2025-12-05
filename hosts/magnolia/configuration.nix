{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/magnolia.yaml; })
    ../../modules/tailscale.nix
    ../../modules/tailscale-dns.nix   # Configuration DNS pour MagicDNS
    ../../modules/nix-serve.nix
    ../../modules/github-actions.nix  # Clés SSH pour GitHub Actions

    ../../modules/deployment.nix      # Clé SSH pour déploiement et GitHub
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
