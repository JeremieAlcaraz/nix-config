# Configuration du gateway (Caddy + Cloudflare Tunnel)
# Hawthorn : Point d'entrée centralisé pour tous les services web

{ config, lib, pkgs, ... }:

{
  # Configuration Caddy - Gateway reverse proxy
  services.caddy = {
    enable = true;

    # Pas de HTTPS auto (Cloudflare gère le TLS en amont)
    globalConfig = ''
      auto_https off

      # Trust Cloudflare Tunnel pour obtenir la vraie IP client
      servers {
        trusted_proxies static 127.0.0.1/32 ::1
        client_ip_headers CF-Connecting-IP X-Forwarded-For
      }
    '';

    # VirtualHost principal
    virtualHosts."http://jeremiealcaraz.com" = {
      extraConfig = ''
        # Compression
        encode gzip zstd

        # Headers de sécurité (repris de mimosa)
        header {
          X-Frame-Options "SAMEORIGIN"
          X-Content-Type-Options "nosniff"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
          Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:; connect-src 'self' https:; media-src 'self' https:;"
          Permissions-Policy "geolocation=(), microphone=(), camera=()"
          Cache-Control "public, must-revalidate, max-age=0"
          -Server
        }

        # Logs JSON
        log {
          output file /var/log/caddy/jeremiealcaraz.com.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
          }
          format json
          level INFO
        }

        # Reverse proxy vers mimosa (Caddy actuel)
        reverse_proxy mimosa:80 {
          # Headers X-Forwarded-*
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };
  };

  # Ouvrir les ports firewall (HTTP pour le tunnel local)
  networking.firewall = {
    allowedTCPPorts = [ 80 ];
  };

  # Configuration Cloudflare Tunnel (à implémenter en P5)
  # systemd.services.cloudflared = { ... };
}

