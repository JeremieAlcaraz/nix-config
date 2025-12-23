-- lua/utils/files.lua
local M = {}

-- Formate un chemin de fichier de manière compacte
-- ~/dossier/sous-dossier/fichier.lua → ~/dossier/…/fichier.lua
function M.format_compact_path(filepath, max_width)
  local fname = vim.fn.fnamemodify(filepath, ":~")
  local file = vim.fn.fnamemodify(fname, ":t") -- Nom du fichier
  local full_dir = vim.fn.fnamemodify(fname, ":h") -- Dossier complet

  -- Si on est dans HOME
  if full_dir:match("^~/") then
    local parts = vim.split(full_dir:sub(3), "/") -- Retire ~/ et split
    if #parts > 1 then
      -- Premier dossier + ... + nom du fichier
      local display = "~/" .. parts[1] .. "/…/" .. file

      -- Optionnel: respecter max_width si fourni
      if max_width and #display > max_width then
        return "~/" .. parts[1] .. "/…/" .. file:sub(-(max_width - #("~/" .. parts[1] .. "/…/")))
      end

      return display
    else
      -- Juste ~/dossier/fichier
      return fname
    end
  else
    -- Comportement par défaut pour les autres chemins
    return fname
  end
end

-- Version pour dashboard snacks (retourne le format attendu)
function M.format_file_for_dashboard(item, ctx)
  local display = M.format_compact_path(item.file, ctx.width)
  return { { display, hl = "file" } }
end

-- Version pour telescope (retourne juste la string)
function M.format_file_for_telescope(filepath)
  return M.format_compact_path(filepath)
end

return M
