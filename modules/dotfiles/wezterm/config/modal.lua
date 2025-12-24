-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/modal.lua - Modal plugin setup
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")

local M = {}

local MODAL_URL = "https://github.com/JeremieAlcaraz/modal.wezterm"
local UPSTREAM_URL = "https://github.com/MLFlexer/modal.wezterm"

local function with_modal_require(fn)
	local original_require = wezterm.plugin.require
	wezterm.plugin.require = function(url)
		if url == UPSTREAM_URL then
			url = MODAL_URL
		end
		return original_require(url)
	end

	local ok, result = pcall(fn)
	wezterm.plugin.require = original_require

	if not ok then
		error(result)
	end

	return result
end

function M.apply(config)
	local modal = wezterm.plugin.require(MODAL_URL)
	modal.enable_defaults(MODAL_URL)

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

	local defaults = with_modal_require(function()
		return {
			ui_mode = require("ui_mode"),
			scroll_mode = require("scroll_mode"),
			copy_mode = require("copy_mode"),
			search_mode = require("search_mode"),
			visual_mode = require("visual_mode"),
		}
	end)

	local status_text = defaults.ui_mode.get_hint_status_text(
		icons,
		colors,
		{ bg = config.colors.ansi[2], fg = fg_status_color }
	)
	modal.add_mode("UI", defaults.ui_mode.key_table, status_text)

	status_text = defaults.scroll_mode.get_hint_status_text(
		icons,
		colors,
		{ bg = config.colors.ansi[7], fg = fg_status_color }
	)
	modal.add_mode("Scroll", defaults.scroll_mode.key_table, status_text)

	status_text = defaults.copy_mode.get_hint_status_text(
		icons,
		colors,
		{ bg = config.colors.ansi[4], fg = fg_status_color }
	)
	modal.add_mode("copy_mode", defaults.copy_mode.key_table, status_text)

	status_text = defaults.search_mode.get_hint_status_text(
		icons,
		colors,
		{ bg = config.colors.ansi[6], fg = fg_status_color }
	)
	modal.add_mode("search_mode", defaults.search_mode.key_table, status_text)

	status_text = defaults.visual_mode.get_hint_status_text(
		icons,
		colors,
		{ bg = config.colors.ansi[3], fg = fg_status_color }
	)
	modal.add_mode("Visual", {}, status_text)

	config.key_tables = modal.key_tables

	wezterm.on("modal.enter", function(name, window, _pane)
		modal.set_right_status(window, name)
	end)

	wezterm.on("modal.exit", function(_name, window, _pane)
		window:set_right_status("")
	end)

	wezterm.on("modal.exit_all", function(_name, window, _pane)
		window:set_right_status("")
	end)
end

return M
