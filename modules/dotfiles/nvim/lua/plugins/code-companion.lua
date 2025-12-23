-- ~/.config/nvim/lua/plugins/codecompanion.lua
return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "zbirenbaum/copilot.lua",
    "ravitemer/mcphub.nvim", -- ✅ AJOUTÉ : Déclare mcphub comme dépendance de CodeCompanion
    -- Cela signifie que mcphub sera installé ET chargé AVANT CodeCompanion
    -- Nécessaire pour que CodeCompanion puisse accéder aux fonctions de mcphub
  },
  keys = {
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<CR>", desc = "Chat" },
    { "<leader>ai", "<cmd>CodeCompanion<CR>", desc = "Inline assistant", mode = "v" }, -- Mode visuel seulement
    { "<leader>aa", "<cmd>CodeCompanionActions<CR>", desc = "Ace prompt" },
  },

  config = function()
    -- Récupération de la clé API via 1Password avec --reveal
    local api_key = vim.fn.system("op item get 'openai-codecompanion' --field credential --reveal"):gsub("%s+", "")

    require("codecompanion").setup({
      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = {
              api_key = api_key,
            },
            model = "gpt-4o-mini",
          })
        end,
        copilot = function()
          return require("codecompanion.adapters").extend("copilot", {})
        end,
      },
      strategies = {
        chat = { adapter = "copilot" },
        inline = { adapter = "openai" },
        agent = { adapter = "openai" },
      },
      extensions = { -- Configuration des extensions
        mcphub = {
          callback = "mcphub.extensions.codecompanion", -- Module d'intégration
          opts = {
            make_vars = true, -- Variables personnalisées (#mcphub_*)
            make_slash_commands = true, -- Commandes slash (/mcp_*)
            show_result_in_chat = true, -- Résultats dans le chat
          },
        },
      },
    })
  end,
}
