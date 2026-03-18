# Configuration du serveur web j12zdotcom
# Ce fichier est importé uniquement dans la configuration "mimosa" complète
# Pour éviter les erreurs, il n'est PAS importé dans "mimosa-bootstrap"

{ config, lib, pkgs, j12zdotcom, ... }:

let
  cfg = config.mimosa.webserver;
  # Packages pré-buildés depuis la flake (téléchargés depuis le cache magnolia)
  sitePackage = j12zdotcom.packages.x86_64-linux.site;
in
{
  options.mimosa.webserver.enable = lib.mkEnableOption "the j12z webserver for mimosa";

  config = lib.mkIf cfg.enable {
    # Service Node.js pour Astro SSR/Hybrid (site vitrine)
    systemd.services.j12zdotcom = {
      description = "J12z Astro Site Server";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ sitePackage ];

      serviceConfig = {
        ExecStart = "${pkgs.nodejs_22}/bin/node ${sitePackage}/server/entry.mjs";
        WorkingDirectory = "${sitePackage}";
        Environment = [
          "HOST=0.0.0.0"
          "PORT=4321"
          "NODE_ENV=production"
        ];

        DynamicUser = true;
        Restart = "always";
        RestartSec = "5s";
      };
    };

  };
}
