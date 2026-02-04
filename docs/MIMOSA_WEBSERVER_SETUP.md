# Guide complet: Déploiement du webserver sur Mimosa

Ce guide explique comment reproduire complètement le setup du webserver j12zdotcom sur l'hôte mimosa.

## 📋 Vue d'ensemble

**Architecture:**
- **Caddy**: Serveur web qui sert les fichiers statiques (HTTP sur port 80)
- **Cloudflare Tunnel**: Tunnel sécurisé qui expose le site publiquement
- **SOPS**: Gestion des secrets (token Cloudflare)
- **Site**: Astro static site dans `/var/www/j12zdotcom`

**Flux de données:**
```
Utilisateur (HTTPS) → Cloudflare Edge (TLS) → Cloudflare Tunnel (HTTP) → Caddy (localhost:80) → Fichiers statiques
```

## 🔐 Auth, proxy et mode maintenance (important)

Cette section évite les surprises quand un module d'auth est ajouté (Better Auth, NextAuth, OAuth, etc.).

### Définitions rapides
- **IP cliente**: IP d'origine du visiteur.
- **IP proxy**: IP du composant intermédiaire (Cloudflare / cloudflared).
- **`X-Forwarded-*`**: en-têtes ajoutés par le proxy pour transmettre l'IP, le host et le protocole d'origine.
  - `X-Forwarded-For`: IP cliente d'origine
  - `X-Forwarded-Proto`: `http` ou `https` vu par l'utilisateur
  - `X-Forwarded-Host`: host demandé par l'utilisateur
- **`CF-Connecting-IP`**: IP cliente fournie par Cloudflare.
- **`trust proxy`**: côté application, autorise l'usage de ces en-têtes comme source de vérité.

### Pourquoi c'est critique pour l'auth
- Sans `trust proxy`, l'app peut croire qu'elle tourne en HTTP local, et casser les cookies `Secure` ou les callbacks OAuth.
- Une auth basée sur l'IP peut échouer si l'app voit le proxy au lieu du client.
- En mode maintenance, les visiteurs non allowlist sont redirigés vers `/wip`: les routes d'auth ne seront pas atteignables tant qu'elles ne sont pas explicitement exemptées.

### Cas Tailscale vs domaine public
- **Sur `https://jeremiealcaraz.com` (public via Cloudflare)**: Caddy voit l'IP publique du client (ou de l'exit node), pas l'IP Tailscale.
- **IP Tailscale visible** uniquement si le client résout le domaine vers l'IP Tailscale de `mimosa` (split-DNS / accès tailnet).

### Checklist avant d'activer un module auth
1. Définir l'URL canonique en `https://jeremiealcaraz.com`.
2. Activer `trust proxy` dans l'app backend.
3. Vérifier les cookies `Secure` et `SameSite` selon le flux de login.
4. Ne pas dépendre exclusivement de l'IP pour autoriser une session.
5. Si maintenance active, décider si `/api/auth/*` doit rester accessible.

### Commandes de diagnostic utiles
```bash
# Voir ce que Caddy reçoit pendant un test
sudo journalctl -u caddy -b --no-pager -n 200

# Vérifier la résolution DNS côté client
dig +short jeremiealcaraz.com

# Vérifier les headers/proxy côté app (exemple)
curl -I https://jeremiealcaraz.com
```

## 🔧 État actuel et problèmes

### Problème: Build Nix sandbox
Le site Astro utilise `pnpm.fetchDeps` qui ne peut pas résoudre le DNS dans la sandbox Nix, même avec `extra-sandbox-paths`. C'est pourquoi on utilise **temporairement** un build manuel.

### Solutions d'automatisation

#### Option 1: Script de déploiement (Simple, recommandé pour l'instant)
#### Option 2: GitHub Actions + artifact (Automatique)
#### Option 3: Fixer le build Nix (Propre mais complexe)

---

## 🚀 Reproduction complète du setup (de zéro)

### Étape 1: Préparation des secrets

Sur ta **machine de développement** (magnolia), crée/vérifie les secrets:

```bash
cd /home/jeremie/nix-config

# Vérifier que le token Cloudflare est dans secrets/mimosa.yaml
export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
sops secrets/mimosa.yaml

# Le fichier doit contenir:
cloudflare-tunnel-token: eyJhIjoiOWRm...  # Ton token (184 caractères)
```

**Obtenir le token Cloudflare:**
1. Va sur https://one.dash.cloudflare.com
2. Zero Trust → Access → Tunnels → Configure ton tunnel
3. Copie le token (commence par `eyJ`)

### Étape 2: Configuration NixOS

Les fichiers importants dans le flake:

**`flake.nix`** - Définit la configuration mimosa:
```nix
mimosa = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./modules/base.nix
    ./modules/ssh.nix
    ./hosts/mimosa/configuration.nix
    ./hosts/mimosa/webserver.nix  # Config webserver
    j12zdotcom.nixosModules.j12z-webserver  # Module du site
    sops-nix.nixosModules.sops
    home-manager.nixosModules.home-manager
    # ...
    # Active le webserver
    { mimosa.webserver.enable = true; }
  ];
};
```

