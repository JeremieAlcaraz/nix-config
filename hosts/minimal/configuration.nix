# hosts/minimal/configuration.nix
# Configuration minimale pour l'installation initiale
# Usage : nixos-install --flake .#minimal
# Après reboot : sudo nixos-rebuild switch --flake .#<hostname>
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/sops.nix { defaultSopsFile = ../../secrets/common.yaml; })
    ../../modules/tailscale.nix
  ];

  system.stateVersion = "24.05";

  # Réseau
  networking.hostName = "minimal";
  networking.useDHCP = true;
  networking.resolvconf.enable = false;

  # Cache magnolia : pull uniquement (pas de push)
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "http://magnolia:5000"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "magnolia.cache:7MVdzDOzQsVItEh+ewmU4Ga8TOke40asmXY1p9nQhC0="
    ];
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };
}
