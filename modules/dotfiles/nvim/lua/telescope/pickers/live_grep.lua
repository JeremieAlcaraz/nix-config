-- ~/.config/nvim/lua/telescope/pickers/live_grep.lua
-- Picker Live Grep avec preview et chemin abrégé

local M = {}
local helpers = require("telescope.helpers")

-- ─── CONFIGURATION DU PICKER ────────────────────────────────────────────────
local function get_live_grep_config()
  return {
    cwd = vim.fn.getcwd(), -- répertoire courant global
    prompt_title = "Live Grep (cwd)",
    entry_maker = helpers.make_entry_live_grep(), -- colonne unique sans mini-preview
    layout_config = {
      preview_width = 0.6, -- ↑ augmente la preview, réduit la liste
    },
    -- on ne met PAS previewer = false pour conserver la preview
  }
end

-- ─── FONCTION PRINCIPALE ────────────────────────────────────────────────────
function M.live_grep()
  -- 1. Vérifier que ripgrep est disponible
  if not helpers.check_ripgrep() then
    return
  end

  -- 2. Lancer live_grep_args avec notre config
  require("telescope").extensions.live_grep_args.live_grep_args(get_live_grep_config())
end

-- ─── CONFIGURATION DU MAPPING ───────────────────────────────────────────────
function M.get_keymap()
  return {
    "<leader>tg",
    M.live_grep,
    desc = "Live grep (cwd, preview, cachés, sans .git, chemin abrégé)",
  }
end

return M
