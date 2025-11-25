{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/magnolia.yaml; })
    ../../modules/tailscale.nix
    ../../modules/nix-serve.nix
    ../../modules/github-actions.nix  # Clés SSH pour GitHub Actions
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "magnolia";  # Infrastructure Proxmox
  networking.useDHCP = true;
  # Désactiver resolvconf (DHCP gère déjà le DNS)
  networking.resolvconf.enable = false;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };
}
