-- ~/.hammerspoon/init.lua
hs.loadSpoon("SpoonInstall")
local Install = spoon.SpoonInstall

-- 1) déclare le repo local
Install.repos["local"] = {
	desc = "Mes Spoons perso",
	url = os.getenv("HOME") .. "/.hammerspoon/Spoons",
}

-- 2) ReloadConfiguration
Install:andUse("ReloadConfiguration", { start = true })

-- 3) FinderPath (⌃⇧F → copie le chemin du Finder)
Install:andUse("FinderPath", {
	repo = "local", -- <— important !
	hotkeys = { copyPath = { { "ctrl", "shift" }, "F" } },
	start = true,
})

-- TextConverter  (⌃⇧L)
Install:andUse("TextConverter", {
	repo = "local", -- <— important !
	hotkeys = { convert = { { "ctrl", "shift", "alt", "cmd" }, "K" } },
	start = true,
})

-- Quitter Aerospace (désactive le tiling manager)
hs.hotkey.bind({ "cmd", "alt" }, "Q", function()
	hs.execute("killall AeroSpace")
	hs.notify.new({ title = "AeroSpace", informativeText = "AeroSpace quitté" }):send()
end)

-- Lancer Aerospace (active le tiling manager)
hs.hotkey.bind({ "cmd", "alt" }, "W", function()
	hs.execute("open -a AeroSpace")
	hs.notify.new({ title = "AeroSpace", informativeText = "AeroSpace lancé" }):send()
end)

-- Basculer la fenêtre courante en flottant/tiling (adapte le chemin si besoin)
hs.hotkey.bind({ "cmd", "alt" }, "A", function()
	hs.execute("/opt/homebrew/bin/aerospace layout floating tiling")
	hs.notify.new({ title = "AeroSpace", informativeText = "Tiling/Flottant basculé" }):send()
end)

---

local function openNewWezTermWindow()
	hs.execute("open -na WezTerm")
end

local function focusPreviousWindow()
	local orderedWindows = hs.window.orderedWindows()
	if #orderedWindows > 1 then
		orderedWindows[2]:focus()
	end
end

local function findWezTermInCurrentSpace()
	local wezTermApp = hs.application.find("WezTerm")
	if not wezTermApp then
		return nil
	end

	local currentSpace = hs.spaces.focusedSpace()
	for _, window in ipairs(wezTermApp:allWindows()) do
		local windowSpaces = hs.spaces.windowSpaces(window)
		if windowSpaces and hs.fnutils.contains(windowSpaces, currentSpace) then
			return window
		end
	end

	return nil
end

local function toggleWezTermInCurrentSpace()
	local wezTermWindow = findWezTermInCurrentSpace()
	if not wezTermWindow then
		openNewWezTermWindow()
		return
	end

	local focusedWindow = hs.window.focusedWindow()
	if focusedWindow and focusedWindow:id() == wezTermWindow:id() then
		focusPreviousWindow()
	else
		wezTermWindow:focus()
	end
end

hs.hotkey.bind({ "alt" }, "space", toggleWezTermInCurrentSpace)

---
-- -- === Toggle du launcher wezterm (ALT+Space) ===============================
--
-- local WEZBIN = "/Applications/WezTerm.app/Contents/MacOS/wezterm-gui"
--
-- local TARGET_W, TARGET_H = 0.60, 0.38
-- local TOP_MARGIN = 0.15
--
-- local function placeTopCenter(win)
-- 	local scr = (hs.mouse.getCurrentScreen() or hs.screen.mainScreen()):frame()
-- 	local w, h = scr.w * TARGET_W, scr.h * TARGET_H
-- 	local x = scr.x + (scr.w - w) / 2
-- 	local y = scr.y + (scr.h * TOP_MARGIN)
-- 	win:setFrame({ x = x, y = y, w = w, h = h }, 0)
-- 	hs.timer.doAfter(0.03, function()
-- 		win:setFrame({ x = x, y = y, w = w, h = h }, 0)
-- 	end)
-- 	win:raise()
-- 	win:focus()
-- end
--
-- -- simple : on prend la dernière fenêtre WezTerm
-- local function getWezTermWindow()
-- 	local app = hs.application.get("WezTerm")
-- 	if not app then
-- 		return nil
-- 	end
-- 	return app:focusedWindow() or app:mainWindow() or app:allWindows()[1]
-- end
--
-- hs.hotkey.bind({ "alt" }, "space", function()
-- 	local win = getWezTermWindow()
-- 	if win then
-- 		if hs.window.focusedWindow() == win and not win:isMinimized() then
-- 			win:minimize()
-- 			return
-- 		end
-- 		if win:isMinimized() then
-- 			win:unminimize()
-- 		end
-- 		placeTopCenter(win)
-- 		return
-- 	end
--
-- 	-- sinon on lance une nouvelle fenêtre classique
-- 	hs.task.new(WEZBIN, nil, { "start" }):start()
-- end)


-- === Zen ultra-simple: focus si déjà lancé, sinon lance =====================
local ZEN_BIN = "/Applications/Zen.app/Contents/MacOS/zen"
local ZEN_PRO = "/Users/jeremiealcaraz/Library/Application Support/zen/Profiles/uta71ubg.Professionnal"
local ZEN_PER = "/Users/jeremiealcaraz/Library/Application Support/zen/Profiles/ekz8l6do.Personal"

local function focusOrLaunch(profilePath)
  -- trouve un PID de Zen qui contient ce chemin de profil dans sa ligne de commande
  local out = hs.execute('/usr/bin/pgrep -f "' .. profilePath .. '"')  -- renvoie "" si rien
  local pid = tonumber((out or ""):match("%d+"))

  if pid then
    local app = hs.application.get(pid)
    if app then app:activate(true) end   -- focus l’instance existante
  else
    hs.task.new(ZEN_BIN, nil, {"--no-remote","--profile", profilePath}):start()  -- lance
  end
end

-- Raccourcis (garde ceux qui marchent chez toi)
hs.hotkey.bind({"ctrl","cmd"}, "P", function() focusOrLaunch(ZEN_PRO) end) -- Pro
hs.hotkey.bind({"ctrl","cmd"}, "D", function() focusOrLaunch(ZEN_PER) end) -- Perso






