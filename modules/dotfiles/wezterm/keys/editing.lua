-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/editing.lua 
-- ══════════════════════════════════════════════════════════════════════
local wezterm = require('wezterm')
local act = wezterm.action

local M = {}

function M.get_keys()
  return {
    -- ═══════════════════════════════════════════════════════════════════
    -- 5-A. Quick editing shortcuts
    -- ═══════════════════════════════════════════════════════════════════
    
    -- Suppression de ligne complète
    { key = "Backspace", mods = "CMD", action = act.SendString("\x15") },
    { key = "Delete", mods = "CMD", action = act.SendString("\x15") },
    
    -- Suppression de mot
    { key = "Backspace", mods = "OPT", action = act.SendString("\x17") },
    { key = "Delete", mods = "OPT", action = act.SendString("\x17") },
    
    -- Navigation début/fin de ligne
    { key = "LeftArrow", mods = "CMD", action = act.SendString("\x01") },
    { key = "RightArrow", mods = "CMD", action = act.SendString("\x05") },
    
    -- Navigation par mot
    { key = "LeftArrow", mods = "OPT", action = act.SendString("\x1bb") },
    { key = "RightArrow", mods = "OPT", action = act.SendString("\x1bf") },
    
    -- Navigation entre onglets
    { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
    { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  }
end

return M