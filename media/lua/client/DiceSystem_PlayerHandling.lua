local StatusEffectsHandler = require("DiceSystem_StatusEffectsHandler")
----------------------

---@alias statusEffectsType {}
---@alias skillsTabType {}
---@alias skillsBonusTabType {}
---@alias diceDataType {isInitialized : boolean, occupation : string, statusEffects : statusEffectsType, currentHealth : number, maxHealth : number, armorBonus : number, currentMovement : number, maxMovement : number, movementBonus : number, allocatedPoints : number, skills : skillsTabType, skillsBonus : skillsBonusTabType}

-- Player data saved locally here

---@type table<string, diceDataType>
DICE_CLIENT_MOD_DATA = {}

---@class PlayerHandler
---@field handlers table
---@field username string
---@field diceData diceDataType
local PlayerHandler = {}
PlayerHandler.handlers = {}

---Instantiate a new Handler or fetch an already existing one
---@param username string
---@return PlayerHandler
function PlayerHandler:instantiate(username)
    if PlayerHandler.handlers[username] then
        return PlayerHandler.handlers[username]
    end

    local o = {}
    setmetatable(o, self)

    o.username = username
    o.diceData = DICE_CLIENT_MOD_DATA[username]

    PlayerHandler.handlers[username] = o
    return o
end

function PlayerHandler:checkDiceDataValidity()
    if DICE_CLIENT_MOD_DATA and self.username and DICE_CLIENT_MOD_DATA[self.username] then
        self.diceData = DICE_CLIENT_MOD_DATA[self.username]
        return true
    else
        print("DICE_CLIENT_MOD_DATA is unavailable for " .. tostring(self.username))
        return false
    end
end

--* Initialization *--

---This is a fairly aggressive way to sync the moddata table. Use it sparingly
---@param username string
local function SyncPlayerTable(username)
    sendClientCommand(getPlayer(), DICE_SYSTEM_MOD_STRING, "UpdatePlayerStats",
        { data = DICE_CLIENT_MOD_DATA[username], username = username })
end

---@return diceDataType
function PlayerHandler:setupModDataTable()
    ---@type diceDataType
    local tempTable = {}
    for k, v in pairs(PLAYER_DICE_VALUES.DEFAULT_MOD_TABLE) do
        tempTable[k] = v
    end
    --print("[DiceSystem] Initializing new player dice data")

    -- Setup status effects
    for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
        local x = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
        tempTable.statusEffects[x] = false
    end

    -- Setup skills
    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local x = PLAYER_DICE_VALUES.SKILLS[i]
        tempTable.skills[x] = 0
        tempTable.skillsBonus[x] = 0
    end

    return tempTable
end

--- Creates a new ModData for a player
---@param force boolean Force initializiation for the current player
function PlayerHandler:initModData(force)
    --print("[DiceSystem] Initializing!")
    if self.username == nil then
        self.username = getPlayer():getUsername()
    end
    -- This should happen only from that specific player, not an admin
    if (DICE_CLIENT_MOD_DATA ~= nil and DICE_CLIENT_MOD_DATA[self.username] == nil) or force then
        -- Do a shallow copy of the table in Data


        local tempTable = self:setupModDataTable()

        DICE_CLIENT_MOD_DATA[self.username] = {}
        copyTable(DICE_CLIENT_MOD_DATA[self.username], tempTable)

        -- Sync it now
        SyncPlayerTable(self.username)
        print("DiceSystem: initialized player")
    elseif DICE_CLIENT_MOD_DATA[self.username] == nil then
        error("DiceSystem: Global mod data is broken")
    end
end

---Set if player has finished their setup via the UI
---@param isInitialized boolean
function PlayerHandler:setIsInitialized(isInitialized)
    -- Syncs it with server
    DICE_CLIENT_MOD_DATA[self.username].isInitialized = isInitialized

    -- Maybe the unique case where this is valid
    if isInitialized then
        SyncPlayerTable(self.username)
    end
end

function PlayerHandler:isPlayerInitialized()
    if DICE_CLIENT_MOD_DATA[self.username] == nil then
        --error("Couldn't find player dice data!")
        return
    end

    local isInit = DICE_CLIENT_MOD_DATA[self.username].isInitialized

    if isInit == nil then
        return false
    end

    return isInit
end

--* Generic Stat Handling *--
--[[
    Stats can be Health or Movement in this version

    Unfortunately, we should have had a table to handle currentValues and maxValues for stats
    instead of putting them directly into DiceData. It would have made things a lot more clean,
    but it is how it is.
]]


