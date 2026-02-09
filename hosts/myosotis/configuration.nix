{ config, pkgs, lib, projectConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/myosotis.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix
    ../../modules/monitoring/node-exporter.nix
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

  # Fichier de config scrape (format Prometheus)
  # Définit les cibles que VictoriaMetrics va interroger toutes les 15s
  environment.etc."victoriametrics/scrape.yml".text = ''
    scrape_configs:
      - job_name: "node"
        scrape_interval: 15s
        static_configs:
          - targets: ["localhost:9100"]
            labels:
              host: "myosotis"
  '';

  services.victoriametrics = {
    enable = true;
    listenAddress = ":8428";
    extraOptions = [
      "-retentionPeriod=12"
      "-promscrape.config=/etc/victoriametrics/scrape.yml"
    ];
  };

  # Firewall : ports ouverts uniquement sur Tailscale
  networking.firewall = {
    interfaces."tailscale0".allowedTCPPorts = [
      8428  # VictoriaMetrics
    ];
  };
}
