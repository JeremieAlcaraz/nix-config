{ config, pkgs, lib, projectConfig, ... }:

let
  # Dashboard Node Exporter Full (grafana.com #1860, rev 37)
  # Téléchargé au build, provisionné automatiquement par Grafana
  grafanaDashboards = pkgs.runCommand "grafana-dashboards" {} ''
    mkdir -p $out
    cp ${pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
      hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
      name = "node-exporter-full.json";
    }} $out/node-exporter-full.json
    # Patch le dashboard pour utiliser notre datasource "VictoriaMetrics"
    ${pkgs.gnused}/bin/sed \
      -e 's/\''${DS__VICTORIAMETRICS}/VictoriaMetrics/g' \
      -e 's/"uid": "xfpJB9FGz"/"uid": "victoriametrics"/g' \
      ${pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/11074/revisions/9/download";
        hash = "sha256-iT9AKe6bPgeX662YndR7jfUW7U0Hjyje0tbY33u9EGU=";
        name = "node-exporter-overview.json";
      }} > $out/node-exporter-overview.json
  '';

  # Génère les scrape targets depuis config.nix (hostnames MagicDNS)
  remoteScrapeTargets = lib.concatMapStrings (host:
    "      - targets: [\"${host}:9100\"]\n        labels:\n          host: \"${host}\"\n"
  ) projectConfig.tailscale.monitoredHosts;
