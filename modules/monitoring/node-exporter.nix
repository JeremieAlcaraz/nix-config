# Module réutilisable : Node Exporter
# Expose les métriques système (CPU, RAM, disque, réseau) sur :9100
# À importer sur chaque host qu'on veut monitorer.
{ config, lib, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    # Écoute sur toutes les interfaces (filtré par firewall)
    listenAddress = "0.0.0.0";
    # Collecteurs activés par défaut : cpu, memory, disk, network, filesystem, etc.
  };

  # Ouvrir le port uniquement sur l'interface Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 9100 ];
}
