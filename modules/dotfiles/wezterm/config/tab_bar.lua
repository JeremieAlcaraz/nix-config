-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/tab_bar.lua
-- Onglets façon tmux (style Catppuccin + séparateurs powerline)
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local M = {}

local LEFT_SEP = ""
local RIGHT_SEP = " "
local MID_SEP = " █"

local PALETTE = {
	bar_bg = "#1e1e2e",
	active = {
		title_bg = "#45475a",
		title_fg = "#cdd6f4",
		number_bg = "#cba6f7",
		number_fg = "#1e1e2e",
	},
	inactive = {
		title_bg = "#313244",
		title_fg = "#a6adc8",
		number_bg = "#45475a",
		number_fg = "#a6adc8",
	},
	hover = {
		title_bg = "#585b70",
		title_fg = "#cdd6f4",
		number_bg = "#b4befe",
		number_fg = "#1e1e2e",
	},
}

local function tab_title(tab)
	local title = tab.tab_title
	if not title or title == "" then
		title = tab.active_pane.title
	end
	if not title or title == "" then
		title = "shell"
	end
	if tab.active_pane and tab.active_pane.is_zoomed then
		title = title .. " "
	end
	return title
end

function M.apply(config)
	if not config.colors then
		if config.color_scheme then
			config.colors = wezterm.color.get_builtin_schemes()[config.color_scheme]
				or wezterm.color.get_default_colors()
		else
			config.colors = wezterm.color.get_default_colors()
		end
	end
	config.colors.tab_bar = {
		background = PALETTE.bar_bg,
		new_tab = { bg_color = PALETTE.bar_bg, fg_color = PALETTE.inactive.title_fg },
		new_tab_hover = { bg_color = PALETTE.bar_bg, fg_color = PALETTE.hover.title_fg },
	}

	wezterm.on("format-tab-title", function(tab, _tabs, _panes, _conf, hover, max_width)
		local colors = PALETTE.inactive
		if tab.is_active then
			colors = PALETTE.active
		elseif hover then
			colors = PALETTE.hover
		end

		local index = tostring(tab.tab_index + 1)
		local title = tab_title(tab)
		local reserved = 9 + #index
		local max_title_width = max_width - reserved
		if max_title_width < 0 then
			max_title_width = 0
		end
		title = wezterm.truncate_right(title, max_title_width)

		return {
			{ Background = { Color = PALETTE.bar_bg } },
			{ Foreground = { Color = colors.title_bg } },
			{ Text = LEFT_SEP },
			{ Background = { Color = colors.title_bg } },
			{ Foreground = { Color = colors.title_fg } },
			{ Text = " " .. title .. " " },
			{ Background = { Color = colors.title_bg } },
			{ Foreground = { Color = colors.number_bg } },
			{ Text = MID_SEP },
			{ Background = { Color = colors.number_bg } },
			{ Foreground = { Color = colors.number_fg } },
			{ Text = " " .. index .. " " },
			{ Background = { Color = PALETTE.bar_bg } },
			{ Foreground = { Color = colors.number_bg } },
			{ Text = RIGHT_SEP },
		}
	end)
end

return M
