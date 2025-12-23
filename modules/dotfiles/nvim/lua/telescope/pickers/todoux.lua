-- ~/.config/nvim/lua/telescope/pickers/todoux.lua
-- Picker : sélectionner une image Todoux et insérer le chemin

local M = {}
local builtin = require("telescope.builtin")
local themes = require("telescope.themes")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

-- ─── CONFIGURATION ────────────────────────────────────────────────────────────
M.config = {
  images_dir = "/Users/jeremiealcaraz/Desktop/1.Progress/Pro/Assets/Branding/Jeremie_Branding/todoux",
  extensions = { "png", "jpg", "jpeg", "gif", "webp", "svg" },
  insert_format = "markdown", -- "markdown", "path", ou "filename"
}

-- ─── PREVIEWER PERSONNALISÉ ───────────────────────────────────────────────────
-- Utilise chafa pour afficher les images en ASCII art dans le terminal
local function image_previewer()
  return previewers.new_termopen_previewer({
    get_command = function(entry, status)
      local filepath = entry.path or entry.value
      -- Calculer la taille disponible pour la preview
      local win_width = vim.api.nvim_win_get_width(status.preview_win)
      local win_height = vim.api.nvim_win_get_height(status.preview_win)
      local size = string.format("%dx%d", win_width, win_height)

      -- chafa pour preview ASCII art (brew install chafa)
      if vim.fn.executable("chafa") == 1 then
        return { "chafa", "--size", size, "--animate", "off", "--stretch", filepath }
      end
      -- fallback: afficher les métadonnées avec file + exiftool
      if vim.fn.executable("exiftool") == 1 then
        return { "exiftool", filepath }
      end
      return { "file", filepath }
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
  -- Construire le pattern pour les extensions
  local ext_pattern = table.concat(M.config.extensions, ",")

  return themes.get_cursor({
    prompt_title = "󰋩 Todoux Assets",
    cwd = M.config.images_dir,
    previewer = image_previewer(),
    find_command = {
      "fd",
      "--type", "f",
      "--extension", "png",
      "--extension", "jpg",
      "--extension", "jpeg",
      "--extension", "gif",
      "--extension", "webp",
      "--extension", "svg",
    },
    layout_config = {
      width = 0.6,
      height = 0.5,
    },
    attach_mappings = function(prompt_bufnr, map)
      -- Entrée : insérer le chemin formaté
      actions.select_default:replace(function()
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

  builtin.find_files(get_picker_config())
end

-- ─── CONFIGURATION DU MAPPING ─────────────────────────────────────────────────
function M.get_keymap()
  return {
    "<leader>ti",
    M.open_picker,
    desc = "󰋩 Todoux image picker",
  }
end

return M