---@param stat string
---@return integer
function PlayerHandler:getCurrentStat(stat)
    if not self:checkDiceDataValidity() then return -1 end
    return DICE_CLIENT_MOD_DATA[self.username]["current" .. stat]
end

---@param stat string
---@return integer
function PlayerHandler:getMaxStat(stat)
    if not self:checkDiceDataValidity() then return -1 end
    return DICE_CLIENT_MOD_DATA[self.username]["max" .. stat]
end

---Some stat could have a bonus value, some others don't
---@param stat string
---@return number
function PlayerHandler:getBonusStat(stat)
    if not self:checkDiceDataValidity() then return -1 end

    local bonusStatStr = string.lower(stat) .. "Bonus"
    if self.diceData[bonusStatStr] then
        return self.diceData[bonusStatStr]
    end

    return 0
end

---@param stat string
---@param val number
function PlayerHandler:setBonusStat(stat, val)
    if not self:checkDiceDataValidity() then return end
    local bonusStatStr = string.lower(stat) .. "Bonus"

    DICE_CLIENT_MOD_DATA[self.username][bonusStatStr] = val
end

---@param stat string
---@return boolean
function PlayerHandler:increaseStat(stat)
    local currStatStr = "current" .. stat
    local maxStatStr = "max" .. stat

    if self.diceData[currStatStr] < self.diceData[maxStatStr] + self:getBonusStat(stat) then
        self.diceData[currStatStr] = self.diceData[currStatStr] + 1
        return true
    end

    return false
end

function PlayerHandler:decreaseStat(stat)
    local currStatStr = "current" .. stat

    if self.diceData[currStatStr] > 0 then
        self.diceData[currStatStr] = self.diceData[currStatStr] - 1
        return true
    end

    return false
end

---@param stat string
---@param operation string
function PlayerHandler:handleStat(stat, operation)
    local result = false


    if operation == "+" then
        result = self:increaseStat(stat)
    elseif operation == "-" then
        result = self:decreaseStat(stat)
    end

    if result and DICE_CLIENT_MOD_DATA[self.username].isInitialized then
        local currStatStr = "current" .. stat
        local currentVal = self.diceData[currStatStr]

        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateCurrentStat',
            { stat = stat, currentVal = currentVal, username = self.username })
    end
end

--*  Skills handling *--

---Return skill points + bonus skill points
---@param skill string
---@return number
function PlayerHandler:getFullSkillPoints(skill)
    local points = self.diceData.skills[skill]
    local bonusPoints = self.diceData.skillsBonus[skill]

    return points + bonusPoints
end

---Get the amount of points for a specific skill.
---@param skill string
---@return number
function PlayerHandler:getSkillPoints(skill)
    if self.diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local points = self.diceData.skills[skill]
    if points ~= nil then
        return points
    else
        return -1
    end
end

---Get the amount of bonus points for a specific skill.
---@param skill string
---@return number
function PlayerHandler:getBonusSkillPoints(skill)
    if self.diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local points = self.diceData.skillsBonus[skill]
    if points ~= nil then
        return points
    else
        return -1
    end
end

---Increment a specific skillpoint
---@param skill string
---@return boolean
function PlayerHandler:incrementSkillPoint(skill)
    local result = false

    -- TODO Make this customizable from DATA
    if self.diceData.allocatedPoints < PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS and self.diceData.skills[skill] < PLAYER_DICE_VALUES.MAX_PER_SKILL_ALLOCATED_POINTS then
        self.diceData.skills[skill] = self.diceData.skills[skill] + 1
        self.diceData.allocatedPoints = self.diceData.allocatedPoints + 1
        result = true
    end

    return result
end

---Decrement a specific skillpoint
---@param skill string
---@return boolean
function PlayerHandler:decrementSkillPoint(skill)
    local result = false

    -- TODO Make this customizable from DATA

    if self.diceData.skills[skill] > 0 then
        self.diceData.skills[skill] = self.diceData.skills[skill] - 1
        self.diceData.allocatedPoints = self.diceData.allocatedPoints - 1
        result = true
    end

    return result
end

---Add or subtract to any skill point for this user
---@param skill any
---@param operation any
---@return boolean
function PlayerHandler:handleSkillPoint(skill, operation)
    local result = false

    if operation == "+" then
        result = self:incrementSkillPoint(skill)
    elseif operation == "-" then
        result = self:decrementSkillPoint(skill)
    end

    -- In case of failure, just return.
    if not result then return false end

    --* Special cases

    -- Movement Bonus scales in Deft
    self:handleSkillPointSpecialCases(skill)
    return result
