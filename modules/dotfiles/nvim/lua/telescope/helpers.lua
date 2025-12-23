-- ~/.config/nvim/lua/telescope/helpers.lua
-- Utilitaires partagés pour Telescope

local M = {}

-- ─── DÉPENDANCES ─────────────────────────────────────────────────────────────
local Path = require("plenary.path")
local entry_display = require("telescope.pickers.entry_display")
local make_entry = require("telescope.make_entry")

-- ─── VÉRIFICATIONS ──────────────────────────────────────────────────────────
-- Vérifie que ripgrep est disponible
function M.check_ripgrep()
  if vim.fn.executable("rg") == 0 then
    vim.notify("ripgrep (rg) introuvable sur le PATH", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- ─── AFFICHAGE ──────────────────────────────────────────────────────────────
-- Crée un displayer pour l'affichage en colonnes
function M.create_displayer(opts)
  opts = opts or {}

  return entry_display.create({
    separator = opts.separator or " ",
    items = {
      { width = opts.path_width or 60 }, -- chemin (troncature si besoin)
      { remaining = true, right_justify = true }, -- nom fichier aligné à droite
    },
  })
end

-- ─── MANIPULATION DE CHEMINS ────────────────────────────────────────────────
-- Raccourcit le chemin avec ellipses (…/dir/dir/file)
function M.shorten_path(filename, keep)
  keep = keep or 3

  local rel = Path:new(filename):make_relative(vim.fn.getcwd())
  local segs = {}

  for s in rel:gmatch("[^/]+") do
    table.insert(segs, s)
  end

  local tail = table.remove(segs) -- nom du fichier

  while #segs > keep do
    table.remove(segs, 1)
    segs[1] = "…"
  end

  return table.concat(segs, "/") .. "/" .. tail
end

-- ─── ENTRY MAKERS ───────────────────────────────────────────────────────────
-- Entry maker personnalisé pour live_grep avec chemin abrégé
function M.make_entry_live_grep(opts)
  opts = opts or {}
  local displayer = M.create_displayer(opts.display or {})
  local mt = make_entry.gen_from_vimgrep(opts)

  return function(line)
    local entry = mt(line)
    entry.display = function(e)
      local short = M.shorten_path(e.filename, opts.keep_segments or 3)
      local file = e.filename:match("[^/]+$") or e.filename
      return displayer({ short, file })
    end
    return entry
  end
end

-- ─── CONFIGURATIONS ─────────────────────────────────────────────────────────
-- Arguments vimgrep avec fichiers cachés et exclusion .git
function M.get_vimgrep_arguments()
  local values = require("telescope.config").values
  local vimgrep = { unpack(values.vimgrep_arguments) }

  vim.list_extend(vimgrep, {
    "--hidden", -- inclut fichiers/dossiers cachés
    "--glob",
    "!**/.git/*", -- exclut tout .git/
  })

  return vimgrep
end

-- Arguments additionnels pour live_grep_args
function M.get_live_grep_additional_args()
  return {
    "--hidden",
    "--glob",
    "!**/.git/*",
  }
end

-- ─── STYLES ─────────────────────────────────────────────────────────────────
-- Applique la surbrillance violet fluo pour les matches
function M.setup_highlight()
  vim.cmd([[highlight TelescopeMatching guifg=#FF00FF gui=bold]])
end

return M
