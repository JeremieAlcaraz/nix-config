# Module réutilisable : PostgreSQL Exporter
# Expose les métriques PostgreSQL (connexions, taille, locks, etc.) sur :9187
# À importer sur chaque host avec PostgreSQL qu'on veut monitorer.
# Tourne en tant qu'utilisateur postgres pour l'authentification peer via socket Unix.
{ config, lib, ... }:

{
  services.prometheus.exporters.postgres = {
    enable = true;
    port = 9187;
    listenAddress = "0.0.0.0";
    dataSourceName = "user=postgres host=/run/postgresql dbname=postgres sslmode=disable";
    user = "postgres";
    group = "postgres";
  };

  # Ouvrir le port uniquement sur l'interface Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 9187 ];
}
