-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/wezterm.lua - Point d'entrée principal
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require('wezterm')
local act = wezterm.action
local config = wezterm.config_builder()

local function in_app_debug(window, pane, message)
	if not pane then
		return
	end

	window:perform_action(act.SendString("\r\n[wezterm] " .. message .. "\r\n"), pane)
end

wezterm.on("debug-split-vertical", function(window, pane)
	in_app_debug(window, pane, "Split vertical (debug)")
end)

wezterm.on("debug-split-horizontal", function(window, pane)
	in_app_debug(window, pane, "Split horizontal (debug)")
end)

config.debug_key_events = true
config.key_map_preference = "Physical"

-- Import des modules de configuration
require('config.environment').apply(config)
require('config.appearance').apply(config)
require('config.domains').apply(config)
require('keys').apply(config)
require('config.startup').apply()


return config
