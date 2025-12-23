return {
  -- Optionnel pour les icônes
  { "nvim-tree/nvim-web-devicons" },

  -- Optionnel pour la commande 'fzf'
  {
    "junegunn/fzf",
  },

  -- Plugin principal fzfx.nvim
  {
    "linrongbin16/fzfx.nvim",
    version = "v8.*", -- Optionnel pour éviter les changements majeurs
    dependencies = { "nvim-tree/nvim-web-devicons", "junegunn/fzf" },
    config = function()
      require("fzfx").setup()
    end,
  },
}

