# Design : Titres WezTerm intelligents

Date : 2026-02-24
Status : Approuvé

## Objectif

Renommer automatiquement les tabs WezTerm avec des noms intelligents basés sur le contexte :

| Contexte | Titre affiché |
|---|---|
| git branch `main` ou `master` | `nom-repo/main` |
| git branch `feat/toto` | `feat/toto` |
| dossier non-git | `nom-du-dossier` |
| titre personnalisé (LEADER + r) | le titre tapé |
| entrée vide lors du rename | reset vers titre automatique |

## Approche choisie : Shell user vars (OSC 1337)

Le shell (zsh) calcule le titre et l'envoie à WezTerm via une séquence d'échappement OSC 1337 `SetUserVar`. WezTerm lit la variable dans `pane.user_vars` lors du rendu des tabs.

## Architecture

```
[zsh precmd hook] ──git/pwd──→ [OSC 1337 SetUserVar] ──→ [WezTerm pane.user_vars]
                                                                    │
                                                         [tab_title() in tab_bar.lua]
                                                                    │
                                                    ┌───────────────┴───────────────┐
                                                    │ priorité:                     │
                                                    │ 1. tab.tab_title (manuel)     │
                                                    │ 2. user_vars.WEZTERM_TAB_TITLE│
                                                    │ 3. pane.title (fallback)      │
                                                    └───────────────────────────────┘
```

## Fichiers modifiés

| Fichier | Nature du changement |
|---|---|
| `modules/dotfiles/wezterm/config/tab_bar.lua` | Modifier `tab_title()` pour lire `user_vars.WEZTERM_TAB_TITLE` |
| `modules/dotfiles/zsh/modules/06-tools.marigold.zsh` | Ajouter hook `precmd` WezTerm |

## Détail des changements

### 1. Zsh : hook precmd

Ajouter à `06-tools.marigold.zsh` :

```zsh
# === WEZTERM - Titres de tabs intelligents ===
if [[ -n "${WEZTERM_PANE:-}" ]]; then
  __wezterm_update_tab_title() {
    local title git_branch git_root repo_name
    git_branch=$(git branch --show-current 2>/dev/null)
    if [[ -n "$git_branch" ]]; then
      if [[ "$git_branch" == "main" || "$git_branch" == "master" ]]; then
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        repo_name=$(basename "$git_root")
        title="${repo_name}/${git_branch}"
      else
        title="$git_branch"
      fi
    else
      title="${PWD##*/}"
    fi
    printf "\033]1337;SetUserVar=WEZTERM_TAB_TITLE=%s\007" \
      "$(printf '%s' "$title" | base64 | tr -d '\n')"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __wezterm_update_tab_title
fi
```

### 2. WezTerm : tab_title() modifiée

```lua
local function tab_title(tab)
  -- Priorité 1 : titre manuel (entrée vide = reset)
  local title = tab.tab_title
  if title and title ~= "" then
    if tab.active_pane and tab.active_pane.is_zoomed then
      title = title .. " "
    end
    return title
  end

  -- Priorité 2 : titre intelligent depuis zsh
  local user_vars = tab.active_pane and tab.active_pane.user_vars
  local smart = user_vars and user_vars.WEZTERM_TAB_TITLE
  if smart and smart ~= "" then
    if tab.active_pane and tab.active_pane.is_zoomed then
      smart = smart .. " "
    end
    return smart
  end

  -- Priorité 3 : fallback processus
  title = tab.active_pane.title
  if not title or title == "" then title = "shell" end
  if tab.active_pane and tab.active_pane.is_zoomed then
    title = title .. " "
  end
  return title
end
```

## Contraintes respectées

- Séparateurs powerline et couleurs Catppuccin Frappe : inchangés
- Config Nix : aucun fichier `.nix` à modifier (déploiement symlink)
- Raccourci LEADER + r : inchangé, fonctionne déjà pour le reset via entrée vide
