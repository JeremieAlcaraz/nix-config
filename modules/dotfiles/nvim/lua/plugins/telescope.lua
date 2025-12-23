-- ~/.config/nvim/lua/plugins/telescope.lua
-- Point d'entrée principal pour Telescope (refactorisé)

local setup = require("telescope.setup")
local live_grep = require("telescope.pickers.live_grep")
local grep_in_folder = require("telescope.pickers.grep_in_folder")
local todoux = require("telescope.pickers.todoux")
local todoux_kitty = require("telescope.pickers.todoux_kitty")

return {
  "nvim-telescope/telescope.nvim",
  event = setup.get_event(),
  dependencies = setup.get_dependencies(),

  -- ─── MAPPINGS ────────────────────────────────────────────────────────────
  keys = {
    live_grep.get_keymap(), -- <leader>tg pour live_grep
    grep_in_folder.get_keymap(), -- <leader>tf pour Folder → live_grep
    todoux.get_keymap(), -- <leader>ti pour Todoux image picker (chafa)
    todoux_kitty.get_keymap(), -- <leader>tp pour Todoux image picker (Kitty/image.nvim)
  },

  -- ─── CONFIGURATION ───────────────────────────────────────────────────────
  opts = function(_, opts)
    return setup.setup(opts)
  end,
}
