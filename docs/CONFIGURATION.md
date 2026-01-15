# Configuration centralisée du projet

Ce document explique comment utiliser le fichier `config.nix` pour gérer les variables globales du projet et configurer les workflows CI/CD.

## Structure du projet

```
nix-config/
├── config.nix              # ← Configuration centralisée (Nix)
├── flake.nix               # Import et distribue projectConfig
├── .gitea/workflows/       # Workflows Gitea (utilise variables)
├── .github/workflows/      # Workflows GitHub (utilise variables)
└── docs/CONFIGURATION.md   # ← Ce fichier
```

## Partie 1 : Configuration Nix (`config.nix`)

### Utilisation dans les modules NixOS

Le fichier `config.nix` contient toutes les variables globales du projet :

```nix
{
  gitForge = {
    type = "gitea";  # ou "github"
    gitea = { url = "http://100.96.250.43:3000"; ... };
    github = { url = "https://github.com"; ... };
  };

  services = {
    n8n.url = "https://n8n.jeremiealcaraz.com";
    website.url = "https://jeremiealcaraz.com";
  };

  tailscale = {
    hosts = { ... };
  };
}
```

### Accès dans un module NixOS

Dans n'importe quel module NixOS, tu peux accéder à `projectConfig` :

```nix
# hosts/dandelion/configuration.nix
{ config, pkgs, projectConfig, ... }:

{
  # Exemple : utiliser l'URL Gitea depuis la config
  services.gitea = {
    enable = true;
    settings.server.ROOT_URL = projectConfig.gitForge.gitea.url;
  };

  # Exemple : configurer selon le type de forge
  environment.variables = {
    GIT_SERVER = projectConfig.gitForge.type;
  };
}
```

### Changer de Gitea vers GitHub

Il suffit de modifier une ligne dans `config.nix` :

```nix
{
  gitForge = {
    type = "github";  # ← Change ici de "gitea" à "github"
    # ...
  };
}
```

Puis rebuild :

```bash
sudo nixos-rebuild switch --flake .#dandelion
```

## Partie 2 : Stratégie Git Remote (SSH vs HTTP)

### Architecture des remotes

Le projet utilise une stratégie **hybride** pour les remotes Git :

| Machine | Remote Origin | Type | Raison |
|---------|---------------|------|--------|
| **Marigold (Mac)** | `gitea@dandelion:...` | SSH | Peut push/pull (développement) |
| **Magnolia** | `gitea@dandelion:...` | SSH | Peut push/pull (cache builder + déploiements) |
| **Whitelily** | `http://100.96.250.43:3000/...` | HTTP | Pull uniquement (read-only) |
| **Dandelion** | `http://dandelion:3000/...` | HTTP | Pull uniquement (self-update) |
| **Mimosa** | `http://100.96.250.43:3000/...` | HTTP | Pull uniquement (read-only) |

### Pourquoi cette stratégie ?

**SSH** :
- ✅ Authentification par clés (pas de password)
- ✅ Sécurisé et rapide
- ✅ Permet push et pull
- ❌ Nécessite clés SSH configurées

**HTTP** :
- ✅ Fonctionne sans configuration SSH
- ✅ Parfait pour pull read-only
- ⚠️ Push nécessiterait credentials
- ✅ Plus simple pour les VMs qui font juste des updates

**Qui a besoin de push ?**
- Marigold (Mac) : développement quotidien
- Magnolia : build cache + déploiements automatisés
- Les autres VMs font seulement `git pull` pour se mettre à jour

### Configuration dans config.nix

```nix
gitea = {
  # HTTP - Pour VMs en read-only
  url = "http://100.96.250.43:3000";

  # SSH - Pour machines qui peuvent push
  sshUrl = "gitea@dandelion:jeremiealcaraz/nix-config.git";
  sshHost = "gitea@dandelion";
};
```

### Vérifier ta configuration

```bash
# Sur n'importe quelle machine
cd /etc/nixos
git remote -v

# Tester un fetch
git fetch origin
```

## Partie 3 : Variables pour les Workflows CI/CD

### Pourquoi des variables séparées ?

Les workflows GitHub/Gitea Actions s'exécutent dans des conteneurs isolés **sans accès à Nix**.
Ils ont besoin de **variables repository** configurées dans l'interface web.

### Configuration dans Gitea

1. Va sur ton dépôt Gitea : `http://100.96.250.43:3000/JeremieAlcaraz/nix-config`
2. Clique sur **Settings** (⚙️)
3. Dans le menu latéral, clique sur **Secrets and Variables** → **Actions**
4. Onglet **Variables**
5. Clique sur **New Variable**

Crée ces variables :

| Nom | Valeur | Description |
|-----|--------|-------------|
| `GIT_SERVER_URL` | `http://100.96.250.43:3000` | URL de ton serveur Git |
| `GIT_SERVER_TYPE` | `gitea` | Type de forge (gitea ou github) |

### Configuration dans GitHub

1. Va sur ton dépôt GitHub : `https://github.com/JeremieAlcaraz/nix-config`
2. Clique sur **Settings**
3. Dans le menu latéral, clique sur **Secrets and variables** → **Actions**
4. Onglet **Variables**
5. Clique sur **New repository variable**

Crée ces variables :

| Nom | Valeur | Description |
|-----|--------|-------------|
| `GIT_SERVER_URL` | `https://github.com` | URL de GitHub |
| `GIT_SERVER_TYPE` | `github` | Type de forge |

