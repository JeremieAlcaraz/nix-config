-- ~/.config/nvim/lua/telescope/pickers/todoux_kitty.lua
-- Picker : sélectionner une image Todoux avec preview image.nvim (protocole Kitty)

local M = {}
local builtin = require("telescope.builtin")
local themes = require("telescope.themes")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

-- ─── CONFIGURATION ────────────────────────────────────────────────────────────
M.config = {
  images_dir = "/Users/jeremiealcaraz/Desktop/1.Progress/Pro/Assets/Branding/Jeremie_Branding/todoux",
  extensions = { "png", "jpg", "jpeg", "gif", "webp" }, -- svg non supporté par image.nvim
  insert_format = "markdown", -- "markdown", "path", ou "filename"
}

-- ─── PREVIEWER IMAGE.NVIM ─────────────────────────────────────────────────────
-- Utilise image.nvim pour afficher les images avec le protocole Kitty
local current_image = nil
local render_id = 0 -- ID unique pour chaque render, évite les race conditions

local function clear_image()
  if current_image then
    pcall(function()
      current_image:clear()
    end)
    current_image = nil
  end
end

local function image_nvim_previewer()
  return previewers.new_buffer_previewer({
    title = "Image Preview",

    define_preview = function(self, entry, status)
      local filepath = entry.path or (M.config.images_dir .. "/" .. entry.value)

      -- Incrémenter l'ID et capturer pour ce render
      render_id = render_id + 1
      local this_render_id = render_id

      -- Clear previous image immédiatement
      clear_image()

      -- Vérifier que image.nvim est disponible
      local ok, image_api = pcall(require, "image")
      if not ok then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          "image.nvim non disponible",
          "",
          "Installez image.nvim et vérifiez que votre",
          "terminal supporte le protocole Kitty graphics.",
        })
        return
      end

      -- Créer un buffer vide pour l'image
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "" })

      -- Render image avec image.nvim
      vim.defer_fn(function()
        -- Annuler si un autre render a été demandé entre-temps
        if this_render_id ~= render_id then
          return
        end

        -- Vérifier que le buffer et la fenêtre existent toujours
        if not vim.api.nvim_buf_is_valid(self.state.bufnr) then
          return
        end
        if not vim.api.nvim_win_is_valid(status.preview_win) then
          return
        end

        -- Clear encore une fois juste avant le render (sécurité)
        clear_image()

        current_image = image_api.from_file(filepath, {
          window = status.preview_win,
          buffer = self.state.bufnr,
          -- Utiliser 100% de la fenêtre (override les valeurs globales)
          max_width_window_percentage = 100,
          max_height_window_percentage = 100,
          -- Position au centre sera calculée par image.nvim
          x = 0,
          y = 0,
        })

        if current_image then
          current_image:render()
        end
      end, 80) -- Délai légèrement plus long pour stabilité
    end,

    teardown = function()
      render_id = render_id + 1 -- Invalider tout render en cours
      clear_image()
    end,
  })
end

-- ─── FORMATTAGE DE L'INSERTION ────────────────────────────────────────────────
local function format_for_insert(filepath)
  local format = M.config.insert_format
  local filename = vim.fn.fnamemodify(filepath, ":t")

  if format == "markdown" then
    return string.format("![%s](%s)", filename:gsub("%.%w+$", ""), filepath)
  elseif format == "filename" then
    return filename
  else
    return filepath
  end
end

-- ─── CONFIGURATION DU PICKER ──────────────────────────────────────────────────
local function get_picker_config()
  return themes.get_cursor({
    prompt_title = "󰋩 Todoux (Kitty)",
    cwd = M.config.images_dir,
    previewer = image_nvim_previewer(),
    find_command = {
      "fd",
      "--type", "f",
      "--extension", "png",
      "--extension", "jpg",
      "--extension", "jpeg",
      "--extension", "gif",
      "--extension", "webp",
    },
    layout_config = {
      width = 0.6,
      height = 0.5,
    },
    attach_mappings = function(prompt_bufnr, map)
      -- Entrée : insérer le chemin formaté
      actions.select_default:replace(function()
        clear_image() -- Clean up before closing
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          local filepath = M.config.images_dir .. "/" .. selection.value
          local text = format_for_insert(filepath)
          vim.api.nvim_put({ text }, "c", true, true)
        end
      end)

      -- Ctrl+Y : copier le chemin dans le presse-papiers
      map("i", "<C-y>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local filepath = M.config.images_dir .. "/" .. selection.value
          vim.fn.setreg("+", filepath)
          vim.notify("Copié: " .. filepath, vim.log.levels.INFO)
        end
      end)

      -- Escape : clean up image on close
      map("i", "<Esc>", function()
        clear_image()
        actions.close(prompt_bufnr)
      end)

      map("n", "<Esc>", function()
        clear_image()
        actions.close(prompt_bufnr)
      end)

      return true
    end,
  })
end

-- ─── FONCTION PRINCIPALE ──────────────────────────────────────────────────────
function M.open_picker()
  -- Vérifier que fd est disponible
  if vim.fn.executable("fd") == 0 then
    vim.notify("fd requis (brew install fd)", vim.log.levels.ERROR)
    return
  end

  -- Vérifier que le dossier existe
  if vim.fn.isdirectory(M.config.images_dir) == 0 then
    vim.notify("Dossier introuvable: " .. M.config.images_dir, vim.log.levels.ERROR)
    return
  end

  -- Charger image.nvim si pas encore chargé (lazy loading)
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { "image.nvim" } })
  end

  builtin.find_files(get_picker_config())
end

-- ─── CONFIGURATION DU MAPPING ─────────────────────────────────────────────────
function M.get_keymap()
  return {
    "<leader>tp",
    M.open_picker,
    desc = "󰋩 Todoux image picker (Kitty)",
  }
end

return M
