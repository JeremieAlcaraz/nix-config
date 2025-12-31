-- ══════════════════════════════════════════════════════════════════════
-- ~/.config/wezterm/keys/tools.lua - Outils et utilitaires (5-C)
-- ══════════════════════════════════════════════════════════════════════

local wezterm = require('wezterm')
local act = wezterm.action
local tab_limit = require("config.tab_limit")

local M = {}

function M.get_keys()
  return {
    -- ═══════════════════════════════════════════════════════════════════
    -- 5-C. Tree view: afficher un arbre et copier dans le presse-papier
    -- ═══════════════════════════════════════════════════════════════════
    
    -- Désactiver le raccourci par défaut
    { key = "t", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
    
    -- Notre binding personnalisé pour tree
    {
      key = "t",
      mods = "CTRL|SHIFT",
      action = act.PromptInputLine {
        description = "Profondeur du tree (défaut 2) :",
        initial_value = "2",
        action = wezterm.action_callback(function(window, pane, line)
          if not line then
            return
          end
          
          local lvl = line:gsub("%D+", "")
          if lvl == "" then
            lvl = "2"
          end

          -- Commande tree avec tee pour copier dans le presse-papier
          local bash_cmd = string.format(
            [[
tree -C -L %s -I '.gitignore|node_modules' \
  | tee /dev/tty >(sed -E 's/\x1B\[[0-9;]*m//g' | pbcopy) ;
echo "";
echo "Arbre copié dans le presse-papier (Ctrl-D pour fermer)";
exec $SHELL -l
]],
            lvl
          )

          if not tab_limit.allow_new_tab(window) then
            return
          end

          window:perform_action(
            act.SpawnCommandInNewTab {
              args = { "/usr/bin/env", "bash", "-lc", bash_cmd },
            },
            pane
          )
        end),
      },
    },
  }
end

return M
