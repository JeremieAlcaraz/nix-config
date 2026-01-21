# Architecture de Déploiement - jeremiealcaraz.com

> Documentation complète du système de déploiement automatisé avec GitHub Actions, NixOS et Tailscale

---

## 🎯 Vue d'ensemble

Ce système permet de déployer automatiquement le site web **jeremiealcaraz.com** depuis GitHub vers un serveur de production, en utilisant un serveur de build dédié et un cache binaire pour optimiser les performances.

## 🏗️ Architecture Globale

```
┌─────────────────────────────────────────────────────────────────┐
│                         GITHUB                                   │
│                                                                   │
│  ┌────────────────┐              ┌─────────────────┐            │
│  │  j12zdotcom    │              │   nix-config    │            │
│  │  (Website)     │              │   (NixOS)       │            │
│  └────────┬───────┘              └────────┬────────┘            │
│           │                               │                      │
│           │ Push sur main                 │ flake.lock push      │
│           │ déclenche workflow            │ automatique          │
│           │                               │                      │
│           ▼                               ▲                      │
│  ┌─────────────────────────────────────────────────┐            │
│  │         GitHub Actions Workflow                 │            │
│  │         (Ubuntu runner éphémère)                │            │
│  └───────────────────┬─────────────────────────────┘            │
└────────────────────────────────────────────────────────────────┘
                       │
                       │ Connexion via Tailscale VPN
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌───────────────────┐         ┌──────────────────┐
│    MAGNOLIA       │         │     MIMOSA       │
│  (Build Server)   │────────▶│ (Web Server)     │
│                   │  Cache  │                  │
│  • Build j12z     │ Binaire │  • Télécharge    │
│  • nix-serve      │ HTTP    │    depuis cache  │
│  • Push flake     │ :5000   │  • Déploie site  │
│                   │         │  • Cloudflare    │
└───────────────────┘         └──────────────────┘
```

## 🔄 Flux de Déploiement Détaillé

### Étape 1 : Déclenchement

```
Developer ──push──▶ GitHub (j12zdotcom/main)
                         │
                         ▼
                   Workflow déclenché
                         │
                         ▼
                   Ubuntu Runner démarre
```

### Étape 2 : Connexion Sécurisée

```
GitHub Actions Runner
        │
        ├─▶ [1] Connexion Tailscale VPN
        │        (ephemeral node, tag:github-actions)
        │
        ├─▶ [2] Setup SSH Keys
        │        • DEPLOY_SSH_KEY → ~/.ssh/deploy_key
        │        • Config SSH pour magnolia et mimosa
        │
        └─▶ [3] Prêt à communiquer avec les serveurs
```

### Étape 3 : Build sur Magnolia

```
GitHub Actions ──SSH──▶ Magnolia
                            │
                            ▼
                    ┌───────────────────────────────┐
                    │ 1. git fetch && reset --hard  │
                    │    (GitHub = source of truth) │
                    └──────────┬────────────────────┘
                               │
                               ▼
                    ┌───────────────────────────────┐
                    │ 2. nix flake update j12zdotcom │
                    │    (Met à jour la dépendance) │
                    └──────────┬────────────────────┘
                               │
                               ▼
                    ┌───────────────────────────────────────┐
                    │ 3. nix build ...mimosa...toplevel     │
                    │    ⚡ BUILD MIMOSA CONFIG = Peuple    │
                    │       le cache avec j12zdotcom !      │
                    └──────────┬────────────────────────────┘
                               │
                               ▼
                    ┌───────────────────────────────┐
                    │ 4. nixos-rebuild .#magnolia   │
                    │    (Rebuild propre config)    │
                    └──────────┬────────────────────┘
                               │
                               ▼
                    ┌───────────────────────────────┐
                    │ 5. git commit + push          │
                    │    (flake.lock → GitHub)      │
                    └───────────────────────────────┘
                               │
                               ▼
                    Cache binaire à jour ! ✅
```

**⚡ Point clé** : La commande `nix build .#nixosConfigurations.mimosa.config.system.build.toplevel` est **CRUCIALE** ! Elle force Magnolia à builder toute la configuration de Mimosa (incluant j12zdotcom) pour peupler son `/nix/store`, permettant à nix-serve de servir ces packages.

### Étape 4 : Déploiement sur Mimosa

