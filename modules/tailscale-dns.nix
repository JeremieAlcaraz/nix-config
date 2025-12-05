# ============================================================================
# Module "tailscale-dns.nix"
# ---------------------------------------------------------------------------
# Configure systemd-resolved pour qu'il fonctionne correctement avec
# MagicDNS de Tailscale, permettant la résolution des hostnames courts
# (mimosa, whitelily, etc.) via le DNS Tailscale.
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # Activer systemd-resolved (gestionnaire DNS moderne)
  services.resolved = {
    enable = true;
    # Tailscale injectera automatiquement son DNS (100.100.100.100)
    # via l'interface tailscale0
  };

  # Désactiver l'ancien système resolvconf
  networking.resolvconf.enable = false;

  # Configuration réseau pour permettre à systemd-resolved de gérer le DNS
  networking.useNetworkd = lib.mkDefault false;  # Garder NetworkManager/dhcpcd par défaut

  # Note : Tailscale avec --accept-dns=true configurera automatiquement
  # systemd-resolved pour utiliser 100.100.100.100 comme serveur DNS
  # pour le domaine .ts.net et les hostnames courts
}
