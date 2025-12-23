-- ~/.config/nvim/lua/plugins/which-key-custom.lua
-- Créez ce nouveau fichier pour configurer l'icône
return {
  "folke/which-key.nvim",
  opts = {
    spec = {
      mode = { "n", "v" },
      { "<leader>a", group = "ai", icon = { icon = "󱚡", color = "yellow" } },
      { "<leader>t", group = "telescope", icon = { icon = "󰭎", color = "purple" } },
    },
  },
}
