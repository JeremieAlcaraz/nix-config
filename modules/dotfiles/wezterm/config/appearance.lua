-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/appearance.lua
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	-- ═══════════════════════════════════════════════════════════════════
	-- Core appearance
	-- ═══════════════════════════════════════════════════════════════════
	config.enable_tab_bar = false
	config.window_decorations = "RESIZE"
	config.use_ime = false -- Faster startup on macOS
	config.native_macos_fullscreen_mode = true

	-- ═══════════════════════════════════════════════════════════════════
	-- Configuration clavier AZERTY français sur macOS
	-- ═══════════════════════════════════════════════════════════════════
	config.use_dead_keys = false
	config.send_composed_key_when_right_alt_is_pressed = true
	config.send_composed_key_when_left_alt_is_pressed = false
	config.debug_key_events = true

	-- ═══════════════════════════════════════════════════════════════════
	-- Font
	-- ═══════════════════════════════════════════════════════════════════
	config.font = wezterm.font("MesloLGS Nerd Font Mono")
	config.font_size = 19

	-- ═══════════════════════════════════════════════════════════════════
	-- Thème (actuel) — Tokyo Night
	-- ═══════════════════════════════════════════════════════════════════
	-- Variantes possibles : 'tokyonight_night', 'tokyonight_storm', 'tokyonight_moon',
	-- 'tokyonight_day', 'tokyonight_light' (selon versions)
	config.color_scheme = "tokyonight_night"

	-- 👉 (Optionnel) Basculer automatiquement selon l’apparence système
	-- Décommente pour activer la bascule auto (light/dark)
	-- if wezterm.gui and wezterm.gui.get_appearance():find("Dark") then
	--   config.color_scheme = "tokyonight_night"
	-- else
	--   config.color_scheme = "tokyonight_day"
	-- end

	-- ═══════════════════════════════════════════════════════════════════
	-- (ANCIEN THÈME CONSERVÉ EN COMMENTAIRE) — Batman
	-- ═══════════════════════════════════════════════════════════════════
	--[[
  -- Couleurs - Thème Batman
  -- config.color_scheme = "Batman"
  -- config.colors = {
  --   foreground = "#CBE0F0",
  --   background = "#011423",
  --   cursor_bg = "#47FF9C",
  --   cursor_fg = "#011423",
  --   cursor_border = "#47FF9C",
  --   selection_bg = "#033259",
  --   selection_fg = "#CBE0F0",
  --   ansi = {
  --     "#214969", "#E52E2E", "#44FFB1", "#FFE073",
  --     "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7"
  --   },
  --   brights = {
  --     "#214969", "#E52E2E", "#44FFB1", "#FFE073",
  --     "#A277FF", "#a277ff", "#24EAF7", "#24EAF7"
  --   },
  -- }
  ]]
end

return M

