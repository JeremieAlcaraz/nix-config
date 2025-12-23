-- Path: ~/.config/nvim/lua/plugins/lsp/keymaps.lua
-- Role: Configuration des raccourcis clavier pour les fonctionnalités LSP
-- Description: Définit tous les keymaps pour navigation, refactoring, diagnostics, etc.

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

-- ========================================
-- NAVIGATION LSP
-- ========================================

-- Aller à la définition
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })

-- Aller à la déclaration
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })

-- Aller à l'implémentation
map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to Implementation" })

-- Aller à la définition de type
map("n", "gt", vim.lsp.buf.type_definition, { desc = "Go to Type Definition" })

-- Trouver les références
map("n", "gr", vim.lsp.buf.references, { desc = "Go to References" })

-- ========================================
-- INFORMATIONS ET DOCUMENTATION
-- ========================================

-- Afficher la documentation (hover)
map("n", "K", vim.lsp.buf.hover, { desc = "Show Hover Documentation" })

-- Afficher l'aide sur les paramètres
map("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Show Signature Help" })

-- Afficher les informations sur le symbole
map("n", "<leader>li", vim.lsp.buf.document_symbol, { desc = "Document Symbols" })

-- Afficher les symboles du workspace
map("n", "<leader>lw", vim.lsp.buf.workspace_symbol, { desc = "Workspace Symbols" })

-- ========================================
-- REFACTORING ET ACTIONS
-- ========================================

-- Actions de code disponibles
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Actions" })
map("v", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Actions (Visual)" })

-- Renommer un symbole
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename Symbol" })

-- Formater le code
map("n", "<leader>lf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format Code" })

-- Formater la sélection
map("v", "<leader>lf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format Selection" })

-- ========================================
-- GESTION DU WORKSPACE
-- ========================================

-- Ajouter un dossier au workspace
map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, { desc = "Add Workspace Folder" })

-- Retirer un dossier du workspace
map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, { desc = "Remove Workspace Folder" })

-- Lister les dossiers du workspace
map("n", "<leader>wl", function()
  print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
end, { desc = "List Workspace Folders" })

-- ========================================
-- DIAGNOSTICS
-- ========================================

-- Aller au diagnostic suivant
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })

-- Aller au diagnostic précédent
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })

-- Afficher les diagnostics du buffer courant
map("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Show Line Diagnostics" })

-- Afficher tous les diagnostics dans la quickfix
map("n", "<leader>lq", vim.diagnostic.setqflist, { desc = "Diagnostics to Quickfix" })

-- ========================================
-- LSPSAGA (UI améliorée) - si installé
-- ========================================

-- Finder LSP amélioré
map("n", "gh", "<cmd>Lspsaga finder<CR>", { desc = "LSP Finder" })

-- Aperçu de la définition
map("n", "gp", "<cmd>Lspsaga peek_definition<CR>", { desc = "Peek Definition" })

-- Aperçu des références
map("n", "gP", "<cmd>Lspsaga peek_references<CR>", { desc = "Peek References" })

-- Renommer avec UI améliorée
map("n", "<leader>rR", "<cmd>Lspsaga rename<CR>", { desc = "Rename (Saga)" })

-- Actions de code avec UI améliorée
map("n", "<leader>cA", "<cmd>Lspsaga code_action<CR>", { desc = "Code Actions (Saga)" })

-- Diagnostics avec UI améliorée
map("n", "<leader>lD", "<cmd>Lspsaga show_line_diagnostics<CR>", { desc = "Show Line Diagnostics (Saga)" })

-- Navigation dans les diagnostics
map("n", "]D", "<cmd>Lspsaga diagnostic_jump_next<CR>", { desc = "Next Diagnostic (Saga)" })
map("n", "[D", "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = "Previous Diagnostic (Saga)" })

-- ========================================
-- UTILITAIRES
-- ========================================

-- Redémarrer le LSP
map("n", "<leader>lr", "<cmd>LspRestart<CR>", { desc = "Restart LSP" })

-- Informations sur le LSP
map("n", "<leader>li", "<cmd>LspInfo<CR>", { desc = "LSP Info" })

-- Ouvrir Mason pour gérer les LSP
map("n", "<leader>lm", "<cmd>Mason<CR>", { desc = "Open Mason" })

-- ========================================
-- CONFIGURATION CONDITIONNELLE
-- ========================================

-- Fonction pour activer les keymaps uniquement quand LSP est attaché
local function setup_buffer_keymaps(bufnr)
  -- Ces keymaps ne sont actifs que dans les buffers avec LSP
  local bufopts = { noremap = true, silent = true, buffer = bufnr }

  -- Exemple de keymap spécifique au buffer
  vim.keymap.set("n", "<leader>lh", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end, vim.tbl_extend("force", bufopts, { desc = "Toggle Inlay Hints" }))
end

-- Auto-command pour setup les keymaps quand LSP s'attache
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    setup_buffer_keymaps(ev.buf)
  end,
})

-- Message de confirmation
vim.notify("LSP keymaps loaded", vim.log.levels.INFO)
