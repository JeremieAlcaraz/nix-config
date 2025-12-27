# Configuration Git (XDG-compliant)

Cette configuration Git est 100% conforme à la spec XDG et s'intègre parfaitement à ta config NixOS/Home Manager.

## Structure

```
~/.config/git/
├── config              # Configuration Git principale
├── ignore              # .gitignore global
└── templates/
    └── hooks/
        ├── pre-commit           # Vérifications avant commit
        ├── commit-msg           # Validation du message
        └── prepare-commit-msg   # Template de message
```

## Fonctionnalités

### Configuration de base (`config`)

- **User** : Nom et email configurés
- **Init** : Branche par défaut `main`, templates XDG
- **Core** : Neovim comme éditeur, meilleurs diffs
- **Push** : Auto-setup remote (plus besoin de `-u` au premier push)
- **Merge** : Conflict style `zdiff3` pour des résolutions plus faciles
- **Diff** : Algorithme `histogram` (plus rapide et lisible)
- **Aliases** : Shortcuts utiles (`co`, `br`, `ci`, `st`, `lg`, etc.)

### Gitignore global (`ignore`)

Contient les patterns à ignorer globalement (actuellement `.claude/settings.local.json`).

### Hooks Git

#### 🛡️ `pre-commit` - Vérifications avant commit

Bloque le commit si :
- Trailing whitespace détecté
- Markers de merge conflict présents (`<<<<<<<`, `>>>>>>>`, `=======`)
- Fichiers sensibles détectés (`.env`, `*.pem`, `*.key`, etc.)

**Non-bloquant** :
- Détection de `@FIXME` (commenté par défaut)

#### ✍️ `commit-msg` - Validation du message

**Bloquant** :
- Message vide

**Warnings (non-bloquant)** :
- Première ligne > 72 caractères
- Format non-conventionnel (suggestion de conventional commits)

Conventional commits format recommandé :
```
<type>(<scope>): <subject>

Types valides : feat, fix, docs, style, refactor, test, chore, perf, ci, build
```

Exemples :
```
feat(auth): add OAuth2 login support
fix(api): resolve race condition in user fetch
docs: update installation instructions
```

#### 📝 `prepare-commit-msg` - Template automatique

Auto-génère un template de message basé sur le nom de la branche :

- **Branche avec préfixe** (`feat/auth-login`) → `feat(auth-login): `
- **Branche sans préfixe** → `# Branch: ma-branche`
- **main/master** → Rien (pas de template)

Ne s'applique **pas** aux merges, squashes, ou commits avec message existant.

## Utilisation

### Application automatique

Les hooks sont **automatiquement copiés** dans chaque nouveau dépôt créé avec `git init` grâce à `init.templateDir`.

### Application manuelle dans un dépôt existant

```bash
# Copier les hooks dans un dépôt existant
cp -r ~/.config/git/templates/hooks/* .git/hooks/

# Ou utiliser Git (si tu veux que les hooks soient trackés)
mkdir -p .githooks
cp -r ~/.config/git/templates/hooks/* .githooks/
git config core.hooksPath .githooks
```

### Désactiver temporairement les hooks

```bash
# Skip pre-commit hook
git commit --no-verify

# ou
SKIP_HOOKS=1 git commit
```

## Personnalisation

### Rendre un hook bloquant

Par exemple, pour bloquer les commits avec `@FIXME`, dans `pre-commit` :

```bash
# Décommenter cette section :
if git diff --cached | grep -E "^\+.*@FIXME"; then
    echo -e "${RED}✗${NC} @FIXME marker detected!"
    exit 1
fi
```

### Ajouter un nouveau hook

1. Créer le fichier dans `modules/dotfiles/git/templates/hooks/`
2. Le rendre exécutable avec `chmod +x`
3. L'ajouter dans `home/marigold.nix` :

```nix
"git/templates/hooks/mon-hook" = {
  source = ../modules/dotfiles/git/templates/hooks/mon-hook;
  executable = true;
};
```

## Tips

### Voir les hooks actifs

```bash
ls -la .git/hooks/
```

### Debug un hook

```bash
# Ajouter au début du hook :
set -x  # Active le mode debug

# Ou run manuellement :
bash -x .git/hooks/pre-commit
```

### Aliases utiles déjà configurés

```bash
git lg           # Pretty log avec graph
git undo         # Annule le dernier commit (garde les changements)
git amend        # Amend sans éditer le message
git current      # Affiche la branche courante
git cleanup      # Supprime les branches mergées
```

## Ressources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
- [XDG Base Directory Spec](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