**`hosts/mimosa/webserver.nix`** - Configuration du webserver:
- Active le service j12z-webserver
- Configure le domaine: jeremiealcaraz.com
- Pointe vers `/var/www/j12zdotcom` (build manuel temporaire)
- Configure le secret Cloudflare via SOPS
- Override Caddy pour accepter HTTP (pas de redirection HTTPS)
- Configure systemd pour cloudflared avec LoadCredential

### Étape 3: Build et déploiement du site

#### Déploiement via deploy-website-action (Go)

Créer `.github/workflows/deploy-site.yml`:

```yaml
name: Deploy j12zdotcom to Mimosa

on:
  repository_dispatch:
    types: [deploy-site]
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout j12zdotcom
        uses: actions/checkout@v4
        with:
          repository: JeremieAlcaraz/j12zdotcom

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Setup pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install

      - name: Build site
        run: pnpm build

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: site-dist
          path: dist/
          retention-days: 7

      - name: Deploy to Mimosa
        env:
          SSH_PRIVATE_KEY: ${{ secrets.MIMOSA_SSH_KEY }}
          HOST: ${{ secrets.MIMOSA_HOST }}
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan "$HOST" >> ~/.ssh/known_hosts

          # Deploy files
          rsync -avz --delete dist/ "$HOST:/var/www/j12zdotcom/" --rsync-path="sudo rsync"

          # Trigger rebuild
          ssh "$HOST" "cd /etc/nixos && sudo nixos-rebuild switch --flake .#mimosa --impure"
```

**Setup GitHub Actions:**
1. Crée un secret `MIMOSA_SSH_KEY` avec ta clé SSH privée
2. Crée un secret `MIMOSA_HOST` avec `jeremie@mimosa` (ou IP Tailscale)

Ensuite, déclenche le déploiement depuis le repo j12zdotcom:
```bash
# Ajouter un webhook dans j12zdotcom pour déclencher le workflow
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/JeremieAlcaraz/nix-config/dispatches \
  -d '{"event_type":"deploy-site"}'
```

#### Option C: Fixer le build Nix (Propre mais complexe)

Pour un vrai build Nix reproductible, il faudrait:

1. **Utiliser `npmlock2nix` ou `dream2nix`** au lieu de `pnpm.fetchDeps`
2. **Ou utiliser un cache binaire** pour les dépendances npm
3. **Ou désactiver la sandbox temporairement** pour ce build spécifique

Exemple avec désactivation sandbox (dans `flake.nix` du site):
```nix
# Dans j12zdotcom/flake.nix
j12zdotcom = stdenv.mkDerivation {
  # ...
  __noChroot = true;  # Désactive la sandbox (DANGER: non reproductible!)
};
```

**Je ne recommande pas cette approche** car elle casse la reproductibilité Nix.

---

## 🔄 Reproduction complète (Checklist)

### Sur ta machine de développement (Magnolia)

1. **Vérifier les secrets:**
   ```bash
   cd /home/jeremie/nix-config
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
   sops secrets/mimosa.yaml  # Vérifier que cloudflare-tunnel-token existe
   ```

2. **Vérifier la configuration:**
   ```bash
   # Vérifier que webserver.nix est correct
   cat hosts/mimosa/webserver.nix

   # Vérifier que le flake active le webserver
   nix flake show
   ```

3. **Commit et push:**
   ```bash
   git add -A
   git commit -m "Configuration webserver mimosa"
   git push
   ```

### Sur Mimosa (première installation)

1. **Cloner la config:**
   ```bash
   sudo mkdir -p /etc/nixos
   sudo chown jeremie:users /etc/nixos
   cd /etc/nixos
   git clone https://github.com/JeremieAlcaraz/nix-config.git .
   git checkout claude/enable-mimosa-webserver-01CCtTLbKEwruEvaB7gVtRdj
   ```

2. **Copier les clés age (si pas déjà fait):**
   ```bash
   # Option 1: Copier depuis magnolia
   scp magnolia:~/.config/sops/age/key.txt ~/.config/sops/age/key.txt

   # Option 2: Utiliser la clé SSH host (déjà configuré dans SOPS)
   # Les clés SSH de mimosa sont déjà autorisées dans secrets/mimosa.yaml
   ```

3. **Builder et déployer le site:**
   ```bash
   # Build du site (une seule fois ou à chaque mise à jour)
   cd /tmp
   git clone https://github.com/JeremieAlcaraz/j12zdotcom.git
   cd j12zdotcom
   nix-shell -p nodejs_20 pnpm_9 vips --run "pnpm install && pnpm build"

   # Copier les fichiers
   sudo mkdir -p /var/www/j12zdotcom
   sudo cp -r dist/* /var/www/j12zdotcom/
   ```

4. **Activer la configuration:**
   ```bash
   cd /etc/nixos
   sudo nixos-rebuild switch --flake .#mimosa --impure
   ```

