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
  queue_checked_at = 0,
}

local function queue_path()
  local home = os.getenv("HOME")
  if not home or home == "" then
    return nil
  end

  local cache_home = os.getenv("XDG_CACHE_HOME")
  if not cache_home or cache_home == "" then
    cache_home = home .. "/.cache"
  end

  return cache_home .. "/wezterm/claude-notify"
end

local QUEUE_PATH = queue_path()

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function truncate_file(path)
  local file = io.open(path, "w")
  if not file then
    return
  end
  file:write("")
  file:close()
end

local function notify_from_queue(window)
  if not QUEUE_PATH then
    return
  end

  local content = read_file(QUEUE_PATH)
  if not content or content == "" then
    return
  end

  truncate_file(QUEUE_PATH)

  for line in content:gmatch("[^\n]+") do
    local title, message, repo = line:match("([^\t]*)\t([^\t]*)\t(.*)")
    if title and message then
      local toast_title = title
      if repo and repo ~= "" then
        toast_title = string.format("%s · %s", title, repo)
      end
      window:toast_notification(toast_title, message, nil, 4000)
    end
  end
end

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

    if now ~= STATE.queue_checked_at then
      STATE.queue_checked_at = now
      notify_from_queue(window)
    end

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
