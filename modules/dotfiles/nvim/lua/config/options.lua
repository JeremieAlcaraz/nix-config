-- -- Options are automatically loaded before lazy.nvim startup
-- -- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- -- Add any additional options here
-- -- Forcer vim à déclencher l'autocomplétion automatiquement
-- vim.opt.completeopt = "menu,menuone,noinsert"
--
-- -- Activer l'autocomplétion automatique
-- vim.api.nvim_create_autocmd("InsertEnter", {
--   callback = function()
--     require("cmp").setup({
--       completion = {
--         autocomplete = {
--           require("cmp").TriggerEvent.TextChanged,
--         },
--       },
--     })
--   end,
-- })

vim.opt.clipboard = "unnamedplus" -- Configuration avancée du clipboard

-- Force la synchronisation du clipboard pour tous les buffers
vim.g.clipboard = {
  name = "system",
  copy = {
    ["+"] = "pbcopy", -- macOS
    ["*"] = "pbcopy", -- macOS
  },
  paste = {
    ["+"] = "pbpaste", -- macOS
    ["*"] = "pbpaste", -- macOS
  },
}

vim.filetype.add({
  extension = {
    mdx = "markdown",
  },
})
