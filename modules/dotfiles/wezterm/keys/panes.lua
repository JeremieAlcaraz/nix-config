-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/panes.lua - Raccourcis splits/panes
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.get_keys()
	return {
		{
			key = "h",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Left"),
		},
		{
			key = "j",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Down"),
		},
		{
			key = "k",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Up"),
		},
		{
			key = "l",
			mods = "LEADER",
			action = act.ActivatePaneDirection("Right"),
		},
		{
			key = "V",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
		},
		{
			key = "H",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
		},
	}
end

return M
