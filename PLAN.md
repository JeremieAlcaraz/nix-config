# Plan de migration Astro SSR/Static (Mimosa)

Checklist des étapes réalisées et restantes pour passer du site statique à un mode SSR partiel (Astro 5+), sans casser l'infra.

## ✅ Fait (validé le 2026-01-21)

### Phase 1 : Préparation et validation locale

#### Repo j12zdotcom
- [x] Adaptateur Node (`@astrojs/node` v9.5.1) déjà installé et configuré.
- [x] Configuration Astro 5+ validée : `output: 'static'` + `adapter: node({ mode: 'standalone' })`.
- [x] Page de test SSR créée (`/test-ssr.astro`) avec `export const prerender = false`.
- [x] Page de test statique créée (`/test-static.astro`) pour comparaison.
- [x] Build local réussi : `dist/server/entry.mjs` généré correctement (4.5K).
- [x] Test serveur Node local : `node dist/server/entry.mjs` fonctionne sur port 4321.
- [x] Validation SSR : date change à chaque refresh sur `/test-ssr`.
- [x] Validation static : date figée sur `/test-static`.
- [x] Commit + push pages de test (commit `f0067b7`).

#### Repo nix-config
- [x] Renommage `j12z-site` → `j12zdotcom` dans tout le projet (commit `f35a6f9`).
- [x] Mise à jour PLAN.md avec résultats validation (commit `e4fda7e`).

### Phase 2 : Build et validation Nix

- [x] Mise à jour hash pnpmDeps pour Linux x86_64 (commit `ec81498` + `64d7432`).
- [x] Résolution problème cache Nix source (commit vide `670b637` pour invalider cache).
- [x] Libération espace disque sur Magnolia (98% → 16% via garbage collection).
- [x] Build Nix réussi avec serveur SSR généré.
- [x] Vérification structure package : `/nix/store/r8pbci4ngs57kcllmymhmf58kppipqqk-j12zdotcom-1.0.0/`
  - ✅ `server/entry.mjs` (4.4K)
  - ✅ `server/pages/test-ssr.astro.mjs`
  - ✅ `client/test-static/` (pré-rendu)

**Chemin validé** : `${sitePackage}/server/entry.mjs` (PAS dans dist/)

### Phase 3 : Déploiement sur Mimosa ✅

#### Étape 1 : Modifier hosts/mimosa/webserver.nix

- [x] Mettre à jour `hosts/mimosa/webserver.nix` :
  - [x] Ajouter service systemd `j12zdotcom` qui lance Node
  - [x] Modifier Caddy : `file_server` → `reverse_proxy 127.0.0.1:4321`
  - [x] Garder `cloudflared` et `sops` inchangés
- [x] Commit + push sur le repo `nix-config` (commit `5afad1d`)

#### Étape 2 : Build avec node_modules

- [x] Modifier `j12zdotcom/flake.nix` pour copier node_modules de production
- [x] Fix erreur patch-shebangs (retirer `-u` flag)
- [x] Update flake.lock sur Magnolia
- [x] Build réussi avec package complet

#### Étape 3 : Déploiement

- [x] Push vers Gitea pour sync `origin/main`
- [x] Déploiement via `da` sur Mimosa
- [x] Service `j12zdotcom` actif et fonctionnel

#### Étape 4 : Vérifications

- [x] `systemctl status j12zdotcom` → Active (running) ✅
- [x] Node.js écoute sur `127.0.0.1:4321`
- [x] Test SSR : https://jeremiealcaraz.com/test-ssr → Date dynamique ✅
- [x] Test static : https://jeremiealcaraz.com/test-static → Date figée ✅
- [x] Pas d'erreurs dans les logs

**Tag créé** : `v1.2.0-mimosa-ssr-stable` 🎉

## 🎯 Résultat final

✅ **Migration réussie** : Le site jeremiealcaraz.com fonctionne maintenant en mode **Astro SSR/Hybrid** !

- Pages statiques pré-rendues (SSG) : build-time
- Pages dynamiques SSR : runtime avec Node.js
- Architecture : Cloudflare → Caddy (reverse proxy) → Node.js (port 4321)
- Package Nix complet avec node_modules de production
- Déploiement déclaratif NixOS validé

---

## 📝 Template de configuration (VALIDÉ)

**Chemin confirmé** : `${sitePackage}/server/entry.mjs` ✅
(Package Nix : `/nix/store/r8pbci4ngs57kcllmymhmf58kppipqqk-j12zdotcom-1.0.0/`)

Configuration à appliquer dans `hosts/mimosa/webserver.nix` :

```nix
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
            Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; frame-src 'self' https:; connect-src 'self' https:; media-src 'self' https:;"
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

    # ✅ Cloudflared + SOPS (inchangés)
    sops.secrets.cloudflare-tunnel-token = {
      owner = "root";
      group = "root";
      mode = "0444";
    };

    systemd.services.cloudflared = {
      description = "Cloudflare Tunnel";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        LoadCredential = "tunnel-token:${config.sops.secrets.cloudflare-tunnel-token.path}";
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat $CREDENTIALS_DIRECTORY/tunnel-token)'";
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [];
      };
    };
  };
}
```

---

## 🔧 Notes techniques

- **Chemin entry.mjs** : Le package Nix copie `dist/*` à la racine, donc `server/entry.mjs` (pas `dist/server/entry.mjs`)
- **Cache binaire** : Avec `ra` + `da`, le site est buildé sur Magnolia puis téléchargé sur Mimosa via le cache local
- **Rollback** : NixOS permet un retour arrière immédiat en cas de problème : `sudo nixos-rebuild switch --rollback`
