-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/tab_limit.lua
-- Limite le nombre d'onglets ouverts
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local M = {}

M.max_tabs = 6
M.banner_duration_s = 4

M._banner_until = 0

local PALETTE = {
	bg = "#f7768e", -- Tokyo Night: alert
	fg = "#1a1b26", -- Tokyo Night: background
}

local function get_tabs(window)
	if window.tabs then
		local ok, tabs = pcall(function()
			return window:tabs()
		end)
		if ok and tabs then
			return tabs
		end
	end

	if window.mux_window then
		local ok, mux_window = pcall(function()
			return window:mux_window()
		end)
		if ok and mux_window and mux_window.tabs then
			local ok_tabs, tabs = pcall(function()
				return mux_window:tabs()
			end)
			if ok_tabs and tabs then
				return tabs
			end
		end
	end

	return {}
end

local function banner_text()
	return string.format("  LIMITE: %d ONGLET(S)  ", M.max_tabs)
end

local function banner_format()
	return wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Foreground = { Color = PALETTE.fg } },
		{ Background = { Color = PALETTE.bg } },
		{ Text = banner_text() },
	})
end

local function show_banner(window)
	window:set_left_status(banner_format())
end

local function clear_banner(window)
	window:set_left_status("")
end

wezterm.on("update-right-status", function(window, _pane)
	if M._banner_until == 0 then
		return
	end

	if os.time() <= M._banner_until then
		show_banner(window)
		return
	end

	clear_banner(window)
	M._banner_until = 0
end)

function M.allow_new_tab(window)
	local tabs = get_tabs(window)
	if #tabs >= M.max_tabs then
		M._banner_until = os.time() + M.banner_duration_s
		show_banner(window)
		window:toast_notification(
			"WezTerm",
			"Trop d'onglets ouverts (max " .. M.max_tabs .. ").",
			nil,
			4000
		)
		return false
	end
	return true
end

function M.guard_action(action)
	return wezterm.action_callback(function(window, pane)
		if not M.allow_new_tab(window) then
			return
		end
		window:perform_action(action, pane)
	end)
end

return M
