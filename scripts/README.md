# Scripts de déploiement

Documentation pour les scripts de déploiement et maintenance de l'infrastructure.

Voir le guide complet: [`../docs/MIMOSA_WEBSERVER_SETUP.md`](../docs/MIMOSA_WEBSERVER_SETUP.md)

## Quick start

### Rebuild toutes les configurations (sur magnolia)

```bash
# Rebuild tout et met à jour j12z-site
./scripts/rebuild-all.sh

# Rebuild tout sans mettre à jour j12z-site
./scripts/rebuild-all.sh --skip-site

# Aide
./scripts/rebuild-all.sh --help
```

Ce script construit toutes les configurations (mimosa, whitelily, minimal) et les rend disponibles via le cache binaire de magnolia. Les déploiements ultérieurs seront beaucoup plus rapides !

### Déployer le site j12zdotcom

```bash
# Déployer depuis n'importe où
./scripts/deploy-j12zdotcom.sh

# Ou depuis mimosa directement
./scripts/deploy-j12zdotcom.sh --local

# Aide
./scripts/deploy-j12zdotcom.sh --help
```

## GitHub Actions

Le workflow automatique est dans `.github/workflows/deploy-j12zdotcom.yml`.

**Configuration requise** (GitHub Secrets):
- `MIMOSA_SSH_KEY`: Clé SSH privée
- `MIMOSA_HOST`: Host SSH (ex: `jeremie@100.108.60.92`)
- `SSH_KNOWN_HOSTS`: Fingerprint SSH de mimosa

**Déclenchement**:
- Manuel: Actions → Deploy j12zdotcom → Run workflow
- Auto: Configure webhook depuis j12zdotcom repo

Voir [`../docs/MIMOSA_WEBSERVER_SETUP.md`](../docs/MIMOSA_WEBSERVER_SETUP.md) pour plus de détails.
