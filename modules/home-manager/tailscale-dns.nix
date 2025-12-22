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
    dnssec = "false";  # Désactiver DNSSEC pour éviter les conflits
    # Tailscale injectera automatiquement son DNS (100.100.100.100)
    # via l'interface tailscale0 avec --accept-dns=true
  };

  # Désactiver l'ancien système resolvconf
  networking.resolvconf.enable = false;

  # IMPORTANT: Faire en sorte que /etc/resolv.conf soit un symlink
  # vers le stub resolver de systemd-resolved (127.0.0.53)
  # Cela permet à systemd-resolved de gérer correctement le DNS
  system.activationScripts.fixResolvConf = lib.stringAfter [ "etc" ] ''
    # Supprimer l'ancien resolv.conf s'il existe et n'est pas un symlink
    if [ -e /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
      # Retirer l'attribut immutable si présent (ignore les erreurs)
      ${pkgs.e2fsprogs}/bin/chattr -i /etc/resolv.conf 2>/dev/null || true
      rm -f /etc/resolv.conf
    fi
    # Créer le symlink vers systemd-resolved stub resolver
    if [ ! -e /etc/resolv.conf ]; then
      ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
  '';

  # Note : Tailscale avec --accept-dns=true configurera automatiquement
  # systemd-resolved pour utiliser 100.100.100.100 comme serveur DNS
  # pour le domaine .ts.net et les hostnames courts
}
