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
	bar_bg = "#1a1b26",
	active = {
		title_bg = "#7aa2f7",
		title_fg = "#16161e",
		number_bg = "#E0AF68",
		number_fg = "#16161e",
	},
	inactive = {
		title_bg = "#292e42",
		title_fg = "#545c7e",
		number_bg = "#283457",
		number_fg = "#545c7e",
	},
	hover = {
		title_bg = "#292e42",
		title_fg = "#7aa2f7",
		number_bg = "#283457",
		number_fg = "#7aa2f7",
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

local function render_compact(colors, title, index, max_width)
	local content = index .. " " .. title
	local padding = 1
	local available = max_width - (padding * 2)
	if available < 1 then
		padding = 0
		available = max_width
	end
	available = math.max(1, available)
	content = wezterm.truncate_right(content, available)

	return {
		{ Background = { Color = colors.title_bg } },
		{ Foreground = { Color = colors.title_fg } },
		{ Text = string.rep(" ", padding) .. content .. string.rep(" ", padding) },
	}
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
		if max_width <= reserved + 2 then
			return render_compact(colors, title, index, max_width)
		end
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
