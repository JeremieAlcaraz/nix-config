return {
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTelescope", "TodoTrouble" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      highlight = {
        comments_only = false, -- Permet la détection dans tous les contextes
        multiline = true,
        pattern = [[.*<(KEYWORDS)\s*:]], -- Pattern plus permissif pour Astro
      },
      search = {
        command = "rg",
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--glob=!node_modules",
          "--glob=!.git",
        },
        pattern = [[\b(KEYWORDS):]], -- Pattern de recherche adapté
      },

      -- 1. DÉFINITION DE LA COULEUR PERSONNALISÉE
      colors = {
        mcp_color = { "#D97757" }, -- Orange style Claude
        test = { "#DC2626" }, -- (Optionnel) Je redéfinis "test" pour éviter une erreur si elle n'existe pas par défaut
      },

      -- 2. LISTE DES MOTS-CLÉS
      keywords = {
        -- Ton nouveau tag personnalisé
        ["MCP-GLOBAL-CLAUDE"] = {
          icon = "🤖",
          color = "mcp_color",
          alt = { "MCP", "CLAUDE" }, -- Tu pourras aussi écrire juste "MCP:" ou "CLAUDE:"
        },

        -- Tes anciens tags conservés
        FIX = {
          icon = " ",
          color = "error",
          alt = { "FIXME", "BUG", "FIXIT", "ISSUE" },
        },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
    },
  },
}
