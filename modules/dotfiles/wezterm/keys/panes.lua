-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/panes.lua - Raccourcis splits/panes
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.get_keys()
	return {
		{
			key = "V",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = act.Multiple({
				act.EmitEvent("debug-split-vertical"),
				act.SplitVertical({ domain = "CurrentPaneDomain" }),
			}),
		},
		{
			key = "H",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = act.Multiple({
				act.EmitEvent("debug-split-horizontal"),
				act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
			}),
		},
	}
end

return M
