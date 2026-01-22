-- =====================================================================
-- ~/.config/wezterm/config/notifications.lua
-- =====================================================================

local wezterm = require("wezterm")
local M = {}

local POLL_LINES = 60
local COOLDOWN_SECONDS = 8

local PATTERNS = {
  {
    name = "Claude Code",
    match = "Do you want to proceed?",
    is_pattern = false,
    title = "Claude Code",
    message = "Interaction requise",
  },
}

local STATE = {
  last_seen = {},
  last_notified_at = {},
}

local function find_latest_match(text, spec)
  if not text or text == "" then
    return nil
  end

  local lines = {}
  for line in text:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end

  for i = #lines, 1, -1 do
    local line = lines[i]
    if spec.is_pattern then
      if line:match(spec.match) then
        return line
      end
    else
      if line:find(spec.match, 1, true) then
        return line
      end
    end
  end

  return nil
end

function M.apply(config)
  config.status_update_interval = config.status_update_interval or 1000

  wezterm.on("update-status", function(window, pane)
    if not pane then
      return
    end

    local text = pane:get_lines_as_text(POLL_LINES)
    local now = os.time()

    for _, spec in ipairs(PATTERNS) do
      local line = find_latest_match(text, spec)
      if line then
        local key = string.format("%s::%s", pane:pane_id(), spec.name)
        local last_seen = STATE.last_seen[key]
        local last_notified = STATE.last_notified_at[key] or 0

        if last_seen ~= line and (now - last_notified) >= COOLDOWN_SECONDS then
          local message = string.format("%s\n%s", spec.message, line)
          window:toast_notification(spec.title, message, nil, 4000)
          STATE.last_seen[key] = line
          STATE.last_notified_at[key] = now
        end
      end
    end
  end)
end

return M
