-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/config/domains.lua
-- ══════════════════════════════════════════════════════════════════════

local M = {}

function M.apply(config)
  -- ═══════════════════════════════════════════════════════════════════
  -- SSH domains
  -- ═══════════════════════════════════════════════════════════════════
  config.ssh_domains = {
    { name = "play", remote_address = "play", multiplexing = "WezTerm" },
    { name = "prox", remote_address = "prox", multiplexing = "WezTerm" },
    { name = "contabo", remote_address = "contabo", multiplexing = "WezTerm" },
  }
end

return M