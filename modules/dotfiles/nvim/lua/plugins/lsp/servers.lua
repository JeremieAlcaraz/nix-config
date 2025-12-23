-- Path: ~/.config/nvim/lua/plugins/lsp/servers.lua
-- Role: Configuration spécifique de chaque serveur LSP
-- Description: Définit les paramètres et capacités pour chaque Language Server

local lspconfig = require("lspconfig")

-- Configuration commune pour tous les serveurs LSP
local function get_common_opts()
  -- Essayer de charger cmp_nvim_lsp, sinon utiliser les capacités par défaut
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end
  
  return {
    -- Capacités communes (autocomplétion, snippets, etc.)
    capabilities = capabilities,
    -- Fonction appelée quand le LSP s'attache à un buffer
    on_attach = function(client, bufnr)
      -- Désactiver le formatage pour certains serveurs (on utilisera prettier)
      if client.name == "tsserver" or client.name == "html" or client.name == "cssls" then
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end
      
      -- Configuration spécifique au buffer
      local opts = { buffer = bufnr, silent = true }
      
      -- Message de confirmation
      vim.notify("LSP " .. client.name .. " attached to buffer " .. bufnr, vim.log.levels.INFO)
    end,
  }
end

-- Configuration TypeScript/JavaScript
lspconfig.tsserver.setup(vim.tbl_extend("force", get_common_opts(), {
  -- Paramètres spécifiques à TypeScript
  settings = {
    typescript = {
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
  -- Filetypes supportés
  filetypes = {
    "javascript",
    "javascriptreact", 
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
}))

-- Configuration HTML
lspconfig.html.setup(vim.tbl_extend("force", get_common_opts(), {
  filetypes = { "html", "astro" }, -- Support pour Astro
  settings = {
    html = {
      format = {
        templating = true,
        wrapLineLength = 120,
        wrapAttributes = "auto",
      },
      hover = {
        documentation = true,
        references = true,
      },
    },
  },
}))

-- Configuration CSS
lspconfig.cssls.setup(vim.tbl_extend("force", get_common_opts(), {
  settings = {
    css = {
      validate = true,
      lint = {
        unknownAtRules = "ignore", -- Pour les règles CSS modernes
      },
    },
    scss = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
    less = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
  },
}))

-- Configuration Astro
lspconfig.astro.setup(vim.tbl_extend("force", get_common_opts(), {
  -- Astro a besoin de TypeScript pour fonctionner correctement
  init_options = {
    typescript = {
      tsdk = vim.fn.getcwd() .. "/node_modules/typescript/lib"
    },
  },
  settings = {
    astro = {
      -- Activer la validation TypeScript dans les composants Astro
      typescript = {
        enabled = true,
      },
    },
  },
}))

-- Configuration JSON
lspconfig.jsonls.setup(vim.tbl_extend("force", get_common_opts(), {
  settings = {
    json = {
      validate = { enable = true },
      -- TODO: Ajouter schemastore plus tard pour les schémas JSON
    },
  },
}))

-- Configuration Tailwind CSS
lspconfig.tailwindcss.setup(vim.tbl_extend("force", get_common_opts(), {
  filetypes = {
    "astro",
    "html",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
  },
  settings = {
    tailwindCSS = {
      -- Activer les suggestions dans les strings
      includeLanguages = {
        astro = "html",
        javascript = "javascript",
        typescript = "typescript",
      },
      -- Classes expérimentales
      experimental = {
        classRegex = {
          "class[:]\\s*['\"]([^'\"]*)['\"]",
          "className[:]\\s*['\"]([^'\"]*)['\"]",
        },
      },
    },
  },
}))

-- Message de confirmation du chargement
vim.notify("LSP servers configuration loaded", vim.log.levels.INFO)