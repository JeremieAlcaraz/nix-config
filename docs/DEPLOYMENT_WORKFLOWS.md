# Workflows de déploiement - Où mettre quoi?

Guide pour choisir la bonne architecture de déploiement pour j12zdotcom.

## TL;DR - Recommandation

**✅ Mets le workflow dans le repo j12zdotcom** (pas dans nix-config)

```
j12zdotcom/.github/workflows/deploy.yml  ← Le workflow ici!
```

## Pourquoi?

### Approche 1: Workflow dans j12zdotcom ✅ (Recommandé)

```
j12zdotcom/
├── .github/workflows/
│   └── deploy.yml          ← Workflow ici
├── src/
└── package.json

nix-config/
├── hosts/mimosa/
│   └── webserver.nix       ← Config NixOS seulement
└── scripts/
    └── deploy-j12zdotcom.sh  ← Script manuel (optionnel)
```

**Avantages:**
- ✅ **Intuitif**: Push sur j12zdotcom → déploiement automatique
- ✅ **Pas de webhook**: GitHub Actions détecte automatiquement les push
- ✅ **Isolation**: Le code et son déploiement sont ensemble
- ✅ **CI/CD standard**: Pattern classique (code + workflow dans le même repo)
- ✅ **Facile à tester**: Les PR sur j12zdotcom peuvent déclencher des déploiements de test

**Inconvénients:**
- ⚠️ Besoin de secrets SSH dans j12zdotcom
- ⚠️ Si tu changes la logique de déploiement, tu dois modifier j12zdotcom

**Flux:**
```
1. Push sur j12zdotcom/main
2. GitHub Actions (dans j12zdotcom) se déclenche
3. Build le site
4. SSH vers mimosa
5. Déploie dans /var/www/j12zdotcom
6. Reload Caddy
```

---

### Approche 2: Workflow dans nix-config ⚠️ (Ce que j'ai fait par erreur)

```
j12zdotcom/
├── src/
└── package.json

nix-config/
├── .github/workflows/
│   └── deploy-j12zdotcom.yml  ← Workflow ici
├── hosts/mimosa/webserver.nix
└── scripts/deploy-j12zdotcom.sh
```

**Avantages:**
- ✅ **Centralisation infra**: Toute l'infra (NixOS + déploiement) au même endroit
- ✅ **Secrets déjà là**: Les secrets SSH sont dans nix-config
- ✅ **Vision globale**: Facile de voir toute l'infra mimosa

**Inconvénients:**
- ❌ **Moins intuitif**: Push sur j12zdotcom → rien ne se passe
- ❌ **Webhook complexe**: Nécessite de configurer un webhook ou repository_dispatch
- ❌ **Couplage étrange**: Le déploiement du site dépend de l'infra repo
- ❌ **Pas de CI sur j12zdotcom**: Les PR ne peuvent pas déclencher de tests

**Flux (compliqué):**
```
1. Push sur j12zdotcom/main
2. Webhook GitHub déclenche nix-config workflow
3. nix-config clone j12zdotcom
4. Build le site
5. Déploie
```

---

### Approche 3: Hybride (Avancé)

```
j12zdotcom/
├── .github/workflows/
│   ├── ci.yml              ← Tests, lint, build
│   └── deploy.yml          ← Appelle le script de nix-config
└── src/

nix-config/
├── scripts/
│   └── deploy-j12zdotcom.sh  ← Logique de déploiement
└── hosts/mimosa/webserver.nix
```

**Avantages:**
- ✅ CI dans j12zdotcom (tests, lint)
- ✅ Logique de déploiement centralisée dans nix-config
- ✅ Réutilisation du script pour déploiement manuel

**Inconvénients:**
- ⚠️ Plus complexe
- ⚠️ Dépendance entre les deux repos

---

## Migration recommandée

### Étape 1: Ajoute le workflow dans j12zdotcom

```bash
cd ~/projects/j12zdotcom  # Ou où tu as cloné j12zdotcom

# Copie le workflow
mkdir -p .github/workflows
cp ~/nix-config/docs/j12zdotcom-deploy-workflow.yml .github/workflows/deploy.yml
```

### Étape 2: Configure les secrets dans j12zdotcom

Va sur https://github.com/JeremieAlcaraz/j12zdotcom/settings/secrets/actions

Ajoute 3 secrets:

**1. `MIMOSA_SSH_KEY`**
```bash
# Sur magnolia, génère une clé dédiée
ssh-keygen -t ed25519 -f ~/.ssh/mimosa-deploy -C "github-deploy"

# Autorise la clé sur mimosa
ssh-copy-id -i ~/.ssh/mimosa-deploy.pub jeremie@mimosa

# Copie la clé PRIVÉE dans le secret GitHub
cat ~/.ssh/mimosa-deploy
# Copie tout le contenu (y compris BEGIN/END) dans le secret
```

