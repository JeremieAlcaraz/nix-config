-- ~/.config/nvim/lua/plugins/image.lua
-- Plugin pour afficher des images dans Neovim
-- Supporte: Kitty, WezTerm, Ghostty, iTerm2

return {
  {
    "3rd/image.nvim",
    -- Uniquement si le terminal supporte les images
    cond = function()
      local term = vim.env.TERM_PROGRAM or ""
      local kitty = vim.env.KITTY_WINDOW_ID ~= nil
      return kitty
        or term:lower():match("wezterm")
        or term:lower():match("ghostty")
        or term:lower():match("iterm")
    end,
    ft = { "markdown", "markdown.mdx", "mdx", "neorg", "oil" },
    opts = {
      backend = "kitty",
      max_height_window_percentage = 30,
      max_width_window_percentage = 50,
      -- Options critiques pour le scroll
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
      editor_only_render_when_focused = true,
      tmux_show_only_in_active_window = true,
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          only_render_image_at_cursor = true, -- Affiche uniquement l'image sous le curseur
          filetypes = { "markdown", "markdown.mdx", "mdx", "vimwiki" },
        },
      },
    },
  },
}
