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
      # TEMPORAIRE: Utiliser un dossier local au lieu du build Nix
      # TODO: Remettre le build Nix automatique une fois le problème sandbox résolu
      siteRoot = /var/www/j12zdotcom;
      # Cloudflare Tunnel activé avec sops
      enableCloudflaredTunnel = true;
      cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
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
  };
}
