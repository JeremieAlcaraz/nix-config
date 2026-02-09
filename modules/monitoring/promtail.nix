# Module réutilisable : Promtail
# Collecte les logs systemd et les envoie à Loki sur myosotis.
# À importer sur chaque host qu'on veut monitorer.
{ config, lib, pkgs, projectConfig, ... }:

let
  lokiUrl = "http://${projectConfig.tailscale.hosts.myosotis}:3100";
  hostname = config.networking.hostName;
in
{
  # Créer le répertoire de travail de Promtail
  systemd.tmpfiles.rules = [
    "d /var/lib/promtail 0755 promtail promtail -"
  ];

  # Promtail a besoin d'accéder au journal systemd, ce qui nécessite
  # de relâcher le sandboxing par défaut
  systemd.services.promtail.serviceConfig = {
    PrivateUsers = lib.mkForce false;
    PrivateMounts = lib.mkForce false;
    ProtectHome = lib.mkForce false;
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;  # désactivé
      };

      clients = [{
        url = "${lokiUrl}/loki/api/v1/push";
      }];

      positions.filename = "/var/lib/promtail/positions.yaml";

      scrape_configs = [{
        job_name = "journal";
        journal = {
          max_age = "12h";  # ne pas renvoyer les vieux logs au démarrage
          labels = {
            job = "systemd-journal";
            host = hostname;
          };
        };
        relabel_configs = [{
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }];
      }];
    };
  };
}
