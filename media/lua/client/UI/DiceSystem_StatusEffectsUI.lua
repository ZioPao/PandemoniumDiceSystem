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

-----------------

---Zomboid doesn't really DistTo. So let's have a wrapper to prevent errors
---@param localPlayer IsoPlayer
---@param onlinePlayer IsoPlayer
---@return number
local function TryDistTo(localPlayer, onlinePlayer)
    local dist = 10000000000 -- Fake number, just to prevent problems later.
    if localPlayer and onlinePlayer then
        if onlinePlayer:getCurrentSquare() ~= nil then
            dist = localPlayer:DistTo(onlinePlayer)
        end
    end

    return dist
end



------------------

StatusEffectsUI = ISPanel:derive("StatusEffectsUI")
StatusEffectsUI.nearPlayersStatusEffects = {}

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

    -- Init a table where we're gonna cache the status effects from nearby players
    StatusEffectsUI.nearPlayersStatusEffects = {}

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
    local statusEffectsTable = StatusEffectsUI.nearPlayersStatusEffects

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
        if pl and TryDistTo(self.player, pl) < StatusEffectsUI.renderDistance then
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

---Used to update the local status effects table
---@param userID number
---@param statusEffects table
function StatusEffectsUI.UpdateLocalStatusEffectsTable(userID, statusEffects)
    StatusEffectsUI.mainPlayer = getPlayer()
    local receivedPlayer = getPlayerByOnlineID(userID)
    local dist = TryDistTo(StatusEffectsUI.mainPlayer, receivedPlayer)
    if dist < StatusEffectsUI.renderDistance then
        StatusEffectsUI.nearPlayersStatusEffects[userID] = {}
        local newStatusEffectsTable = {}
        for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
            local x = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
            if statusEffects[x] ~= nil and statusEffects[x] == true then
                --print(x)
                table.insert(newStatusEffectsTable, x)
            end
        end

        if table.concat(newStatusEffectsTable) ~= table.concat(StatusEffectsUI.nearPlayersStatusEffects[userID]) then
            --print("Changing table! Some stuff is different")
            StatusEffectsUI.nearPlayersStatusEffects[userID] = newStatusEffectsTable
            --else
            --print("Same effects! No change needed")
        end
    else
        StatusEffectsUI.nearPlayersStatusEffects[userID] = {}
    end
end

---Set the colors table. Used to handle colorblind option
---@param colors table r,g,b
function StatusEffectsUI.SetColorsTable(colors)
    StatusEffectsUI.colorsTable = colors
end

---Set the Y offset for the status effects on top of the players heads
---@param offset number
function StatusEffectsUI.SetUserOffset(offset)
    StatusEffectsUI.userOffset = offset
end

---Returns the y offset for status effects
---@return number
function StatusEffectsUI.GetUserOffset()
    return StatusEffectsUI.userOffset
end

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
