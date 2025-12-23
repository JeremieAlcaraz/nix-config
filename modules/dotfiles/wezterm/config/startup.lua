-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/startup.lua
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

function M.apply()
  -- ═══════════════════════════════════════════════════════════════════
  -- Événement de démarrage - Plein écran automatique
  -- ═══════════════════════════════════════════════════════════════════
  wezterm.on("gui-startup", function(cmd)
    local _tab, _pane, window = mux.spawn_window(cmd or {})
    window:gui_window():toggle_fullscreen()
  end)
end

return M