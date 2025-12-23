-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
--

-- TEST TEMPORAIRE - Ne touche pas au K existant
--vim.keymap.set("n", "<leader>h", function()
--require("config.custom-docs").show_documentation()
--end, { desc = "Show custom documentation" })
--TODO: In progress devaslife
local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- Delete a word backwards
keymap.set("n", "dw", "vb_d")

-- Split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

-- Move window
keymap.set("n", "sh", "<C-w>h")
keymap.set("n", "sk", "<C-w>k")
keymap.set("n", "sj", "<C-w>j")
keymap.set("n", "sl", "<C-w>l")

-- Todoux image picker
keymap.set("n", "<leader>@", function()
  require("telescope.pickers.todoux").open_picker()
end, { desc = "󰋩 Todoux image picker" })
