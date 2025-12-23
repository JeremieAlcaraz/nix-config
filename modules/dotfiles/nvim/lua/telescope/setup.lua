-- ~/.config/nvim/lua/telescope/setup.lua
-- Configuration générale de Telescope

local M = {}
local helpers = require("telescope.helpers")

-- ─── CONFIGURATION PRINCIPALE ───────────────────────────────────────────────
function M.get_telescope_config()
  return {
    defaults = {
      vimgrep_arguments = helpers.get_vimgrep_arguments(),
      preview = {
        filesize_limit = 100000, -- pas d'aperçu > 100 kio
      },
    },
    extensions = {
      live_grep_args = {
        auto_quoting = true,
        additional_args = helpers.get_live_grep_additional_args,
      },
    },
  }
end

-- ─── SETUP COMPLET ──────────────────────────────────────────────────────────
function M.setup(user_opts)
  user_opts = user_opts or {}

  -- 1. Récupérer la config par défaut
  local config = M.get_telescope_config()

  -- 2. Merger avec les options utilisateur
  config = vim.tbl_deep_extend("force", config, user_opts)

  -- 3. Appliquer la surbrillance personnalisée
  helpers.setup_highlight()

  return config
end

-- ─── DÉPENDANCES REQUISES ───────────────────────────────────────────────────
function M.get_dependencies()
  return {
    "nvim-telescope/telescope-live-grep-args.nvim",
  }
end

-- ─── ÉVÉNEMENT DE CHARGEMENT ────────────────────────────────────────────────
function M.get_event()
  return "BufReadPost"
end

return M
