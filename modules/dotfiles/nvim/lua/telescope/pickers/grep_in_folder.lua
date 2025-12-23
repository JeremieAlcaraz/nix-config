-- ~/.config/nvim/lua/telescope/pickers/grep_in_folder.lua
-- Picker : choisir un dossier avec fd, puis lancer un live_grep dedans

local M = {}
local builtin = require("telescope.builtin")

-- ─── CONFIGURATION DU PICKER ────────────────────────────────────────────────
local function get_folder_picker_config()
  return {
    prompt_title = "Sélection du dossier",
    cwd = vim.loop.cwd(), -- root courant du projet
    previewer = false, -- IMPORTANT : on liste des dossiers, pas de preview
    find_command = { "fd", "--type", "d", "--hidden", "--exclude", ".git" },
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        local actions = require("telescope.actions")
        local state = require("telescope.actions.state")
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          -- ── LANCER LIVE_GREP AVEC AFFICHAGE CUSTOM ───────────────────────
          local entry_display = require("telescope.pickers.entry_display")

          -- petit parseur vimgrep (rg --vimgrep) : "file:lnum:col:text"
          local function parse_vimgrep_line(line)
            local fname, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
            if not fname then
              return nil
            end
            return {
              filename = fname,
              lnum = tonumber(lnum),
              col = tonumber(col),
              text = text,
            }
          end

          local function basename(path)
            return path:match("([^/\\]+)$") or path
          end

          local displayer = entry_display.create({
            separator = " ",
            items = {
              { remaining = true }, -- à gauche : seulement le nom de fichier
            },
          })

          builtin.live_grep({
            search_dirs = { entry.value },

            -- ── LISTE DE GAUCHE : n'afficher que le nom de fichier ─────────
            entry_maker = function(line)
              local ret = parse_vimgrep_line(line)
              if not ret then
                return nil
              end
              local name = basename(ret.filename)
              return {
                value = ret, -- requis pour preview
                ordinal = name .. " " .. (ret.text or ""), -- fuzzy nom + contenu
                display = function()
                  return displayer({ name })
                end,
                filename = ret.filename,
                lnum = ret.lnum,
                col = ret.col,
                text = ret.text,
              }
            end,

            -- ── LAYOUT : preview = 80%, liste = 20% ────────────────────────
            layout_strategy = "horizontal",
            layout_config = {
              horizontal = {
                preview_width = 0.80, -- ≈ 80% pour la preview (droite)
              },
            },
          })
        end
      end)
      return true
    end,
  }
end

-- ─── FONCTION PRINCIPALE ────────────────────────────────────────────────────
function M.grep_in_folder()
  if vim.fn.executable("fd") == 0 then
    vim.notify("fd requis pour ce picker (brew install fd)", vim.log.levels.ERROR)
    return
  end
  builtin.find_files(get_folder_picker_config())
end

-- ─── CONFIGURATION DU MAPPING ───────────────────────────────────────────────
function M.get_keymap()
  return { "<leader>tf", M.grep_in_folder, desc = "Folder → live_grep" }
end

return M
