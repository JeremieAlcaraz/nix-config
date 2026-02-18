# Marigold Zsh - fzf completion et cache smart

## Objectif

Fournir une completion fuzzy rapide pour `nvim` (et alias `v`) avec:

- `Tab` standard conserve le comportement `fzf-tab`.
- `v **<TAB>` et `nvim **<TAB>` utilisent la completion fzf native.
- Les candidats sont issus d'une source intelligente avec cache memoire TTL.

## Comportement clavier

- `Tab` par defaut: widget `smart-tab-for-nvim-fzf`.
- Hors cas `nvim/v` + trigger `**`: fallback vers `fzf-tab-complete`.
- Cas `nvim/v` + suffixe `**`: route vers `fzf-completion`.

## Source des candidats

Pour `nvim` / `v`, la completion utilise:

1. `git ls-files` + `git ls-files --others --exclude-standard` si le dossier est dans un repo Git.
2. `fd` en fallback hors repo.

Fonctions impliquees:

- `_v_candidates_source`
- `_v_candidates_cached`
- `_fzf_complete_nvim`
- `_fzf_complete_v`

## Cache et tuning

Variables d'environnement:

- `ZSH_V_FZF_CACHE_TTL` (defaut: `3` secondes)
- `ZSH_V_FZF_CACHE_DEBUG` (`0` ou `1`)

Fonctions utilitaires:

- `_v_candidates_cache_stats`
- `_v_candidates_cache_invalidate --all`
- `_v_candidates_cache_invalidate <path>`

Exemple session:

```zsh
export ZSH_V_FZF_CACHE_TTL=10
export ZSH_V_FZF_CACHE_DEBUG=1
_v_candidates_cache_stats
_v_candidates_cache_invalidate --all
```

## Validation rapide

```bash
bash modules/dotfiles/zsh/scripts/check-zsh-completion.sh --mode both
bash modules/dotfiles/zsh/scripts/bench-zsh-completion.sh --runs 5 --mode both --target-dir .
```

Checks interactifs utiles:

```zsh
bindkey -M emacs '^I'
whence -w _smart_tab_for_nvim_fzf
whence -w _fzf_complete_nvim
```

## Activation sur Marigold

```bash
darwin-rebuild switch --flake .#marigold
exec zsh
```

## Notes

- Les scripts `check-zsh-completion.sh` et `bench-zsh-completion.sh` supportent un mode `sandbox` temporaire pour valider le code du repo sans rebuild immediat.
- Les mesures peuvent varier selon la charge machine, d'ou l'usage de plusieurs runs.
