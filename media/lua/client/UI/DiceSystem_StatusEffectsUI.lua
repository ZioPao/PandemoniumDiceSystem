-- Caching stuff
local getOnlinePlayers = getOnlinePlayers
local playerBase = __classmetatables[IsoPlayer.class].__index
local getNum = playerBase.getPlayerNum
local getUsername = playerBase.getUsername
local getOnlineID = playerBase.getOnlineID
local getX = playerBase.getX
local getY = playerBase.getY
local getZ = playerBase.getZ
local isoToScreenX = isoToScreenX
local isoToScreenY = isoToScreenY
local debugWriteLog = DiceSystem_Common.DebugWriteLog
local os_time = os.time

local UPDATE_DELAY = SandboxVars.PandemoniumDiceSystem.DelayUpdateStatusEffects
local StatusEffectsHandler = require("DiceSystem_StatusEffectsHandler")
-----------------

---@class StatusEffectsUI : ISPanel
local StatusEffectsUI = ISPanel:derive("StatusEffectsUI")

--************************************--

function StatusEffectsUI:new()
    local o = ISPanel:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index    = self

    o.player        = getPlayer()
    o.zoom          = 1
    o.visibleTarget = o
    o:setAlwaysOnTop(false)
    o:initialise()

    return o
end

--************************************--

---Initialization
function StatusEffectsUI:initialise()
    ISPanel.initialise(self)
    self:addToUIManager()

    self.currPlayerUsername = self.player:getUsername()
    self.sTime = os_time()
    self.onlinePlayers = getOnlinePlayers()
    self.requestsCounter = {} -- This is to prevent a spam of syncs from users who did not initialize the mod.

end

---Render loop
function StatusEffectsUI:render()
    if DICE_CLIENT_MOD_DATA == nil or DICE_CLIENT_MOD_DATA[self.currPlayerUsername] == nil then return end
    if DICE_CLIENT_MOD_DATA[self.currPlayerUsername].isInitialized == false then return end

    self.zoom = getCore():getZoom(self.player:getPlayerNum())
    local statusEffectsTable = StatusEffectsHandler.nearPlayersStatusEffects

    -- Check timer and update if it's over
    local cTime = os_time()
    local shouldUpdate = false
    if cTime > self.sTime + UPDATE_DELAY then
        shouldUpdate = true
        self.onlinePlayers = getOnlinePlayers()
        self.sTime = os_time()
    end

    for i = 0, self.onlinePlayers:size() - 1 do
        local pl = self.onlinePlayers:get(i)
        -- When servers are overloaded, it seems like they like to make players "disappear". That means they exists, but they're not
        -- in any square. This causes a bunch of issues here, since it needs to access getCurrentSquare in checkCanSeeClient
        if pl and StatusEffectsHandler.TryDistTo(self.player, pl) < StatusEffectsUI.renderDistance then
            local userID = getOnlineID(pl)
            if shouldUpdate then
                local username = getUsername(pl)
                --print("Updating for " ..username)
                --print("Requesting update for " .. pl:getUsername())
                sendClientCommand(DICE_SYSTEM_MOD_STRING, 'RequestUpdatedStatusEffects',
                    { username = username, userID = userID })
            end

            -- Player is visible and their data is present locally
            if self.player:checkCanSeeClient(pl) and statusEffectsTable[userID] then
                self:drawStatusEffect(pl, statusEffectsTable[userID])
            end
        end
    end
end

---Set the Y offset for the status effects on top of the players heads
---@param offset number
function StatusEffectsUI.SetUserOffset(offset)
    StatusEffectsUI.userOffset = offset
end

---Returns the y offset for status effects
---@return number
function StatusEffectsUI.GetUserOffset()
    return StatusEffectsUI.userOffset or 0
end


---Main function ran during the render loop
---@param pl IsoPlayer
---@param statusEffects table
function StatusEffectsUI:drawStatusEffect(pl, statusEffects)
    local plNum = getNum(pl)
    local plX = getX(pl)
    local plY = getY(pl)
    local plZ = getZ(pl)
    local baseX = isoToScreenX(plNum, plX, plY, plZ) - 100
    local baseY = isoToScreenY(plNum, plX, plY, plZ) - (150 / self.zoom) - 50 + StatusEffectsUI.GetUserOffset()

    local x = baseX
    local y = baseY

    local lineCounter = 0

    -- TODO Can't go any more than two lines.
    for k = 1, #statusEffects do
        local v = statusEffects[k]

        -- OPTIMIZE This part could be cached if we wanted.
        local stringToPrint = string.format("[%s]", v)
        --print(stringToPrint)

        if lineCounter >= 3 then
            y = y + getTextManager():MeasureStringY(UIFont.NewMedium, stringToPrint)
            x = baseX
            lineCounter = 0
        end

        local color = DiceSystem_Common.statusEffectsColors[v]

        -- The first DrawText is to simulate a drop shadow to help readability
        self:drawText(stringToPrint, x - 2, y - 2, 0, 0, 0, 0.5, UIFont.NewMedium)
        self:drawText(stringToPrint, x, y, color.r, color.g, color.b, 1, UIFont.NewMedium)
        x = x + getTextManager():MeasureStringX(UIFont.NewMedium, stringToPrint) + 10
        lineCounter = lineCounter + 1

    end
end

----------------------
-- Static functions, to be used to set stuff from external sources

--************************************--
-- Setup Status Effects UI
if isClient() then
    local function InitStatusEffectsUI()
        StatusEffectsUI.renderDistance = SandboxVars.PandemoniumDiceSystem.RenderDistanceStatusEffects
        StatusEffectsUI:new()
    end

    if SandboxVars.PandemoniumDiceSystem.ShowStatusEffects then
        Events.OnGameStart.Add(InitStatusEffectsUI)
    end
end
