{ config, pkgs, lib, projectConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/myosotis.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix
  ];

  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "myosotis";  # VM Observabilité - Monitoring centralisé
  networking.useDHCP = true;

  # Configuration de base héritée des modules communs
  # Les modules importés ci-dessus fournissent :
  # - Utilisateur jeremie avec sudo
  # - SSH avec clés publiques
  # - Tailscale pour réseau privé
  # - Sops pour gestion des secrets

  # ==========================================================================
  # VictoriaMetrics - TSDB métriques (compatible Prometheus)
  # ==========================================================================
  services.victoriametrics = {
    enable = true;
    listenAddress = ":8428";
    extraOptions = [
      "-retentionPeriod=12"  # 12 mois de rétention
    ];
  };

  # Firewall : ports ouverts uniquement sur Tailscale
  networking.firewall = {
    interfaces."tailscale0".allowedTCPPorts = [
      8428  # VictoriaMetrics
    ];
  };
}
