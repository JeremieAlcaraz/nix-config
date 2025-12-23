local M = {}

function M.apply(config)
  -- Configuration du PATH pour inclure Homebrew
  config.set_environment_variables = {
    PATH = "/opt/homebrew/bin:" .. (os.getenv("PATH") or "")
  }
end

return M