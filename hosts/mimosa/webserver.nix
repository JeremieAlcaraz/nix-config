# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-minimal"

{ config, ... }:

{
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
}
