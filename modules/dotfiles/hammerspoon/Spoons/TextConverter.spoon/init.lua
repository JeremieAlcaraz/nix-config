local obj = {}
obj.__index = obj

obj.name     = "TextConverter"
obj.version  = "1.0"
obj.author   = "Votre nom <vous@email>"
obj.homepage = "https://github.com/…/TextConverter.spoon"
obj.license  = "MIT"

obj.logger = hs.logger.new('TextConverter')

-- default hotkey (si utilisé sans SpoonInstall)
obj.hotkey = { {"ctrl","shift"}, "L" }

function obj:convertMultilineToSingleline()
    local clipboard = hs.pasteboard.getContents()
    if not clipboard then
        self.logger.w("Clipboard vide")
        hs.alert.show("Clipboard vide !", 1)
        return false
    end
    local single = clipboard
        :gsub("\r\n"," ")
        :gsub("\n"," ")
        :gsub("\r"," ")
        :gsub("%s+"," ")
        :gsub("^%s+","")
        :gsub("%s+$","")
    hs.pasteboard.setContents(single)
    self.logger.i(
      ("Conversion %d→%d chars"):format(#clipboard,#single)
    )
    hs.alert.show("✓ Converti en single line", 0.8)
    return true
end

function obj:bindHotkeys(mapping)
    if mapping and mapping.convert then
        if self.hotkey_convert then
            self.hotkey_convert:delete()
        end
        local mods, key = mapping.convert[1], mapping.convert[2]
        self.hotkey_convert = hs.hotkey.bind(mods, key, function()
            self:convertMultilineToSingleline()
        end)
    end
    return self
end

function obj:start()
    -- SpoonInstall a déjà bindé les hotkeys
    self.logger.i("TextConverter démarré")
    return self
end

function obj:stop()
    if self.hotkey_convert then
        self.hotkey_convert:delete()
        self.hotkey_convert = nil
    end
    self.logger.i("TextConverter arrêté")
    return self
end

return obj