end

---@param skill string
function PlayerHandler:handleSkillPointSpecialCases(skill)
    if skill == 'Deft' then
        local actualPoints = self:getSkillPoints(skill)
        local bonusPoints = self:getBonusSkillPoints(skill)
        self:setMovementBonus(actualPoints, bonusPoints)
    end
end

---Get Allocated Skill points
---@return integer
function PlayerHandler:getAllocatedSkillPoints()
    if self.diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local allocatedPoints = self.diceData.allocatedPoints
    if allocatedPoints ~= nil then return allocatedPoints else return -1 end
end

--* Occupations *--

---Returns the player's occupation
---@return string
function PlayerHandler:getOccupation()
    -- This is used in the prerender for our special combobox. We'll add a bit of added logic to be sure that it doesn't break
    if not self:checkDiceDataValidity() then return "" end

    return DICE_CLIENT_MOD_DATA[self.username].occupation
end

---Set an occupation and its related bonuses
---@param occupation string
function PlayerHandler:setOccupation(occupation)
    --print("Setting occupation")
    --print(PlayerStatsHandler.username)
    if self.diceData == nil then return end

    --print("Setting occupation => " .. occupation)
    self.diceData.occupation = occupation
    local bonusData = PLAYER_DICE_VALUES.OCCUPATIONS_BONUS[occupation]

    -- Reset diceData.skillBonus
    for k, _ in pairs(self.diceData.skillsBonus) do
        self.diceData.skillsBonus[k] = 0
    end

    for key, bonus in pairs(bonusData) do
        self.diceData.skillsBonus[key] = bonus
    end
end

--* Status Effects *--

---@param statusEffect string
function PlayerHandler:toggleStatusEffectValue(statusEffect)
    -- Add a check in the UI to make it clear that we have selected them or something
    if self.diceData.statusEffects[statusEffect] ~= nil then
        self.diceData.statusEffects[statusEffect] = not self.diceData.statusEffects[statusEffect]
    end

    -- We need to force set an update since this is gonna be visible to all players!
    local isActive = self.diceData.statusEffects[statusEffect]
    local pl = getPlayerFromUsername(self.username)
    local userID = nil
    if pl then
        userID = pl:getOnlineID()
    end

    sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateStatusEffect',
        { username = self.username, userID = userID, statusEffect = statusEffect, isActive = isActive })
end

---Get the status effect value
---@param status string
---@return boolean
function PlayerHandler:getStatusEffectValue(status)
    local val = DICE_CLIENT_MOD_DATA[self.username].statusEffects[status]
    --print("Status: " .. status .. ",value: " .. tostring(val))
    return val
end

---Returns current health
---@return number
function PlayerHandler:getCurrentHealth()
    return self:getCurrentStat("Health")
end

---@return number
function PlayerHandler:getMaxHealth()
    return self:getMaxStat("Health")
end

--* Movement *--

---Returns current movmenet
---@return number
function PlayerHandler:getCurrentMovement()
    return self:getCurrentStat("Movement")
end

---Returns the max movement value
---@return number
function PlayerHandler:getMaxMovement()
    return self:getMaxStat("Movement")
end

---Get the movement bonus
---@return number
function PlayerHandler:getMovementBonus()
    return self:getBonusStat("Movement")
end

---Set the correct Movement Bonus to the player data
---@param points number
---@param bonusPoints number
function PlayerHandler:setMovementBonus(points, bonusPoints)
    local movBonus = math.floor((points + bonusPoints) / 2)
    self:setBonusStat("Movement", movBonus)
end

function PlayerHandler:setCurrentMovement(movement)
    DICE_CLIENT_MOD_DATA[self.username].currentMovement = movement
end

---Set the new correct max movement
---@param maxMov number
function PlayerHandler:setMaxMovement(maxMov)
    DICE_CLIENT_MOD_DATA[self.username].maxMovement = maxMov
    local movBonus = self:getMovementBonus()

    if self:getCurrentMovement() > maxMov + movBonus then
        DICE_CLIENT_MOD_DATA[self.username].currentMovement = maxMov + movBonus
    end
end

--* Armor Bonus

--- Returns the current value of armor bonus
---@return number
function PlayerHandler:getArmorBonus()
    return self:getBonusStat("Armor")
