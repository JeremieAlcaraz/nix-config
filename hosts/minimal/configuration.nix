# hosts/minimal/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/minimal.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix   # Configuration DNS pour MagicDNS
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "minimal";
  networking.useDHCP = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };
}
