-- lua/plugins/oil.lua
return {
  "stevearc/oil.nvim",
  opts = {},
  -- Optional dependencies
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    {
      "-",
      "<CMD>Oil<CR>",
      desc = "Open parent directory with oil.nvim",
    },
  },
}