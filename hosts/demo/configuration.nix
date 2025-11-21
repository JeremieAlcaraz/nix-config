# hosts/demo/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/tailscale.nix
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "demo";
  networking.useDHCP = true;
  networking.resolvconf.enable = false;

  # Utilisateur jeremie (pas de mot de passe, SSH uniquement)
  users.users.jeremie = {
    password = null;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Configuration sops-nix pour la gestion des secrets communs (Tailscale)
  sops = {
    defaultSopsFile = ../../secrets/common.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
