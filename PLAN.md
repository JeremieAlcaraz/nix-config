# Plan de migration Astro Hybrid (Mimosa)

Checklist des étapes réalisées et restantes pour passer du site statique à un mode hybride (SSR partiel), sans casser l'infra.

## ✅ Fait (aujourd'hui)

- [x] Build Astro en local sur macOS (marigold).
- [x] Vérification du dossier `dist/` avec `client/` et `server/`.
- [x] Test local du serveur Node (`node dist/server/entry.mjs`) OK.

## ⏳ À faire (prochaines étapes)

### 1) Côté projet Astro (repo j12zdotcom)

- [ ] Ajouter l'adaptateur Node (`@astrojs/node`).
- [ ] Configurer `astro.config.mjs` en mode hybride (output par défaut statique + SSR pour les pages dynamiques).
- [ ] Identifier les pages dynamiques et ajouter `export const prerender = false`.
- [ ] Rebuild local pour vérifier que `dist/server/entry.mjs` existe toujours.
- [ ] Commit + push sur le repo `j12zdotcom`.

### 2) Côté infra Nix (repo nix-config)

- [ ] Sur Magnolia, vérifier le chemin exact de `entry.mjs` dans le store Nix (après `nix build`).
- [ ] Mettre à jour `hosts/mimosa/webserver.nix` :
- [ ] Ajouter un service systemd `j12zdotcom` qui lance Node.
- [ ] Modifier Caddy pour faire `reverse_proxy 127.0.0.1:4321`.
- [ ] Garder `cloudflared` et `sops` inchangés.
- [ ] Commit + push sur le repo `nix-config`.

### 3) Déploiement (Magnolia → Mimosa)

- [ ] Lancer `ra` sur Magnolia (met à jour `j12zdotcom` + build + cache).
- [ ] Lancer `da` sur Magnolia (déploie sur Mimosa).
- [ ] Vérifier sur Mimosa :
- [ ] `systemctl status j12zdotcom`
- [ ] `journalctl -u j12zdotcom -f`
- [ ] `curl http://127.0.0.1:4321`
- [ ] Tester l'URL publique.

### 4) Rollback (si besoin)

- [ ] Sur Mimosa : `sudo nixos-rebuild switch --rollback`.

Top, si le build SSR tourne bien en local, on peut l’intégrer proprement dans Mimosa. Il y a 2 changements NixOS à
faire :

1. lancer le serveur Node (systemd)
2. faire proxy Caddy → Node

Voici la version minimale et sûre à mettre dans hosts/mimosa/webserver.nix (je te laisse valider le chemin exact du
entry.mjs après build Nix) :

# hosts/mimosa/webserver.nix

{ config, lib, pkgs, j12zdotcom, ... }:

let
cfg = config.mimosa.webserver;
sitePackage = j12zdotcom.packages.x86_64-linux.site;
in
{
options.mimosa.webserver.enable = lib.mkEnableOption "the j12z webserver for mimosa";

    config = lib.mkIf cfg.enable {
      # ✅ Nouveau service Node (Astro SSR/Hybrid)
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

      # ✅ Caddy devient reverse proxy
      services.caddy = {
        enable = true;
        globalConfig = ''
          auto_https off
        '';
        virtualHosts."http://jeremiealcaraz.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:4321

            encode gzip zstd

            header {
              X-Frame-Options "SAMEORIGIN"
              X-Content-Type-Options "nosniff"
              X-XSS-Protection "1; mode=block"
              Referrer-Policy "strict-origin-when-cross-origin"
              Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-

src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:;
connect-src 'self' https:; media-src 'self' https:;"
Permissions-Policy "geolocation=(), microphone=(), camera=()"
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

      # (cloudflared + sops inchangés)
    };

}

Points importants

- Le chemin ${sitePackage}/server/entry.mjs suppose que le package Nix copie bien dist à la racine.
    Si dans le store tu vois .../dist/server/entry.mjs, alors change en ${sitePackage}/dist/server/entry.mjs et
    WorkingDirectory = "${sitePackage}/dist";.
- Avec ra + da, la nouvelle version du site est buildée sur Magnolia puis téléchargée sur Mimosa via le cache.

Déploiement (ta méthode habituelle)

1. Push tes modifs dans le repo j12zdotcom (adapter + output hybrid).
2. Dans nix-config, applique la modification ci‑dessus.
3. Sur Magnolia :
   - ra (met à jour j12zdotcom + build + cache)
   - da (déploie Mimosa)
4. Vérifs sur Mimosa :
   - systemctl status j12zdotcom
   - journalctl -u j12zdotcom -f
   - curl <http://127.0.0.1:4321>

Rollback ultra simple
Si besoin : sudo nixos-rebuild switch --rollback sur Mimosa.

Si tu veux, je peux appliquer directement le changement dans hosts/mimosa/webserver.nix et te dire exactement quoi
exécuter pour valider (avec vérifs du chemin entry.mjs).
