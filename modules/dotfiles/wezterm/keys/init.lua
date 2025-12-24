-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/init.lua - Point d'entrée des keybindings
-- ══════════════════════════════════════════════════════════════════════

local editing = require("keys.editing")
local ssh = require("keys.ssh")
local tools = require("keys.tools")
local files = require("keys.files") -- NOUVEAU
local ui = require("keys.ui") -- Assurez-vous que cette ligne existe
local panes = require("keys.panes")

local M = {}

function M.apply(config)
	config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

	-- ═══════════════════════════════════════════════════════════════════
	-- Assemblage de tous les raccourcis clavier
	-- ═══════════════════════════════════════════════════════════════════
	local keys = {}

	-- Ajouter les raccourcis d'édition (5-A)
	for _, key in ipairs(editing.get_keys()) do
		table.insert(keys, key)
	end

	-- Ajouter les raccourcis SSH (5-B)
	for _, key in ipairs(ssh.get_keys()) do
		table.insert(keys, key)
	end

	-- Ajouter les outils (5-C)
	for _, key in ipairs(tools.get_keys()) do
		table.insert(keys, key)
	end

	-- Ajouter les raccourcis fichiers
	for _, key in ipairs(files.get_keys()) do
		table.insert(keys, key)
	end

	-- Assurez-vous que cette ligne existe
	for _, key in ipairs(ui.get_keys()) do
		table.insert(keys, key)
	end

	for _, key in ipairs(panes.get_keys()) do
		table.insert(keys, key)
	end

	config.keys = keys
end

return M
