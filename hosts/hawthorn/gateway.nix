# Configuration du gateway (Caddy + Cloudflare Tunnel)
# Hawthorn : Point d'entrée centralisé pour tous les services web

{ config, lib, pkgs, ... }:

let
  # Configuration commune pour tous les virtualHosts
  commonSecurityHeaders = ''
    X-Frame-Options "SAMEORIGIN"
    X-Content-Type-Options "nosniff"
    X-XSS-Protection "1; mode=block"
    Referrer-Policy "strict-origin-when-cross-origin"
    Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:; connect-src 'self' https:; media-src 'self' https:;"
    Permissions-Policy "geolocation=(), microphone=(), camera=()"
    Cache-Control "public, must-revalidate, max-age=0"
    -Server
  '';

  # Fonction helper pour générer la config de logs
  mkLogConfig = logFile: ''
    log {
      output file ${logFile} {
        roll_size 100mb
        roll_keep 10
        roll_keep_for 720h
      }
      format json
      level INFO
    }
  '';
in
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

    # VirtualHost principal (production)
    virtualHosts."http://jeremiealcaraz.com" = {
      extraConfig = ''
        # Compression
        encode gzip zstd

        # Headers de sécurité
        header {
          ${commonSecurityHeaders}
        }

        # Logs JSON
        ${mkLogConfig "/var/log/caddy/jeremiealcaraz.com.log"}

        # Reverse proxy vers mimosa (Caddy actuel)
        reverse_proxy mimosa:80
      '';
    };

    # VirtualHost de test (preview hawthorn)
    virtualHosts."http://hawthorn-preview.jeremiealcaraz.com" = {
      extraConfig = ''
        # Compression
        encode gzip zstd

        # Headers de sécurité
        header {
          ${commonSecurityHeaders}
        }

        # Logs JSON
        ${mkLogConfig "/var/log/caddy/hawthorn-preview.log"}

        # Reverse proxy vers mimosa (Caddy actuel)
        # Note: header_up Host nécessaire pour que mimosa reconnaisse la requête
        reverse_proxy mimosa:80 {
          header_up Host jeremiealcaraz.com
        }
      '';
    };
  };

  # Ouvrir les ports firewall (HTTP pour le tunnel local)
  networking.firewall = {
    allowedTCPPorts = [ 80 ];
  };

  # Secret Cloudflare Tunnel (même token que mimosa)
  sops.secrets.cloudflare-tunnel-token = {
    owner = "root";
    group = "root";
    mode = "0444";
  };

  # Configuration Cloudflare Tunnel
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      # Charger le token comme credential systemd
      LoadCredential = "tunnel-token:${config.sops.secrets.cloudflare-tunnel-token.path}";
      # Utiliser bash pour lire le token depuis $CREDENTIALS_DIRECTORY
      ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat $CREDENTIALS_DIRECTORY/tunnel-token)'";
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [];
    };
  };
}

