-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/modal.lua - Modal keybindings
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local modal = require("modal")

local M = {}

function M.get_keys()
	return {
		{
			key = "u",
			mods = "ALT",
			action = modal.activate_mode("UI"),
		},
		{
			key = "c",
			mods = "ALT",
			action = modal.activate_mode("copy_mode"),
		},
		{
			key = "n",
			mods = "ALT",
			action = modal.activate_mode("Scroll"),
		},
	}
end

return M
