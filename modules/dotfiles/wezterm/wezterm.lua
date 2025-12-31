-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/wezterm.lua - Point d'entrée principal
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.key_map_preference = "Mapped"

-- Import des modules de configuration
require('config.environment').apply(config)
require('config.appearance').apply(config)
require('config.tab_bar').apply(config)
require('config.domains').apply(config)
require('config.modal').apply(config)
require('keys').apply(config)
require('config.startup').apply()


return config