### Utilisation dans un workflow

```yaml
name: Mon workflow
on: [push]

jobs:
  mon-job:
    runs-on: ubuntu-latest
    env:
      # Utilise les variables repository avec fallback
      GIT_SERVER_URL: ${{ vars.GIT_SERVER_URL || 'http://100.96.250.43:3000' }}
      GIT_SERVER_TYPE: ${{ vars.GIT_SERVER_TYPE || 'gitea' }}

    steps:
      - uses: actions/checkout@v4
        with:
          github-server-url: ${{ env.GIT_SERVER_URL }}

      - name: Afficher la config
        run: |
          echo "Serveur : $GIT_SERVER_TYPE"
          echo "URL     : $GIT_SERVER_URL"
```

### Exemple réel : Mise à jour de n8n

Regarde `.github/workflows/update-n8n-next.yml:17` :

```yaml
steps:
  - uses: actions/checkout@v4
    # Utilise la variable configurée dans GitHub
```

Pour adapter ce workflow à Gitea, il suffit de :
1. Copier le fichier dans `.gitea/workflows/`
2. Ajouter `github-server-url: ${{ env.GIT_SERVER_URL }}` à l'action checkout
3. Les variables Gitea seront automatiquement utilisées !

## Partie 4 : Workflow complet

### Scénario : Basculer de Gitea vers GitHub

#### Étape 1 : Configuration Nix (pour les hosts NixOS)

```bash
# Édite config.nix
vim config.nix
# Change type de "gitea" à "github"

# Rebuild les machines
ssh jeremie@dandelion
cd /root/nix-config
sudo git pull
sudo nixos-rebuild switch --flake .#dandelion
```

#### Étape 2 : Variables workflow (pour les CI/CD)

**Sur Gitea :**
- Settings → Actions → Variables
- Change `GIT_SERVER_URL` → `https://github.com`
- Change `GIT_SERVER_TYPE` → `github`

**Sur GitHub :**
- Settings → Actions → Variables
- Change `GIT_SERVER_URL` → `https://github.com`
- Change `GIT_SERVER_TYPE` → `github`

#### Étape 3 : Push les workflows

```bash
git add .gitea/workflows/ .github/workflows/
git commit -m "Update workflows for GitHub"
git push
```

## Exemples pratiques

### Exemple 1 : Workflow de test

Fichier : `.gitea/workflows/example-with-variables.yaml`

Ce workflow montre comment :
- Utiliser les variables repository
- Avoir des fallbacks par défaut
- Détecter le type de serveur
- Adapter le comportement selon l'environnement

Lance-le manuellement depuis Gitea pour tester !

### Exemple 2 : Script de déploiement

```nix
# scripts/deploy.nix
{ projectConfig, pkgs, ... }:

pkgs.writeScriptBin "deploy-to-production" ''
  #!/usr/bin/env bash
  set -e

  echo "🚀 Déploiement vers ${projectConfig.services.website.url}"

  # Le script s'adapte automatiquement selon config.nix
  if [[ "${projectConfig.gitForge.type}" == "gitea" ]]; then
    echo "📦 Utilisation de Gitea: ${projectConfig.gitForge.gitea.url}"
  else
    echo "📦 Utilisation de GitHub: ${projectConfig.gitForge.github.url}"
  fi
''
```

## Avantages de cette approche

### Pour Nix (config.nix)
- ✅ Un seul endroit à modifier (`config.nix`)
- ✅ Typage et validation par Nix
- ✅ Réutilisable dans tous les modules NixOS
- ✅ Rebuild automatique avec les nouvelles valeurs

### Pour les workflows (variables)
- ✅ Pas besoin de rebuild pour changer les workflows
- ✅ Interface web simple (Gitea/GitHub Settings)
- ✅ Valeurs différentes par dépôt/environnement
- ✅ Fallbacks par défaut dans le YAML

## Résumé

| Contexte | Solution | Où configurer |
|----------|----------|---------------|
| **Modules NixOS** | `config.nix` | Fichier à la racine |
| **Workflows Actions** | Variables repository | Interface web Gitea/GitHub |
| **Scripts shell** | Source `.env` ou use Nix | `.env` ou module Nix |

## Questions fréquentes

**Q : Puis-je utiliser `config.nix` dans mes workflows ?**
R : Non directement, les runners n'ont pas Nix installé. Utilise les variables repository.

**Q : Comment synchroniser config.nix et les variables ?**
R : Manuellement. Tu pourrais créer un script qui génère un `.env` depuis `config.nix` pour automatiser.

**Q : Que faire si j'oublie de créer les variables ?**
R : Les workflows utilisent les valeurs par défaut (fallback dans le YAML).

**Q : Est-ce que les secrets doivent être dans config.nix ?**
R : NON ! Les secrets vont dans `secrets/*.yaml` (sops-nix) et dans les **Secrets** (pas Variables) de Gitea/GitHub.

## Prochaines étapes

1. ✅ Teste le workflow d'exemple : `.gitea/workflows/example-with-variables.yaml`
2. Configure tes variables dans Gitea Settings
3. Adapte tes workflows existants (comme `demo.yaml`) pour utiliser les variables
4. Utilise `projectConfig` dans tes modules NixOS

Bon dev ! 🚀
