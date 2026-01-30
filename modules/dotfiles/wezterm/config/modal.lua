-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/modal.lua - Modal setup (local module)
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")

local M = {}

function M.apply(config)
	local modal = require("modal")
	modal.enable_defaults()

	if not config.colors then
		if config.color_scheme then
			config.colors = wezterm.color.get_builtin_schemes()[config.color_scheme]
		else
			config.colors = wezterm.color.get_default_colors()
		end
	end

	local icons = {
		left_seperator = wezterm.nerdfonts.ple_left_half_circle_thick,
		key_hint_seperator = "  ",
		mod_seperator = "-",
	}

	local colors = {
		key_hint_seperator = config.colors.foreground,
		key = config.colors.foreground,
		hint = config.colors.foreground,
		bg = config.colors.background,
		left_bg = config.colors.background,
	}

	local fg_status_color = config.colors.background

	local defaults = {
		ui_mode = require("ui_mode"),
		scroll_mode = require("scroll_mode"),
		copy_mode = require("copy_mode"),
		search_mode = require("search_mode"),
		visual_mode = require("visual_mode"),
	}

	-- Fonction pour créer un badge propre style LazyVim (juste le badge, pas de hints)
	local function create_mode_badge(mode_name, bg_color)
		return wezterm.format({
			{ Attribute = { Intensity = "Bold" } },
			{ Background = { Color = bg_color } },
			{ Foreground = { Color = fg_status_color } },
			{ Text = " " .. mode_name .. " " },
		})
	end

	modal.add_mode("UI", defaults.ui_mode.key_table,
		create_mode_badge("UI", config.colors.ansi[2]))

	modal.add_mode("Scroll", defaults.scroll_mode.key_table,
		create_mode_badge("SCROLL", config.colors.ansi[7]))

	modal.add_mode("copy_mode", defaults.copy_mode.key_table,
		create_mode_badge("COPY", config.colors.ansi[4]))

	modal.add_mode("search_mode", defaults.search_mode.key_table,
		create_mode_badge("SEARCH", config.colors.ansi[6]))

	modal.add_mode("Visual", {},
		create_mode_badge("VISUAL", config.colors.ansi[3]))

	config.key_tables = modal.key_tables

	-- Utiliser update-status pour afficher le badge en haut à droite
	wezterm.on("update-status", function(window, _pane)
		local mode = modal.get_mode(window)
		if mode and mode.status_text then
			window:set_right_status(mode.status_text)
		end
	end)

	wezterm.on("modal.exit", function(_name, window, _pane)
		window:set_right_status("")
	end)

	wezterm.on("modal.exit_all", function(_name, window, _pane)
		window:set_right_status("")
	end)
end

return M
