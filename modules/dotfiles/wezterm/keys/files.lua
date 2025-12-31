-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/files.lua - MISE À JOUR avec chemins raccourcis
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require('wezterm')
local act = wezterm.action
local tab_limit = require("config.tab_limit")
local utils = require('utils')

local M = {}

--- Génère le script bash pour la recherche de fichiers récents
--- @return string Le script bash complet
local function generate_recent_files_script()
  local constants = utils.constants
  local helpers = utils.helpers
  
  -- Construction des patterns d'extensions
  local find_pattern = helpers.build_find_pattern(constants.ALL_EXTENSIONS)
  local grep_pattern = helpers.build_grep_pattern(constants.ALL_EXTENSIONS)
  
  return string.format([[
# Configuration
nvim_data_dir="%s"
recent_files=""
method_used=""

echo "%s"

# ──────────────────────────────────────────────────────────────
# Méthode 1: Base de données smart_open (le plus précis)
# ──────────────────────────────────────────────────────────────
if [ -f "$nvim_data_dir/smart_open.sqlite3" ]; then
  echo "%s Méthode 1: Consultation smart_open.sqlite3..."
  recent_files=$(sqlite3 "$nvim_data_dir/smart_open.sqlite3" \
    "SELECT path FROM files WHERE path LIKE '%%.%%' ORDER BY last_open DESC LIMIT 30;" 2>/dev/null | \
    while read file; do [ -f "$file" ] && echo "$file"; done)
  
  if [ -n "$recent_files" ]; then
    method_used="smart_open.sqlite3"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 2: Historique Telescope
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ] && [ -f "$nvim_data_dir/telescope_history" ]; then
  echo "%s Méthode 2: Lecture telescope_history..."
  recent_files=$(cat "$nvim_data_dir/telescope_history" | \
    while read file; do [ -f "$file" ] && echo "$file"; done | head -20)
  
  if [ -n "$recent_files" ]; then
    method_used="telescope_history"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 3: Fichier shada (si disponible)
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ]; then
  shada_file="$nvim_data_dir/shada/main.shada"
  if [ -f "$shada_file" ]; then
    echo "%s Méthode 3: Extraction depuis shada..."
    recent_files=$(strings "$shada_file" | \
      grep -E '^/' | \
      grep -E '%s' | \
      head -30 | \
      while read file; do [ -f "$file" ] && echo "$file"; done)
    
    if [ -n "$recent_files" ]; then
      method_used="shada/main.shada"
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 4: v:oldfiles direct de Neovim
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ] && command -v nvim >/dev/null 2>&1; then
  echo "%s Méthode 4: Consultation v:oldfiles Neovim..."
  recent_files=$(nvim --headless \
    -c 'for file in v:oldfiles | if filereadable(file) | echo file | endif | endfor' \
    -c 'qa' 2>/dev/null | head -20)
  
  if [ -n "$recent_files" ]; then
    method_used="v:oldfiles"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 5: Fichiers récemment modifiés (répertoire courant)
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ]; then
  echo "%s Méthode 5: Fichiers récents du répertoire courant..."
  recent_files=$(find . -type f %s -exec ls -t {} + 2>/dev/null | head -25)
  
  if [ -n "$recent_files" ]; then
    method_used="fichiers récents locaux"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 6: Recherche récursive simple
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ]; then
  echo "%s Méthode 6: Recherche récursive simple..."
  recent_files=$(find . -type f %s 2>/dev/null | head -20)
  
  if [ -n "$recent_files" ]; then
    method_used="recherche récursive"
  fi
fi

# ──────────────────────────────────────────────────────────────
# Méthode 7: Dossiers de développement standards (fallback ultime)
# ──────────────────────────────────────────────────────────────
if [ -z "$recent_files" ]; then
  echo "%s Méthode 7: Recherche dans les dossiers de dev..."
  for dir in ~/Projects ~/Code ~/Developer ~/Documents ~/.config; do
    if [ -d "$dir" ]; then
      recent_files=$(find "$dir" -type f \( \
        -name "*.lua" -o -name "*.py" -o -name "*.js" -o -name "*.md" \
        \) -exec ls -t {} + 2>/dev/null | head -15)
      
      if [ -n "$recent_files" ]; then
        method_used="dossier $dir"
        break
      fi
    fi
  done
