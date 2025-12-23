-- Path: ~/.config/nvim/lua/plugins/lsp/init.lua
-- Role: Configuration principale des LSP (Language Server Protocol)
-- Description: Point d'entrée pour toute la configuration LSP, gère l'installation et la configuration des serveurs

return {
  -- Plugin principal pour la configuration LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" }, -- Chargement lazy au besoin
    dependencies = {
      -- Gestionnaire d'installation automatique des LSP
      {
        "mason-org/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
        build = ":MasonUpdate",
        opts = {
          ensure_installed = {
            -- LSP servers pour notre stack Astro/TypeScript
            "astro-language-server",
            "tailwindcss-language-server",
            -- Formatters
            "prettier",
            -- Linters
            "eslint_d",
          },
        },
      },
      -- Pont entre Mason et lspconfig
      {
        "mason-org/mason-lspconfig.nvim",
        opts = {
          -- Installation automatique des serveurs listés
          automatic_installation = true,
        },
      },
      -- Amélioration de l'UI LSP
      {
        "nvimdev/lspsaga.nvim",
        event = "LspAttach",
        opts = {
          -- Configuration UI améliorée
          border_style = "rounded",
          symbol_in_winbar = {
            enable = true,
            separator = " › ",
          },
          finder = {
            max_height = 0.5,
            keys = {
              jump_to = "p",
              expand_or_jump = "o",
              vsplit = "s",
              split = "i",
              quit = { "q", "<ESC>" },
            },
          },
        },
      },
    },
    config = function()
      -- Import des configurations spécifiques
      require("plugins.lsp.servers") -- Configuration des serveurs LSP
      require("plugins.lsp.keymaps") -- Raccourcis clavier LSP

      -- Configuration globale des diagnostics
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN] = "▲",
            [vim.diagnostic.severity.HINT] = "⚑",
            [vim.diagnostic.severity.INFO] = "»",
          },
        },
      })
    end,
  },
}
