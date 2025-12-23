-- FinderPath.spoon/init.lua
local obj = {}
obj.__index = obj

obj.name    = "FinderPath"
obj.version = "1.0"
obj.author  = "Votre Nom <vous@exemple.com>"
obj.license = "MIT"
obj.homepage = "https://github.com/VotreUser/FinderPath.spoon"

-- (optionnel) initialisation côté spoon
function obj:init()
  -- rien à renseigner pour l'instant
end

-- Permet à SpoonInstall de binder les hotkeys
function obj:bindHotkeys(mapping)
  local spec = {
    copyPath = hs.fnutils.partial(self.copyPath, self)
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
end

-- Votre action principale : récupérer et copier le chemin
function obj:copyPath()
  local ok, path = hs.osascript.applescript([[
    tell application "Finder"
      if exists front window then
        POSIX path of (target of front window as alias)
      else
        ""
      end if
    end tell
  ]])
  if ok and path ~= "" then
    hs.pasteboard.setContents(path)
    hs.alert.show("Chemin copié :\n" .. path)
  else
    hs.alert.show("Aucune fenêtre Finder ouverte")
  end
end

-- (optionnel) démarrage/arrêt si besoin
function obj:start()
  -- démarrage automatique par SpoonInstall
end

function obj:stop()
  -- rien à nettoyer
end

return obj
