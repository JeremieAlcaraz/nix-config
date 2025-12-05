# hosts/minimal/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/minimal.yaml; })
    ../../modules/tailscale.nix
    ../../modules/tailscale-dns.nix   # Configuration DNS pour MagicDNS
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
