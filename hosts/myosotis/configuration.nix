{ config, pkgs, lib, projectConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/myosotis.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix
    ../../modules/monitoring/node-exporter.nix
    ../../modules/monitoring/promtail.nix
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

  # ==========================================================================
  # Loki - Stockage et indexation des logs
  # ==========================================================================
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server.http_listen_port = 3100;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_retain_period = "30s";
      };

      schema_config.configs = [{
        from = "2025-01-01";
        store = "tsdb";
        object_store = "filesystem";
        schema = "v13";
        index = {
          prefix = "index_";
          period = "24h";
        };
      }];

      storage_config.filesystem.directory = "/var/lib/loki/chunks";
      storage_config.tsdb_shipper = {
        active_index_directory = "/var/lib/loki/tsdb-active";
        cache_location = "/var/lib/loki/tsdb-cache";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";  # 7 jours max d'ancienneté à l'ingestion
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };

      # Rétention 30 jours
      limits_config.retention_period = "720h";
    };
  };

  # ==========================================================================
  # Grafana - Interface web de visualisation
  # ==========================================================================
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        root_url = "https://myosotis.inanga-sirius.ts.net";
      };
      # Login admin par défaut (à remplacer par sops en T31)
      security = {
        admin_user = "admin";
        admin_password = "admin";
      };
    };

    # Datasources préconfigurées (provisioning)
    provision.datasources.settings.datasources = [
      {
        name = "VictoriaMetrics";
        type = "prometheus";
        url = "http://localhost:8428";
        isDefault = true;
        access = "proxy";
      }
      {
        name = "Loki";
        type = "loki";
        url = "http://localhost:3100";
        access = "proxy";
      }
    ];
  };

  # ==========================================================================
  # Tailscale Serve - HTTPS avec certs Tailscale pour Grafana
  # ==========================================================================
  # `tailscale serve` expose Grafana en HTTPS avec des vrais certificats
  # Accessible sur https://myosotis.inanga-sirius.ts.net
  systemd.services.tailscale-serve-grafana = {
    description = "Tailscale Serve for Grafana";
    after = [ "tailscaled.service" "grafana.service" ];
    wants = [ "tailscaled.service" "grafana.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:3000";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
    };
  };

  # Firewall : ports ouverts uniquement sur Tailscale
  networking.firewall = {
    interfaces."tailscale0".allowedTCPPorts = [
      8428  # VictoriaMetrics
      3100  # Loki
    ];
  };
}
