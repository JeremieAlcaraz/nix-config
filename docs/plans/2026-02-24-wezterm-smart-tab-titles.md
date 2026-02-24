# WezTerm Smart Tab Titles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Renommer automatiquement les tabs WezTerm selon le contexte git (branche/repo) ou le dossier courant, tout en conservant la priorité aux renames manuels.

**Architecture:** Le shell zsh calcule le titre intelligent dans un hook `precmd` et l'envoie à WezTerm via OSC 1337 `SetUserVar`. WezTerm lit `pane.user_vars.WEZTERM_TAB_TITLE` dans `tab_title()` comme priorité 2 (après titre manuel, avant fallback processus).

**Tech Stack:** Lua (WezTerm config), Zsh (hook precmd), OSC 1337 escape sequences

---

### Task 1 : Modifier `tab_title()` dans tab_bar.lua

**Files:**
- Modify: `modules/dotfiles/wezterm/config/tab_bar.lua:35-47`

La fonction `tab_title()` actuelle fait déjà :
1. Lire `tab.tab_title` (titre manuel)
2. Fallback sur `tab.active_pane.title` (processus)
3. Fallback sur `"shell"`

On doit insérer entre 1 et 2 : lire `pane.user_vars.WEZTERM_TAB_TITLE`.

**Step 1 : Remplacer la fonction `tab_title()` dans tab_bar.lua**

Remplacer les lignes 35-47 (la fonction `tab_title` entière) par :

```lua
local function tab_title(tab)
	-- Priorité 1 : titre manuel (LEADER + r)
	-- Entrée vide lors du rename = reset → retour automatique
	local title = tab.tab_title
	if title and title ~= "" then
		if tab.active_pane and tab.active_pane.is_zoomed then
			title = title .. " "
		end
		return title
	end

	-- Priorité 2 : titre intelligent depuis zsh (branch git / dossier)
	local user_vars = tab.active_pane and tab.active_pane.user_vars
	local smart = user_vars and user_vars.WEZTERM_TAB_TITLE
	if smart and smart ~= "" then
		if tab.active_pane and tab.active_pane.is_zoomed then
			smart = smart .. " "
		end
		return smart
	end

	-- Priorité 3 : fallback sur le titre du processus
	title = tab.active_pane.title
	if not title or title == "" then
		title = "shell"
	end
	if tab.active_pane and tab.active_pane.is_zoomed then
		title = title .. " "
	end
	return title
end
```

**Step 2 : Vérifier que le fichier est bien formé**

Ouvrir WezTerm → le fichier est rechargé automatiquement (hot reload).
Si WezTerm affiche une erreur → vérifier la syntaxe Lua (accolades, `end` manquant, etc.).

Expected : les onglets s'affichent toujours normalement (titre processus pour l'instant, car le hook zsh n'est pas encore ajouté).

**Step 3 : Commit**

```bash
git add modules/dotfiles/wezterm/config/tab_bar.lua
git commit -m "feat(wezterm): read WEZTERM_TAB_TITLE user var in tab_title()"
```

---

### Task 2 : Ajouter le hook zsh dans 06-tools.marigold.zsh

**Files:**
- Modify: `modules/dotfiles/zsh/modules/06-tools.marigold.zsh` (fin du fichier)

**Step 1 : Ajouter le bloc WezTerm à la fin du fichier**

