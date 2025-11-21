# hosts/demo/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/ssh.nix
    ../../modules/tailscale.nix
  ];

  time.timeZone = "Europe/Paris";
  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "demo";
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  networking.resolvconf.enable = false;

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

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
