# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-minimal"

{ config, lib, ... }:

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
      # Cloudflare Tunnel activé avec sops
      enableCloudflaredTunnel = true;
      cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
    };

    # Secret Cloudflare Tunnel (uniquement nécessaire pour la config complète)
    sops.secrets.cloudflare-tunnel-token = {
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
    };
  };
}
