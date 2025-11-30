# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-minimal"

{ config, lib, pkgs, j12z-site, ... }:

let
  cfg = config.mimosa.webserver;
  # Package pré-buildé depuis la flake (téléchargé depuis le cache magnolia)
  sitePackage = j12z-site.packages.x86_64-linux.site;
in
{
  options.mimosa.webserver.enable = lib.mkEnableOption "the j12z webserver for mimosa";

  config = lib.mkIf cfg.enable {
    # Configuration Caddy directe (sans le module j12z-webserver qui rebuild)
    services.caddy = {
      enable = true;
      # Désactiver HTTPS automatique - Cloudflare gère le TLS
      globalConfig = ''
        auto_https off
      '';
      # Adapter pour désactiver le rechargement gracieux
      # Cela force un restart complet au lieu d'un reload
      adapter = null;
      # Config pour accepter HTTP du tunnel Cloudflare sans redirection
      # Cloudflare gère déjà le HTTPS entre l'utilisateur et leur edge
      virtualHosts."http://jeremiealcaraz.com" = {
        extraConfig = ''
          root * ${sitePackage}
          file_server

          handle_errors {
            @404 {
              expression {http.error.status_code} == 404
            }
            rewrite @404 /404.html
            file_server
          }

          encode gzip zstd

          header {
            X-Frame-Options "SAMEORIGIN"
            X-Content-Type-Options "nosniff"
            X-XSS-Protection "1; mode=block"
            Referrer-Policy "strict-origin-when-cross-origin"
            Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:; connect-src 'self' https:;"
            Permissions-Policy "geolocation=(), microphone=(), camera=()"
            # Contrôle du cache - permet au navigateur de mettre en cache mais force la revalidation
            Cache-Control "public, must-revalidate, max-age=0"
            -Server
          }

          log {
            output file /var/log/caddy/jeremiealcaraz.com.log {
              roll_size 100mb
              roll_keep 10
              roll_keep_for 720h
            }
            format json
            level INFO
          }
        '';
      };
    };

    # Forcer le redémarrage de Caddy quand le site change
    # Cela résout le problème des styles perdus après déploiement
    systemd.services.caddy = {
      restartTriggers = [ sitePackage ];
    };

    # Secret Cloudflare Tunnel
    # Mode 0444 permet au service cloudflared (avec DynamicUser) de lire le token
    sops.secrets.cloudflare-tunnel-token = {
      owner = "root";
      group = "root";
      mode = "0444";
    };

    # Service cloudflared manuel avec systemd
    # On n'utilise pas services.cloudflared car il ne supporte pas --token directement
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
  };
}