```
GitHub Actions ──SSH──▶ Mimosa
                            │
                            ▼
                    ┌───────────────────────────────┐
                    │ 1. git fetch && reset --hard  │
                    │    (Sync avec GitHub)         │
                    └──────────┬────────────────────┘
                               │
                               ▼
                    ┌───────────────────────────────────────┐
                    │ 2. nixos-rebuild .#mimosa             │
                    │                                       │
                    │    Nix vérifie le cache :             │
                    │    • cache.nixos.org ?                │
                    │    • http://magnolia:5000 ? ✅        │
                    │                                       │
                    │    ⚡ Télécharge depuis Magnolia      │
                    │       au lieu de rebuilder !          │
                    └──────────┬────────────────────────────┘
                               │
                               ▼
                    Déploiement rapide ! (~10-15s) ✅
```

### Étape 5 : Finalisation

```
GitHub Actions
        │
        ├─▶ Purge Cloudflare Cache
        │   (API REST : purge_everything)
        │
        └─▶ Site mis à jour ! 🎉
```

---

## 🔑 Composants Clés

### 1. Clés SSH

#### GitHub Actions → Serveurs (Deploy Key)

**Localisation** : Secrets GitHub `DEPLOY_SSH_KEY`

**Usage** :
- GitHub Actions se connecte à Magnolia ET Mimosa
- Même clé pour les deux serveurs (simplifié)

**Configuration NixOS** : `/home/user/nix-config/modules/github-actions.nix`

```nix
users.users.jeremie.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3Nza...Sz+no/ github-actions"
];
```

#### Magnolia → GitHub (Deploy Key)

**Localisation** : Secret sops-nix `github-deploy-key`

**Usage** :
- Magnolia push flake.lock vers GitHub
- Accès en écriture sur le repo nix-config

**Configuration NixOS** : `/home/user/nix-config/modules/github-deploy.nix`

```nix
sops.secrets."github-deploy-key" = {
  mode = "0600";
  owner = "jeremie";
};

programs.ssh.extraConfig = ''
  Host github.com
    IdentityFile /home/jeremie/.ssh/github-deploy
    IdentitiesOnly yes
'';
```

### 2. Cache Binaire (nix-serve)

**Serveur** : Magnolia (port 5000)

**Configuration** : `/home/user/nix-config/modules/nix-serve.nix`

```nix
services.nix-serve = {
  enable = true;
  port = 5000;
  secretKeyFile = "/var/cache-keys/cache-private-key.pem";
  bindAddress = "0.0.0.0";  # Écoute sur Tailscale
};
```

**Génération clé** (déjà fait) :
```bash
nix-store --generate-binary-cache-key magnolia.cache \
  /var/cache-keys/cache-private-key.pem \
  /var/cache-keys/cache-public-key.pem
```

**Client** : Mimosa

**Configuration** : `/home/user/nix-config/hosts/mimosa/configuration.nix`

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "http://magnolia:5000"
  ];

  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "magnolia.cache:7MVdzDOzQsVItEh+ewmU4Ga8TOke40asmXY1p9nQhC0="
  ];
};
```

### 3. Tailscale VPN

**Rôle** : Connexion sécurisée GitHub Actions ↔ Serveurs privés

**Configuration GitHub Actions** :
```yaml
- uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
    tags: tag:github-actions
```

**Nœuds éphémères** : Le runner GitHub se connecte temporairement au Tailnet et se déconnecte automatiquement après le job.

---

## 📊 Performances

### Avant optimisation (cache non utilisé)

```
Magnolia : ~10s   (rebuild propre config sans j12zdotcom)
Mimosa   : ~60s   (doit builder j12zdotcom lui-même)
─────────────────
Total    : ~70s   ❌ Mimosa rebuilde ce que Magnolia aurait pu cacher
```

### Après optimisation (cache fonctionnel)

```
Magnolia : ~90s   (build mimosa config + propre rebuild)
Mimosa   : ~15s   (télécharge depuis cache Magnolia)
─────────────────
Total    : ~105s  ✅ Temps total similaire, mais Mimosa déploie vite
```

**Avantage** : Mimosa devient un simple "téléchargeur" rapide. Le build lourd est fait sur Magnolia qui a plus de ressources.

---

## 🛠️ Troubleshooting

### Problème : Mimosa build au lieu de télécharger

**Symptômes** :
```
these 8 derivations will be built:
  /nix/store/...j12zdotcom-1.0.0.drv
```

**Causes possibles** :
1. ❌ Magnolia n'a pas buildé la config de Mimosa
2. ❌ nix-serve n'est pas actif sur Magnolia
3. ❌ Mimosa ne peut pas atteindre `http://magnolia:5000`
4. ❌ Signature key mismatch

**Solution** :
```bash
# Sur Magnolia : vérifier nix-serve
systemctl status nix-serve

# Sur Mimosa : tester la connexion au cache
curl http://magnolia:5000/nix-cache-info

# Vérifier que Magnolia a bien j12zdotcom dans son store
nix path-info /nix/store/*j12zdotcom*
```