**2. `MIMOSA_HOST`**
```
jeremie@100.108.60.92
```
(Utilise l'IP Tailscale pour que ça fonctionne de partout)

**3. `SSH_KNOWN_HOSTS`**
```bash
# Sur magnolia
ssh-keyscan 100.108.60.92
# Copie la sortie dans le secret
```

### Étape 3: Test!

```bash
cd ~/projects/j12zdotcom

# Commit le workflow
git add .github/workflows/deploy.yml
git commit -m "Add automated deployment workflow"
git push

# GitHub Actions va se déclencher automatiquement! 🎉
```

Vérifie sur: https://github.com/JeremieAlcaraz/j12zdotcom/actions

### Étape 4: Nettoie nix-config (optionnel)

```bash
cd ~/nix-config

# Supprime le workflow de nix-config (plus nécessaire)
git rm .github/workflows/deploy-j12zdotcom.yml

# Garde le script manuel pour déploiements rapides
# scripts/deploy-j12zdotcom.sh ← Garde celui-ci
```

---

## Cas d'usage

### Déploiement automatique (recommandé)

```bash
cd ~/projects/j12zdotcom

# Travaille sur le site
vim src/pages/blog/new-post.md
pnpm dev  # Test local

# Commit et push
git add .
git commit -m "Add new blog post"
git push

# GitHub Actions déploie automatiquement! 🚀
# Check: https://github.com/JeremieAlcaraz/j12zdotcom/actions
```

### Déploiement manuel rapide

```bash
# Si besoin de déployer manuellement (sans attendre GitHub Actions)
cd ~/nix-config
./scripts/deploy-j12zdotcom.sh
```

### Rollback rapide

```bash
# Sur mimosa
ssh mimosa

# Liste les backups
ls -la /var/www/j12zdotcom.backup.*

# Restore
sudo rm -rf /var/www/j12zdotcom
sudo cp -r /var/www/j12zdotcom.backup.20250121-143022 /var/www/j12zdotcom
sudo systemctl reload caddy
```

---

## Comparaison résumée

| Critère | Workflow dans j12zdotcom | Workflow dans nix-config | Hybride |
|---------|-------------------------|--------------------------|---------|
| **Intuitivité** | ⭐⭐⭐⭐⭐ Très intuitif | ⭐⭐ Contre-intuitif | ⭐⭐⭐ Moyen |
| **Setup complexité** | ⭐⭐⭐⭐ Simple | ⭐⭐ Webhook nécessaire | ⭐⭐⭐ Moyen |
| **CI/CD standard** | ✅ Oui | ❌ Non | ✅ Oui |
| **Centralisation infra** | ❌ Non | ✅ Oui | ⭐ Partiel |
| **Tests PR** | ✅ Facile | ❌ Difficile | ✅ Facile |

**Recommandation: Workflow dans j12zdotcom** ⭐

---

## FAQ

### Q: Pourquoi le workflow était dans nix-config au départ?

J'ai pensé à "centraliser toute l'infrastructure" mais c'est contre-intuitif. Le pattern standard est: **code + workflow ensemble**.

### Q: Je peux garder les deux?

Oui! Tu peux avoir:
- Workflow dans j12zdotcom pour déploiement automatique
- Script dans nix-config pour déploiement manuel

### Q: Et si je change la config NixOS?

```bash
# Sur mimosa ou magnolia
cd /etc/nixos  # ou ~/nix-config
git pull
sudo nixos-rebuild switch --flake .#mimosa --impure
```

Le workflow ne gère QUE le site, pas la config NixOS.

### Q: Comment tester avant de déployer en prod?

Option 1: Déploiement manuel local
```bash
./scripts/deploy-j12zdotcom.sh --skip-nix
```

Option 2: Branch de staging
- Crée une branche `staging`
- Configure le workflow pour déployer `staging` vers un autre dossier
- Teste, puis merge dans `main`

### Q: Le script dans nix-config sert encore à quoi?

Utile pour:
- Déploiement manuel rapide
- Tester localement
- Déployer depuis mimosa directement
- Debug si GitHub Actions est down

---

## Conclusion

**✅ Recommandation finale:**

1. **Mets le workflow dans j12zdotcom** (fichier: `docs/j12zdotcom-deploy-workflow.yml`)
2. **Garde le script dans nix-config** pour déploiements manuels
3. **Supprime le workflow de nix-config** (plus nécessaire)

**Résultat:**
- Push sur j12zdotcom → site déployé automatiquement 🎉
- Script manuel disponible si besoin
- Architecture standard et intuitive
