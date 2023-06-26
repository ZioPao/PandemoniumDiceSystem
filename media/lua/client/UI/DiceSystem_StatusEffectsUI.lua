-- TODO We should use some kind of asynchronous event so that we don't have to use a for in the render func
StatusEffectsUI = ISPanel:derive("StatusEffectsUI")
local PlayerHandler = require("DiceSystem_PlayerHandling")



local COLORS_TABLE = {
    Stable = {r = 0, g = 0.68, b = 0.94},
    Wounded = {r = 0.95, g = 0.35, b = 0.16},
    Bleeding = {r = 0.66, g = 0.15, b = 0.18},
    Prone = {r = 0.04, g = 0.58, b = 0.27},
    Unconscious = {r = 0.57, g = 0.15, b = 0.56}
}


function StatusEffectsUI:render()
    self.zoom = getCore():getZoom(self.player:getPlayerNum())


    --local players = getOnlinePlayers()

    local players = ArrayList.new()
    players:add(getPlayer())

    for i=0, players:size() - 1 do
        local pl = players:get(i)
        if pl then
            local list = PlayerHandler.GetActiveStatusEffectsByUsername(pl:getUsername())

            local baseX = isoToScreenX(pl:getPlayerNum(), pl:getX(), pl:getY(), pl:getZ()) - 150
            local baseY = isoToScreenY(pl:getPlayerNum(), pl:getX(), pl:getY(), pl:getZ()) - (150 / self.zoom)

            local x = baseX
            local y = baseY

            local highestX = 0
            local isSecondLine = false
            for k,v in ipairs(list) do
                local stringToPrint = "[" .. v .. "]"
                if k > 3 and isSecondLine == false then
                    y = y + getTextManager():MeasureStringY(UIFont.NewMedium, stringToPrint)
                    x = baseX
                    isSecondLine = true
                end
                --print("Length: " .. tostring(getTextManager():MeasureStringX(UIFont.Medium, stringToPrint)))
                --print(x)
                --print(v)
                --print("____________")
                local color = COLORS_TABLE[v]
  
                self:drawText(stringToPrint, x - 2, y -2, 0, 0, 0, 0.5, UIFont.NewMedium)
                self:drawText(stringToPrint, x, y, color.r, color.g, color.b, 1, UIFont.NewMedium)
                x = x + getTextManager():MeasureStringX(UIFont.NewMedium, stringToPrint) + 10

                -- if highestX < x then
                --     highestX = x
                -- end
            end

            --self:drawRect(getPlayerScreenWidth(pl:getPlayerNum()) - highestX - 150, y, getPlayerScreenWidth(pl:getPlayerNum()) - highestX - 550,55, 0.3, 0, 0, 0)

        end
    end
end

function StatusEffectsUI:initialise()
	ISPanel.initialise(self)
    self:addToUIManager()
    self:bringToTop()
end

--************************************--

function StatusEffectsUI:new()
    local o = ISPanel:new(0, 0, 0, 0)
	setmetatable(o, self)
	self.__index      = self

    o.player = getPlayer()
	o.zoom                  = 1
	o.visibleTarget			= o
	o:initialise()
	return o
end

--************************************--
-- Setup Status Effects UI
if isClient() then
    local function InitStatusEffectsUI()
        StatusEffectsUI:new()
    end
    Events.OnGameStart.Add(InitStatusEffectsUI)
end