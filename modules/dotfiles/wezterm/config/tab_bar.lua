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
	bar_bg = "#303446",
	active = {
		title_bg = "#f4b8e4",
		title_fg = "#232634",
		number_bg = "#f4b8e4",
		number_fg = "#232634",
	},
	inactive = {
		title_bg = "#292c3c",
		title_fg = "#51576d",
		number_bg = "#292c3c",
		number_fg = "#51576d",
	},
	hover = {
		title_bg = "#292c3c",
		title_fg = "#f4b8e4",
		number_bg = "#292c3c",
		number_fg = "#f4b8e4",
	},
}

local function tab_title(tab)
	-- Priorité 1 : titre manuel (LEADER + r)
	-- Entrée vide lors du rename = reset → retour automatique
	local title = tab.tab_title
	if title and title ~= "" then
		if tab.active_pane and tab.active_pane.is_zoomed then
			title = title .. " "
		end
		return title
	end

	-- Priorité 2 : titre intelligent depuis zsh (branch git / dossier)
	local user_vars = tab.active_pane and tab.active_pane.user_vars
	local smart = user_vars and user_vars.WEZTERM_TAB_TITLE
	if smart and smart ~= "" then
		if tab.active_pane and tab.active_pane.is_zoomed then
			smart = smart .. " "
		end
		return smart
	end

	-- Priorité 3 : fallback sur le titre du processus
	title = tab.active_pane.title
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
