-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/ssh.lua - Raccourcis SSH (5-B)
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.get_keys()
	return {
		-- ═══════════════════════════════════════════════════════════════════
		-- 5-B. Custom SSH shortcuts
		-- ═══════════════════════════════════════════════════════════════════
		{
			key = "1",
			mods = "CTRL|SHIFT",
			action = act.SpawnCommandInNewTab({ args = { "ssh", "magnolia" } }),
		},
		{
			key = "2",
			mods = "CTRL|SHIFT",
			action = act.SpawnCommandInNewTab({ args = { "ssh", "whitelily" } }),
		},
		{
			key = "3",
			mods = "CTRL|SHIFT",
			action = act.SpawnCommandInNewTab({ args = { "ssh", "muscari" } }),
		},
		{
			key = "4",
			mods = "CTRL|SHIFT",
			action = act.SpawnCommandInNewTab({ args = { "ssh", "crocus" } }),
		},
	}
end

return M
