-- =====================================================================
-- ~/.config/wezterm/config/notifications.lua
-- =====================================================================

local wezterm = require('wezterm')
local M = {}

function M.apply(config)
  -- Notifications basees sur des patterns de sortie
  config.window_alert_on_bell = "WhenUnfocused"

  config.triggers = config.triggers or {}
  table.insert(config.triggers, {
    regex = 'Do you want to proceed\\?',
    action = wezterm.action.RingBell,
    match_interval = 2000,
  })
end

return M
