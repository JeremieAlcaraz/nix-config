-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/ui.lua
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")

local M = {}

function M.get_keys()
	return {
		-- Renommer l'onglet (style tmux: Prefix + r)
		{
			key = "r",
			mods = "LEADER",
			action = wezterm.action.PromptInputLine({
				description = "Nouveau nom d'onglet",
				action = wezterm.action_callback(function(window, _pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		-- Nouveau raccourci pour le debug overlay
		{
			key = "D",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = wezterm.action.ShowDebugOverlay,
		},
		-- Votre raccourci pour le plein écran
		{
			key = "p",
			mods = "CMD|ALT|CTRL|SHIFT",
			action = wezterm.action.ToggleFullScreen,
		},
		-- DÉSACTIVATION du Alt + Enter par défaut (bascule plein écran)
		-- Cela permet de libérer le raccourci pour vos applications (shell, nvim, etc.)
		{
			key = "Enter",
			mods = "ALT",
			action = wezterm.action.DisableDefaultAssignment,
		},
	}
end

return M
