# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-minimal"

{ config, lib, pkgs, ... }:

let
  cfg = config.mimosa.webserver;
in
{
  options.mimosa.webserver.enable = lib.mkEnableOption "the j12z webserver for mimosa";

  config = lib.mkIf cfg.enable {
    # Configuration du service j12z-webserver
    services.j12z-webserver = {
      enable = true;
      domain = "jeremiealcaraz.com";
      email = "hello@jeremiealcaraz.com";
      # TEMPORAIRE: Utiliser un dossier local au lieu du build Nix
      # TODO: Remettre le build Nix automatique une fois le problème sandbox résolu
      siteRoot = /var/www/j12zdotcom;
      # Cloudflare Tunnel activé avec sops
      enableCloudflaredTunnel = true;
      cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
    };

    # Override Caddy config pour accepter HTTP du tunnel Cloudflare sans redirection
    # Cloudflare gère déjà le HTTPS entre l'utilisateur et leur edge
    # On doit remplacer la config par défaut qui utilise HTTPS automatique
    services.caddy.virtualHosts = lib.mkForce {
      "http://jeremiealcaraz.com" = {
        extraConfig = ''
          root * ${toString config.services.j12z-webserver.siteRoot}
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
