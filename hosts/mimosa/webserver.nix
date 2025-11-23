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

    # Secret Cloudflare Tunnel (uniquement nécessaire pour la config complète)
    # Note: mode 0444 (world-readable) requis pour que le service cloudflared avec DynamicUser puisse lire le fichier
    # Le service cloudflared utilise DynamicUser qui crée un utilisateur temporaire sans privilèges
    # Ce utilisateur temporaire a besoin de pouvoir lire le token pour se connecter à Cloudflare
    sops.secrets.cloudflare-tunnel-token = {
      owner = "root";
      group = "root";
      mode = "0444";  # Lisible par tous (nécessaire pour DynamicUser)
    };

    # Fix: systemd n'évalue pas $(cat ...) dans ExecStart par défaut
    # On doit passer le token via un fichier de credentials systemd au lieu de substitution shell
    systemd.services.cloudflared = {
      serviceConfig = {
        # Charger le token comme credential systemd (accessible via $CREDENTIALS_DIRECTORY/tunnel-token)
        LoadCredential = "tunnel-token:${config.sops.secrets.cloudflare-tunnel-token.path}";
        # Modifier ExecStart pour utiliser bash et évaluer la substitution de commande
        ExecStart = lib.mkForce "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat $CREDENTIALS_DIRECTORY/tunnel-token)'";
      };
    };
  };
}