fi

# ──────────────────────────────────────────────────────────────
# Fonction de raccourcissement des chemins (bash)
# ──────────────────────────────────────────────────────────────
format_path() {
  local path="$1"
  # Remplacer le home par ~
  path="${path/#$HOME/~}"
  
  # Compter les niveaux de profondeur
  path_parts=$(echo "$path" | tr '/' ' ' | wc -w)
  if [ "$path_parts" -gt 4 ]; then
    # Extraire les 2-3 dernières parties du chemin
    basename_file=$(basename "$path")
    dirname_path=$(dirname "$path")
    parent_dir=$(basename "$dirname_path")
    grandparent_dir=$(basename "$(dirname "$dirname_path")")
    
    if [ "$grandparent_dir" != "." ] && [ "$grandparent_dir" != "/" ] && [ "$grandparent_dir" != "~" ]; then
      echo ".../$grandparent_dir/$parent_dir/$basename_file"
    else
      echo ".../$parent_dir/$basename_file"
    fi
  else
    echo "$path"
  fi
}

# ──────────────────────────────────────────────────────────────
# Sélection avec fzf et ouverture (avec chemins raccourcis)
# ──────────────────────────────────────────────────────────────
if [ -n "$recent_files" ]; then
  echo "%s $method_used"
  echo ""
  
  # Créer les chemins raccourcis pour l'affichage
  display_files=""
  original_files=""
  while IFS= read -r file; do
    if [ -n "$file" ]; then
      short_path=$(format_path "$file")
      display_files="$display_files$short_path"$'\n'
      original_files="$original_files$file"$'\n'
    fi
  done <<< "$recent_files"
  
  # Utiliser fzf avec les chemins raccourcis
  selected_short=$(echo -n "$display_files" | fzf \
    --preview 'head -20 {}' \
    --height=50%% \
    --reverse \
    --header="📁 Fichiers récents ($method_used)")
  
  if [ -n "$selected_short" ]; then
    # Retrouver le chemin complet original
    line_num=$(echo -n "$display_files" | grep -n "^$selected_short$" | cut -d: -f1)
    selected_full=$(echo -n "$original_files" | sed -n "${line_num}p")
    
    echo "%s $selected_full"
    nvim "$selected_full"
  fi
else
  echo "%s"
  echo "Vérifiez que Neovim a été utilisé récemment ou qu'il y a des fichiers de code dans les dossiers courants."
  read -p "Appuyez sur Entrée pour fermer..."
fi
]],
    constants.PATHS.NVIM_DATA,
    constants.MESSAGES.SEARCH_START,
    constants.EMOJIS.DATABASE,
    constants.EMOJIS.TELESCOPE,
    constants.EMOJIS.MEMORY,
    grep_pattern,
    constants.EMOJIS.LIGHTNING,
    constants.EMOJIS.FOLDER,
    find_pattern,
    constants.EMOJIS.SEARCH,
    find_pattern,
    constants.EMOJIS.HOME,
    constants.MESSAGES.SUCCESS,
    constants.MESSAGES.OPENING,
    constants.MESSAGES.NO_FILES
  )
end

function M.get_keys()
  return {
    -- ═══════════════════════════════════════════════════════════════════
    -- Raccourci fichiers récents avec fzf + neovim (chemins raccourcis)
    -- ═══════════════════════════════════════════════════════════════════
    { 
      key = "r", 
      mods = "CMD|OPT|CTRL|SHIFT", 
      action = tab_limit.guard_action(act.SpawnCommandInNewTab {
        args = { "/usr/bin/env", "bash", "-lc", generate_recent_files_script() },
      }),
    },
  }
end

return M
