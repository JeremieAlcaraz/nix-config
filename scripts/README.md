# Scripts de déploiement

Documentation pour les scripts de déploiement automatique du site j12zdotcom.

Voir le guide complet: [`../docs/MIMOSA_WEBSERVER_SETUP.md`](../docs/MIMOSA_WEBSERVER_SETUP.md)

## Quick start

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