```zsh
# === WEZTERM - Titres de tabs intelligents ===
# Envoie le contexte git/dossier à WezTerm via OSC 1337 SetUserVar.
# Déclenché après chaque commande (precmd hook).
# Guard : ne s'active que dans WezTerm ($WEZTERM_PANE est défini par WezTerm).
if [[ -n "${WEZTERM_PANE:-}" ]]; then
  __wezterm_update_tab_title() {
    local title git_branch git_root repo_name
    git_branch=$(git branch --show-current 2>/dev/null)

    if [[ -n "$git_branch" ]]; then
      if [[ "$git_branch" == "main" || "$git_branch" == "master" ]]; then
        # Pour main/master : affiche nom-repo/main
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        repo_name=$(basename "$git_root")
        title="${repo_name}/${git_branch}"
      else
        # Autres branches : affiche la branche directement (ex: feat/toto)
        title="$git_branch"
      fi
    else
      # Hors dépôt git : affiche le nom du dossier courant
      title="${PWD##*/}"
    fi

    # Envoie la variable à WezTerm via OSC 1337
    # base64 requis par le protocole ; tr -d '\n' supprime les sauts de ligne
    printf "\033]1337;SetUserVar=WEZTERM_TAB_TITLE=%s\007" \
      "$(printf '%s' "$title" | base64 | tr -d '\n')"
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __wezterm_update_tab_title
fi
```

**Step 2 : Tester dans le shell courant**

Dans un terminal WezTerm, sourcer le fichier modifié :

```bash
source ~/.config/zsh/modules/06-tools.zsh
```

Note : `~/.config/zsh/modules/06-tools.zsh` est un symlink vers le fichier dans le repo (via Nix).

Vérifier en changeant de dossier :

```bash
cd ~/Development/_programmation/_production/_services/nix-config
# → doit afficher "nix-config/main" dans le tab (après une commande ou Enter)

cd /tmp
# → doit afficher "tmp"

cd ~/Development/_programmation/_production/_services/nix-config
git checkout -b feat/test-wezterm 2>/dev/null || git checkout feat/test-wezterm
# → doit afficher "feat/test-wezterm"
git checkout main
# → doit afficher "nix-config/main"
git branch -d feat/test-wezterm 2>/dev/null || true
```

Expected : les tabs se renomment automatiquement après chaque commande.

**Step 3 : Tester le titre manuel + reset**

```
LEADER + r → taper "mon-titre" → Enter
# → tab affiche "mon-titre"

LEADER + r → Enter (vide)
# → tab revient au titre automatique (branch/dossier)
```

**Step 4 : Commit**

```bash
git add modules/dotfiles/zsh/modules/06-tools.marigold.zsh
git commit -m "feat(zsh): add WezTerm precmd hook for smart tab titles"
```

---

### Task 3 : Vérification finale et nettoyage

**Step 1 : Vérifier le hot reload WezTerm**

Les fichiers WezTerm sont rechargés automatiquement. Vérifier que le tab_bar.lua ne génère pas d'erreurs en consultant le debug overlay :
`CMD+ALT+CTRL+SHIFT + D`

Expected : pas d'erreur Lua dans le log.

**Step 2 : Tester tous les cas du tableau**

| Contexte à tester | Titre attendu |
|---|---|
| `cd nix-config` (branche main) | `nix-config/main` |
| `git checkout feat/toto` | `feat/toto` |
| `cd /tmp` | `tmp` |
| `LEADER + r` → "mon-titre" | `mon-titre` |
| `LEADER + r` → Enter vide | retour auto |

**Step 3 : Vérifier que le styling est intact**

Les séparateurs powerline et couleurs Catppuccin Frappe doivent être inchangés.

**Step 4 : Commit du doc de design (si pas encore commité)**

```bash
git add docs/plans/
git commit -m "docs: add WezTerm smart tab titles design and implementation plan"
```

---

## Notes importantes

- **Pas de rebuild Nix nécessaire** : WezTerm est déployé via symlink (`xdg.configFile."wezterm".source`), les changements lua sont actifs immédiatement (hot reload WezTerm).
- **Pour le zsh** : `~/.config/zsh/modules/06-tools.zsh` est un symlink Nix vers le fichier du repo. Sourcer le fichier suffit pour tester sans rebuild.
- **Si le hot reload ne se déclenche pas** : `CTRL+SHIFT+R` dans WezTerm force le rechargement de la config.
