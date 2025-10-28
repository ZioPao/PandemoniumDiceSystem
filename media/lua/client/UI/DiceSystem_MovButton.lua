local DiceMenu = require("UI/DiceSystem_PlayerUI")
local MOVBTN_STRING = "_MOVBUTTON"

---@class DiceSystem_MovBtnPanel : ISPanel
---@field backgroundTex Texture
DiceSystem_MovBtnPanel = ISPanel:derive("DiceMovButton")
local BUTTON_X = 11
local ICON_SIZE = 32

function DiceSystem_MovBtnPanel:new(x, y)
	local o = {}
	o = ISPanel:new(x, y, 64, 64)
	setmetatable(o, self)
    self.__index = self
	o.x = x
	o.y = y
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.anchorLeft = true
	o.anchorRight = false
	o.anchorTop = true
	o.anchorBottom = false
	o.moveWithMouse = true
    o.backgroundTex = getTexture("media/ui/HandMain2_Off.png")
    o.dragTex = getTexture("media/ui/dragIcon.png")
	o.diceIconOff = getTexture("media/ui/diceBtnIcon_Off.png")
	o.diceIconOn = getTexture("media/ui/diceBtnIcon_On.png")

    DiceSystem_MovBtnPanel.instance = o
	return o
end

function DiceSystem_MovBtnPanel:initialise()
	ISPanel.initialise(self)

    self.diceTex = ISImage:new(4, 0, self.backgroundTex:getWidthOrig(), self.backgroundTex:getHeightOrig(), self.backgroundTex)
    self.diceTex:initialise()
    self.diceTex.parent = self
    self:addChild(self.diceTex)

	self.diceBtn = ISButton:new(BUTTON_X, 7, ICON_SIZE, ICON_SIZE, "", self, DiceSystem_MovBtnPanel.onOptionMouseDown)
    self.diceBtn:setImage(self.diceIconOff)
    self.diceBtn.internal = "DICE"
    self.diceBtn:initialise()
    self.diceBtn:instantiate()
    self.diceBtn:setDisplayBackground(false)

    self.diceBtn.borderColor = {r=1, g=1, b=1, a=0.1}
    self.diceBtn:ignoreWidthChange()
    self.diceBtn:ignoreHeightChange()
	self:addChild(self.diceBtn)


    self:setPosition()
end

function DiceSystem_MovBtnPanel:setPosition()
    local savedPos = ModData.getOrCreate(DICE_SYSTEM_MOD_STRING .. MOVBTN_STRING)
    if savedPos.x and savedPos.y then
        local x = savedPos.x
        local y = savedPos.y
        local width = getCore():getScreenWidth()
        local height = getCore():getScreenHeight()

        if x + ICON_SIZE > width then x = width - ICON_SIZE end
        if y + ICON_SIZE > height then y = height - ICON_SIZE end

        self:setX(x)
        self:setY(y)
    end
end

function DiceSystem_MovBtnPanel:render()
	if self:isMouseOver() then
        self:drawTextureScaled(self.dragTex, self:getWidth() - 12, 0, 12, 12, 0.5, 1, 1, 1)
	end

    ISPanel.render(self)
end


function DiceSystem_MovBtnPanel:onMouseUp(x, y)
	if self.moving then
        local data = ModData.getOrCreate(DICE_SYSTEM_MOD_STRING .. MOVBTN_STRING)
        -- print('saving position')
        data.x = self.x
        data.y = self.y
	end
	ISPanel.onMouseUp(self, x, y)
end

function DiceSystem_MovBtnPanel:destroyUi()
    self:clearChildren()
    self:close()
    self:removeFromUIManager()
    ISPanel.destroy(self)
end


function DiceSystem_MovBtnPanel:onOptionMouseDown(_btn)
    if DiceMenu.instance then
        self.diceBtn:setImage(self.diceIconOff)
        DiceMenu.ClosePanel()
    else
        self.diceBtn:setImage(self.diceIconOn)
        DiceMenu.OpenPanel(false, getPlayer():getUsername())
     end
end

function DiceSystem_MovBtnPanel.OnResolutionChange()
    if DiceSystem_MovBtnPanel.instance then
        DiceSystem_MovBtnPanel.instance:setPosition()
    end
end

local function CreateMovButton()
    if getPlayer():isDead() then
        return
    end

    local y = getCore():getScreenHeight()/2
    local ui = DiceSystem_MovBtnPanel:new(0, y)
    ui:initialise()
    ui:addToUIManager()



end

-- function DEBUG_CREATE_MOV_BUTTON()
--     CreateMovButton()
-- end


if SandboxVars.PandemoniumDiceSystem.UseMovButton then
    Events.OnGameStart.Add(CreateMovButton)
    Events.OnResolutionChange.Add(DiceSystem_MovBtnPanel.OnResolutionChange)

end