5. **Vérifier que tout fonctionne:**
   ```bash
   sudo systemctl status caddy
   sudo systemctl status cloudflared
   curl http://localhost
   ```

6. **Tester publiquement:**
   ```bash
   curl https://jeremiealcaraz.com
   ```

### Configuration Cloudflare (une seule fois)

1. **Active "Always Use HTTPS":**
   - Dashboard → jeremiealcaraz.com → SSL/TLS → Edge Certificates
   - Active "Always Use HTTPS"

2. **Configure le mode SSL:**
   - SSL/TLS → Overview
   - Mode: **Full** (recommandé)

3. **Configure le tunnel:**
   - Zero Trust → Access → Tunnels
   - Tunnel doit pointer vers `http://localhost:80`
   - Public hostname: `jeremiealcaraz.com` → `http://localhost:80`

---

## 📝 Fichiers importants

### Structure du projet
```
nix-config/
├── flake.nix                          # Définit mimosa avec webserver
├── hosts/mimosa/
│   ├── configuration.nix              # Config de base (réseau, users, etc)
│   ├── webserver.nix                  # Config webserver (CELUI-CI!)
│   └── hardware-configuration.nix     # Config matériel
└── secrets/
    └── mimosa.yaml                    # Secret Cloudflare (SOPS)
```

### Contenu de `webserver.nix` (version finale)
```nix
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
      siteRoot = /var/www/j12zdotcom;  # Build manuel (temporaire)
      enableCloudflaredTunnel = true;
      cloudflaredTokenFile = config.sops.secrets.cloudflare-tunnel-token.path;
    };

    # Override Caddy: accepter HTTP du tunnel (pas de redirect HTTPS)
    services.caddy.virtualHosts = lib.mkForce {
      "http://jeremiealcaraz.com" = {
        extraConfig = ''
          root * ${toString config.services.j12z-webserver.siteRoot}
          file_server
          encode gzip zstd
          # ... (headers, logging, etc)
        '';
      };
    };

    # Secret Cloudflare Tunnel
    sops.secrets.cloudflare-tunnel-token = {
      owner = "root";
      group = "root";
      mode = "0444";  # Lisible par DynamicUser
    };

    # Fix systemd: LoadCredential pour le token
    systemd.services.cloudflared = {
      serviceConfig = {
        LoadCredential = "tunnel-token:${config.sops.secrets.cloudflare-tunnel-token.path}";
        ExecStart = lib.mkForce "${pkgs.bash}/bin/bash -c 'exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat $CREDENTIALS_DIRECTORY/tunnel-token)'";
      };
    };
  };
}
```

---

## 🐛 Problèmes résolus

### 1. Token Cloudflare invalide
**Problème:** systemd n'évalue pas `$(cat ...)` dans ExecStart
**Solution:** Utiliser `LoadCredential` + wrapper bash

### 2. Boucle de redirection HTTP→HTTPS
**Problème:** Caddy redirige HTTP→HTTPS, Cloudflare renvoie en HTTP
**Solution:** Forcer Caddy en mode HTTP uniquement avec `http://domain`

### 3. DynamicUser ne peut pas lire le secret
**Problème:** Fichier en mode 0400, l'utilisateur dynamique n'a pas accès
**Solution:** Mode 0444 (world-readable) + LoadCredential systemd

### 4. Build Nix sandbox échoue (pnpm)
**Problème:** pnpm.fetchDeps ne peut pas résoudre le DNS dans sandbox
**Solution temporaire:** Build manuel + copie dans /var/www

---

## ✅ Vérifications

### Santé du système
```bash
# Services actifs
sudo systemctl status caddy
sudo systemctl status cloudflared

# Logs en temps réel
sudo journalctl -u caddy -f
sudo journalctl -u cloudflared -f

# Test local
curl http://localhost
curl http://192.168.1.40  # IP LAN de mimosa

# Test public
curl https://jeremiealcaraz.com
```

### Métriques Cloudflare Tunnel
```bash
# Dashboard cloudflared (si activé)
curl http://localhost:39485/metrics
```

---

## 🔮 Prochaines améliorations

1. **Automatiser le build du site**
   - GitHub Actions qui build et upload un artifact
   - Script qui download l'artifact et déploie

2. **Fixer le build Nix**
   - Migrer de `pnpm.fetchDeps` vers `dream2nix`
   - Ou utiliser un cache binaire (Cachix)

3. **Monitoring**
   - Prometheus + Grafana pour métriques Caddy
   - Alertes si le tunnel se déconnecte

4. **Backups automatiques**
   - Script cron qui backup /var/www
   - Versioning avec git dans /var/www

---

## 📚 Ressources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [SOPS-nix](https://github.com/Mic92/sops-nix)
- [Caddy Docs](https://caddyserver.com/docs/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Astro Docs](https://docs.astro.build/)

---

**Créé le:** 2025-11-21
**Dernière mise à jour:** 2026-02-04
**Auteur:** Jérémie Alcaraz (avec l'aide de Claude)