end

-----------------------
--* Static functions *--

---Get a certain player active status effects from the cache
---@param username string
---@return table
function PlayerHandler.GetActiveStatusEffectsByUsername(username)
    local pl = getPlayerFromUsername(username)

    if pl then
        local plID = pl:getOnlineID()
        local effectsTable = StatusEffectsHandler.nearPlayersStatusEffects[plID]
        if effectsTable == nil then return {} else return effectsTable end
    end

    return {}
end

---Start cleaning process for a specific user. ADMIN ONLY!
---@param userID number
---@param username string
function PlayerHandler.CleanModData(userID, username)
    sendClientCommand(DICE_SYSTEM_MOD_STRING, "ResetServerDiceData", { userID = userID, username = username })
end

---Check if player is initialized and ready to use the system
---@param username string
---@return boolean
PlayerHandler.CheckInitializedStatus = function(username)
    if DICE_CLIENT_MOD_DATA[username] then
        return DICE_CLIENT_MOD_DATA[username].isInitialized
    else
        return false
    end
end


---Calculate the current armor bonus. Must be run ONLY on that specific client!
---@param pl IsoPlayer local player
---@return boolean
function PlayerHandler.CalculateArmorBonus(pl)
    --!!! This could be run on any client.
    if pl == nil then return false end
    if pl ~= getPlayer() then return false end
    local username = getPlayer():getUsername()
    local handler = PlayerHandler:instantiate(username)


    if DICE_CLIENT_MOD_DATA == nil or DICE_CLIENT_MOD_DATA[username] == nil then return false end
    local wornItems = pl:getWornItems()
    local tempProtection = 0
    for i = 1, wornItems:size() do
        ---@type InventoryItem
        local item = wornItems:get(i - 1):getItem()
        if instanceof(item, "Clothing") then
            ---@cast item Clothing
            tempProtection = tempProtection + item:getBulletDefense()
        end
    end

    -- Calculate the armor bonus
    local armorBonus = math.floor(tempProtection / 100)
    if armorBonus < 0 then armorBonus = 0 end

    -- Hard cap it at 3
    if armorBonus > 3 then armorBonus = 3 end


    -- TODO Cache old armor bonus before updating it

    -- Set the correct amount of armor bonus
    DICE_CLIENT_MOD_DATA[username].armorBonus = armorBonus

    -- We need to scale the movement accordingly
    local maxMov = PLAYER_DICE_VALUES.DEFAULT_MOVEMENT - armorBonus
    handler:setMaxMovement(maxMov)

    -- TODO Cache old max movement before updating it
    if handler:isPlayerInitialized() then
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateArmorBonus', { armorBonus = armorBonus, username = username })
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateMaxMovement', { maxMovement = maxMov, username = username })
    end

    return true
end

------------------------
--* Various events handling
Events.OnGameStart.Add(function()
    local handler = PlayerHandler:instantiate(getPlayer():getUsername())
    handler:initModData(false)
end)
Events.OnClothingUpdated.Add(PlayerHandler.CalculateArmorBonus)



--------------------------------
--* Global mod data *--

---Ask ModData from server
local function OnConnected()
    print("Requested global mod data")
    ModData.request(DICE_SYSTEM_MOD_STRING)
    DICE_CLIENT_MOD_DATA = ModData.get(DICE_SYSTEM_MOD_STRING)

    if DICE_CLIENT_MOD_DATA == nil then
        DICE_CLIENT_MOD_DATA = {}
    end
end

Events.OnConnected.Add(OnConnected)

local function copyTable(tableA, tableB)
    if not tableA or not tableB then
        return
    end
    for key, value in pairs(tableB) do
        tableA[key] = value
    end
    for key, _ in pairs(tableA) do
        if not tableB[key] then
            tableA[key] = nil
        end
    end
end

---Receives ModData from server
---@param key string
---@param data table
local function ReceiveGlobalModData(key, data)
    --print("Received global mod data")
    if key == DICE_SYSTEM_MOD_STRING then
        --Creating a deep copy of recieved data and storing it in local store CLIENT_GLOBALMODDATA table
        copyTable(DICE_CLIENT_MOD_DATA, data)
    end

    --Update global mod data with local table (from global_mod_data.bin)
    ModData.add(DICE_SYSTEM_MOD_STRING, DICE_CLIENT_MOD_DATA)
end
Events.OnReceiveGlobalModData.Add(ReceiveGlobalModData)

--------------------------------

return PlayerHandler
