require "ISUI/ISCharacterScreen"

_ISCharacterScreenCreate = ISCharacterScreen.create
---@diagnostic disable-next-line: duplicate-set-field
function ISCharacterScreen:create()
    _ISCharacterScreenCreate(self)
    self.diceMenuButton = ISButton:new(0, 0, 100, getTextManager():getFontHeight(UIFont.Small), "Dice System", self,
        ISCharacterScreen.onOpenDiceMenu)
    self.diceMenuButton:initialise()
    self.diceMenuButton:instantiate()
    self.diceMenuButton.background = false
    self:addChild(self.diceMenuButton)
end

_ISCharacterScreenUpdate = ISCharacterScreen.update
function ISCharacterScreen:update()
    _ISCharacterScreenUpdate(self)
    local nameX = self.avatarX + self.avatarWidth + 25

    self.diceMenuButton:setX(nameX)
    self.diceMenuButton:setY(self.literatureButton:getBottom() + 25)
end

function ISCharacterScreen.onOpenDiceMenu()
    local PlayerHandler = require("DiceSystem_PlayerHandling")
    PlayerHandler:instantiate(getPlayer():getUsername())

    local DiceMenu = require("UI/DiceSystem_PlayerUI")
    DiceMenu.OpenPanel(false, getPlayer():getUsername())
end
