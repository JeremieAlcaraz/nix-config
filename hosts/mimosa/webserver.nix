# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-bootstrap"

{ config, lib, pkgs, j12zdotcom, ... }:

let
  cfg = config.mimosa.webserver;
  # Package pré-buildé depuis la flake (téléchargé depuis le cache magnolia)
  sitePackage = j12zdotcom.packages.x86_64-linux.site;
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

        # Faire confiance au tunnel Cloudflare pour obtenir la vraie IP client
        # (permet remote_ip de fonctionner pour les règles d'accès)
        servers {
          trusted_proxies static 127.0.0.1/32 ::1
          client_ip_headers CF-Connecting-IP X-Forwarded-For
        }
      '';
      # Config pour accepter HTTP du tunnel Cloudflare sans redirection
      # Cloudflare gère déjà le HTTPS entre l'utilisateur et leur edge
      virtualHosts."http://jeremiealcaraz.com" = {
        extraConfig = ''
          encode gzip zstd

          header {
            X-Frame-Options "SAMEORIGIN"
            X-Content-Type-Options "nosniff"
            X-XSS-Protection "1; mode=block"
            Referrer-Policy "strict-origin-when-cross-origin"
            Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:; connect-src 'self' https:; media-src 'self' https:;"
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

          # WARN: Mode maintenance temporaire (à commenter/supprimer une fois le site prêt)
          @wip path /wip* /_astro/* /assets/* /favicon* /robots.txt /sitemap* /site.webmanifest

          route {
            handle @wip {
              reverse_proxy 127.0.0.1:4321
            }

            # Tout le reste → page WIP
            handle {
              redir https://jeremiealcaraz.com/wip 302
            }
          }
        '';
      };
    };

    # Service Node.js pour Astro SSR/Hybrid
    systemd.services.j12zdotcom = {
      description = "J12z Astro Site Server";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ sitePackage ];

      serviceConfig = {
        ExecStart = "${pkgs.nodejs_20}/bin/node ${sitePackage}/server/entry.mjs";
        WorkingDirectory = "${sitePackage}";
        Environment = [
          "HOST=127.0.0.1"
          "PORT=4321"
          "NODE_ENV=production"
        ];

        DynamicUser = true;
        Restart = "always";
        RestartSec = "5s";
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
