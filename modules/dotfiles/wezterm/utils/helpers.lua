-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/utils/helpers.lua - Fonctions utilitaires
-- ══════════════════════════════════════════════════════════════════════

local constants = require('utils.constants')

local M = {}

-- ═══════════════════════════════════════════════════════════════════
-- Helpers pour les chemins
-- ═══════════════════════════════════════════════════════════════════

--- Remplace le chemin home par ~
--- @param path string Le chemin à raccourcir
--- @return string Le chemin raccourci
function M.shorten_path(path)
  if not path then return "" end
  return path:gsub("^" .. constants.PATHS.HOME, "~")
end

--- Raccourcit un chemin en gardant seulement les 2-3 derniers niveaux
--- @param path string Le chemin à raccourcir
--- @return string Le chemin raccourci avec ...
function M.truncate_path(path)
  if not path then return "" end
  
  local shortened = M.shorten_path(path)
  local parts = {}
  for part in shortened:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  
  if #parts > 4 then
    local basename = parts[#parts]
    local parent = parts[#parts - 1]
    local grandparent = parts[#parts - 2]
    return ".../" .. grandparent .. "/" .. parent .. "/" .. basename
  end
  
  return shortened
end

--- Vérifie si un fichier existe
--- @param filepath string Le chemin du fichier
--- @return boolean true si le fichier existe
function M.file_exists(filepath)
  if not filepath then return false end
  local file = io.open(filepath, "r")
  if file then
    file:close()
    return true
  end
  return false
end

-- ═══════════════════════════════════════════════════════════════════
-- Helpers pour les extensions de fichiers
-- ═══════════════════════════════════════════════════════════════════

--- Génère un pattern find pour les extensions données
--- @param extensions table Liste des extensions
--- @return string Pattern pour la commande find
function M.build_find_pattern(extensions)
  local patterns = {}
  for _, ext in ipairs(extensions) do
    table.insert(patterns, "-name '*." .. ext .. "'")
  end
  return "\\( " .. table.concat(patterns, " -o ") .. " \\)"
end

--- Génère un pattern grep pour les extensions données
--- @param extensions table Liste des extensions
--- @return string Pattern pour grep
function M.build_grep_pattern(extensions)
  local patterns = {}
  for _, ext in ipairs(extensions) do
    table.insert(patterns, "\\." .. ext .. "$")
  end
  return "\\(" .. table.concat(patterns, "\\|") .. "\\)"
end

-- ═══════════════════════════════════════════════════════════════════
-- Helpers pour les tableaux
-- ═══════════════════════════════════════════════════════════════════

--- Étend un tableau avec les éléments d'un autre
--- @param target table Le tableau cible
--- @param source table Le tableau source
function M.table_extend(target, source)
  for _, item in ipairs(source) do
    table.insert(target, item)
  end
end

--- Filtre un tableau avec une fonction de prédicat
--- @param tbl table Le tableau à filtrer
--- @param predicate function La fonction de test
--- @return table Le tableau filtré
function M.table_filter(tbl, predicate)
  local result = {}
  for _, item in ipairs(tbl) do
    if predicate(item) then
      table.insert(result, item)
    end
  end
  return result
end

-- ═══════════════════════════════════════════════════════════════════
-- Helpers pour les commandes shell
-- ═══════════════════════════════════════════════════════════════════

--- Échappe une chaîne pour une utilisation sécurisée dans le shell
--- @param str string La chaîne à échapper
--- @return string La chaîne échappée
function M.shell_escape(str)
  if not str then return "''" end
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

--- Formate un message avec des paramètres
--- @param template string Le template avec %s
--- @param ... any Les paramètres à injecter
--- @return string Le message formaté
function M.format_message(template, ...)
  return string.format(template, ...)
end

return M