in
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

  # Secrets spécifiques à myosotis
  sops.secrets.grafana_admin_password = {
    owner = "grafana";
  };
  sops.secrets."gmail/from" = {
    owner = "grafana";
  };
  sops.secrets."gmail/app_password" = {
    owner = "grafana";
  };
  sops.secrets."gmail/to" = {
    owner = "grafana";
  };
  sops.secrets."slack/webhook_url" = {
    owner = "grafana";
  };

  # ==========================================================================
  # VictoriaMetrics - TSDB métriques (compatible Prometheus)
  # ==========================================================================

  # Fichier de config scrape (format Prometheus)
  # Définit les cibles que VictoriaMetrics va interroger toutes les 15s
  # Scrape config générée dynamiquement depuis config.nix (monitoredHosts)
  # myosotis scrape localhost, les autres via hostname MagicDNS
  environment.etc."victoriametrics/scrape.yml".text = ''
    scrape_configs:
      - job_name: "node"
        scrape_interval: 15s
        static_configs:
          - targets: ["localhost:9100"]
            labels:
              host: "myosotis"
    ${remoteScrapeTargets}
      - job_name: "caddy"
        scrape_interval: 15s
        static_configs:
          - targets: ["hawthorn:9180"]
            labels:
              host: "hawthorn"
      - job_name: "gitea"
        scrape_interval: 15s
        static_configs:
          - targets: ["dandelion:3000"]
            labels:
              host: "dandelion"
        metrics_path: "/metrics"
      - job_name: "postgres"
        scrape_interval: 15s
        static_configs:
          - targets: ["dandelion:9187"]
            labels:
              host: "dandelion"
          - targets: ["whitelily:9187"]
            labels:
              host: "whitelily"
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
      security = {
        admin_user = "admin";
        admin_password = "$__file{/run/secrets/grafana_admin_password}";
      };

      # SMTP Gmail pour les alertes email
      smtp = {
        enabled = true;
        host = "smtp.gmail.com:587";
        user = "$__file{/run/secrets/gmail/from}";
        password = "$__file{/run/secrets/gmail/app_password}";
        from_address = "$__file{/run/secrets/gmail/from}";
        from_name = "Grafana Myosotis";
      };
    };

    # Datasources préconfigurées (provisioning)
    provision.datasources.settings.datasources = [
      {
        name = "VictoriaMetrics";
        uid = "victoriametrics";
        type = "prometheus";
        url = "http://localhost:8428";
        isDefault = true;
        access = "proxy";
      }
      {
        name = "Loki";
        uid = "loki";
        type = "loki";
        url = "http://localhost:3100";
        access = "proxy";
      }
    ];

    # Dashboards provisionnés (chargés automatiquement au démarrage)
    provision.dashboards.settings.providers = [{
      name = "default";
      options.path = grafanaDashboards;
    }];

    # Contact points pour les alertes
    provision.alerting.contactPoints.settings = {
      contactPoints = [
        {
          name = "email";
          receivers = [{
            uid = "email";
            type = "email";
            settings.addresses = "$__file{/run/secrets/gmail/to}";
          }];
        }
        {
          name = "slack";
          receivers = [{
            uid = "slack";
            type = "slack";
            settings = {
              url = "$__file{/run/secrets/slack/webhook_url}";
              title = ''{{ template "default.title" . }}'';
              text = ''{{ template "default.message" . }}'';
            };
          }];
        }
      ];
    };

    # Politique de notification : critical → email + slack, le reste → slack
    provision.alerting.policies.settings = {
      policies = [
        {
          receiver = "slack";
          group_by = [ "alertname" "host" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "24h";
          routes = [
            {
              receiver = "email";
              matchers = [ "severity=critical" ];
              continue = true;
            }
          ];
        }
      ];
    };

    # ==========================================================================
    # Règles d'alerte provisionnées
    # ==========================================================================
    provision.alerting.rules.settings = {
      apiVersion = 1;
      groups = [{
        orgId = 1;
        name = "Infrastructure";
        folder = "Infrastructure";
        interval = "1m";
        rules = [
          # 1. Disque > 80% (critical → email + slack)
          {
            uid = "disk-usage-high";
            title = "Disk usage > 80%";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "victoriametrics";
                model = {
                  editorMode = "code";
                  expr = ''100 - (node_filesystem_avail_bytes{mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{mountpoint="/",fstype!~"tmpfs|overlay"}) * 100'';
                  instant = true;
                  refId = "A";
                };
              }
              {
                refId = "B";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "reduce";
                  expression = "A";
                  reducer = "last";
                  refId = "B";
                };
              }
              {
                refId = "C";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "threshold";
                  expression = "B";
                  conditions = [{ evaluator = { type = "gt"; params = [ 80 ]; }; }];
                  refId = "C";
                };
              }
            ];
            noDataState = "OK";
            execErrState = "Error";
            for = "5m";
            labels = { severity = "critical"; };
            annotations = {
              summary = "Disque > 80% sur {{ $labels.host }}";
              description = "Usage actuel : {{ $values.B }}%";
            };
          }
          # 2. RAM > 90% (warning → slack)
          {
            uid = "ram-usage-high";
            title = "RAM usage > 90%";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "victoriametrics";
                model = {
                  editorMode = "code";
                  expr = ''(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100'';
                  instant = true;
                  refId = "A";
                };
              }
              {
                refId = "B";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "reduce";
                  expression = "A";
                  reducer = "last";
                  refId = "B";
                };
              }
              {
                refId = "C";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "threshold";
                  expression = "B";
                  conditions = [{ evaluator = { type = "gt"; params = [ 90 ]; }; }];
                  refId = "C";
                };
              }
            ];
            noDataState = "OK";
            execErrState = "Error";
            for = "5m";
            labels = { severity = "warning"; };
            annotations = {
              summary = "RAM > 90% sur {{ $labels.host }}";
              description = "Usage actuel : {{ $values.B }}%";
            };
          }
          # 3. CPU > 90% pendant 5min (warning → slack)
          {
            uid = "cpu-usage-high";
            title = "CPU usage > 90%";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "victoriametrics";
                model = {
                  editorMode = "code";
                  expr = ''100 - (avg by(host) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
                  instant = true;
                  refId = "A";
                };
              }
              {
                refId = "B";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "reduce";
                  expression = "A";
                  reducer = "last";
                  refId = "B";
                };
              }
              {
                refId = "C";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "threshold";
                  expression = "B";
                  conditions = [{ evaluator = { type = "gt"; params = [ 90 ]; }; }];
                  refId = "C";
                };
              }
            ];
            noDataState = "OK";
            execErrState = "Error";
            for = "5m";
            labels = { severity = "warning"; };
            annotations = {
              summary = "CPU > 90% sur {{ $labels.host }}";
              description = "Usage actuel : {{ $values.B }}%";
            };
          }
          # 4. Host injoignable depuis 2min (critical → email + slack)
          {
            uid = "host-unreachable";
            title = "Host unreachable";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "victoriametrics";
                model = {
                  editorMode = "code";
                  expr = ''up{job="node"}'';
                  instant = true;
                  refId = "A";
                };
              }
              {
                refId = "B";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "reduce";
                  expression = "A";
                  reducer = "last";
                  refId = "B";
                };
              }
              {
                refId = "C";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "threshold";
                  expression = "B";
                  conditions = [{ evaluator = { type = "lt"; params = [ 1 ]; }; }];
                  refId = "C";
                };
              }
            ];
            noDataState = "Alerting";
            execErrState = "Alerting";
            for = "2m";
            labels = { severity = "critical"; };
            annotations = {
              summary = "Host {{ $labels.host }} injoignable";
              description = "Aucune métrique reçue depuis 2 minutes";
            };
          }
          # 5. Reboot détecté - uptime < 5min (info → slack)
          {
            uid = "host-reboot";
            title = "Host reboot detected";
            condition = "C";
            data = [
              {
                refId = "A";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "victoriametrics";
                model = {
                  editorMode = "code";
                  expr = "node_time_seconds - node_boot_time_seconds";
                  instant = true;
                  refId = "A";
                };
              }
              {
                refId = "B";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "reduce";
                  expression = "A";
                  reducer = "last";
                  refId = "B";
                };
              }
              {
                refId = "C";
                relativeTimeRange = { from = 600; to = 0; };
                datasourceUid = "__expr__";
                model = {
                  type = "threshold";
                  expression = "B";
                  conditions = [{ evaluator = { type = "lt"; params = [ 300 ]; }; }];
                  refId = "C";
                };
              }
            ];
            noDataState = "OK";
            execErrState = "Error";
            for = "0s";
            labels = { severity = "info"; };
            annotations = {
              summary = "Reboot détecté sur {{ $labels.host }}";
              description = "Uptime : {{ $values.B }} secondes";
            };
          }
        ];
      }];
    };
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
