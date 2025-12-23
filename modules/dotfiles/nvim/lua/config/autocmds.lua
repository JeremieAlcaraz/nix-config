-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Auto-indentation pour les fichiers HJSON à la sauvegarde
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.hjson" },
  callback = function()
    local view = vim.fn.winsaveview() -- Sauvegarde la position du curseur
    vim.cmd("normal! gg=G") -- Sélectionne tout et indente (=)
    vim.fn.winrestview(view) -- Restaure la position du curseur
  end,
})