### Problème : Fish shell incompatibilité

**Symptôme** :
```
fish: Missing end to balance this if statement
```

**Solution** : Forcer bash dans les commandes SSH
```bash
ssh magnolia bash << 'ENDSSH'
  # commandes bash ici
ENDSSH
```

### Problème : YAML syntax error

**Symptôme** :
```
Invalid workflow file - error in your yaml syntax
```

**Cause** : Variables GitHub Actions `${{ }}` dans les heredocs

**Solution** : Simplifier les messages de commit, éviter multi-lignes avec variables

---

## 🔐 Secrets GitHub

Liste complète des secrets nécessaires :

| Secret | Description | Où le trouver |
|--------|-------------|---------------|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth Client ID | Tailscale Admin Console → OAuth Clients |
| `TS_OAUTH_SECRET` | Tailscale OAuth Secret | Tailscale Admin Console → OAuth Clients |
| `DEPLOY_SSH_KEY` | Clé SSH privée pour GitHub Actions | Générée avec `ssh-keygen`, publique dans `github-actions.nix` |
| `MAGNOLIA_HOST` | IP Tailscale de Magnolia | `tailscale ip -4 magnolia` |
| `MIMOSA_HOST` | IP Tailscale de Mimosa | `tailscale ip -4 mimosa` |
| `CLOUDFLARE_ZONE_ID` | ID de zone Cloudflare | Cloudflare Dashboard → Zone |
| `CLOUDFLARE_API_TOKEN` | Token API Cloudflare | Cloudflare Dashboard → API Tokens |

---

## 📝 Commandes Utiles

### Sur Magnolia

```bash
# Vérifier le cache binaire
systemctl status nix-serve
curl http://localhost:5000/nix-cache-info

# Voir ce qui est dans le store
nix path-info --all | grep j12zdotcom

# Rebuilder manuellement
cd /etc/nixos
nix build .#nixosConfigurations.mimosa.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#magnolia
```

### Sur Mimosa

```bash
# Tester la connexion au cache
curl http://magnolia:5000/nix-cache-info

# Vérifier la config des substituters
nix show-config | grep substituters

# Forcer l'utilisation du cache
sudo nixos-rebuild switch --flake .#mimosa --option substituters "https://cache.nixos.org http://magnolia:5000"
```

### Depuis GitHub Actions (debug local)

```bash
# Simuler la connexion SSH
ssh jeremie@<magnolia-ip> -i ~/.ssh/deploy_key "hostname && whoami"

# Tester le workflow manuellement
gh workflow run deploy.yml
gh run watch
```

---

## 🎯 Points Clés à Retenir

1. **GitOps** : GitHub est la source de vérité (`git reset --hard origin/main`)
2. **Cache Binaire** : Magnolia build, Mimosa télécharge
3. **Build Mimosa Config** : Crucial pour peupler le cache sur Magnolia
4. **Tailscale** : VPN sécurisé pour GitHub Actions → serveurs privés
5. **Deploy Keys** : Deux clés distinctes (Actions→Serveurs, Magnolia→GitHub)
6. **Bash Explicit** : Toujours forcer `bash` dans les SSH heredocs

---

## 📚 Fichiers de Configuration

### Fichiers modifiés dans nix-config

```
nix-config/
├── modules/
│   ├── github-actions.nix    # SSH key pour GitHub Actions
│   ├── github-deploy.nix     # Deploy key pour Magnolia→GitHub
│   ├── nix-serve.nix          # Cache binaire sur Magnolia
│   └── ssh.nix                # Config SSH générale
├── hosts/
│   ├── magnolia/
│   │   └── configuration.nix  # Importe github-deploy + nix-serve
│   └── mimosa/
│       └── configuration.nix  # Substituters + trusted-public-keys
└── flake.nix                  # Définit les configs magnolia/mimosa
```

### Fichier workflow

```
j12zdotcom/
└── .github/
    └── workflows/
        └── deploy.yml         # Workflow complet de déploiement
```

---

## 🚀 Workflow de Développement

```
1. Developer fait des modifs sur j12zdotcom
   ↓
2. git push origin main
   ↓
3. GitHub Actions démarre automatiquement
   ↓
4. Magnolia build j12zdotcom + cache binaire
   ↓
5. Magnolia push flake.lock vers GitHub
   ↓
6. Mimosa télécharge et déploie (rapide!)
   ↓
7. Cloudflare cache purgé
   ↓
8. Site live en ~2 minutes ! 🎉
```

---

**Date de création** : 2025-11-26
**Auteur** : Claude + Jérémie Alcaraz
**Version** : 1.0
