-- Configuration MCPHub pour lazy.nvim
return {
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  build = "npm install -g mcp-hub@latest",
  config = function()
    require("mcphub").setup()
  end,
  -- Optionnel : charger seulement quand nécessaire
  cmd = { "MCPHub" },
  keys = {
    { "<leader>am", "<cmd>MCPHub<cr>", desc = "MCPHub" },
  },
}
