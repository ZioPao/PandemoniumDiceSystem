local StatusEffectsHandler = require("DiceSystem_StatusEffectsHandler")
local CommonMethods = require("DiceSystem_CommonMethods")
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
    DiceSystem_Common.DebugWriteLog("Instantiating PlayerHandler for user: " .. username)
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
        DiceSystem_Common.DebugWriteLog("DICE_CLIENT_MOD_DATA is unavailable for " .. tostring(self.username))
        return false
    end
end

--* Initialization *--

---This is a fairly aggressive way to sync the moddata table. Use it sparingly
function PlayerHandler:syncPlayerTable()
    sendClientCommand(getPlayer(), DICE_SYSTEM_MOD_STRING, "UpdatePlayerStats",
        { data = DICE_CLIENT_MOD_DATA[self.username], username = self.username })
end

---Exec a deep copy of DEFAULT_MOD_TABLE to the user mod data
---@return diceDataType
function PlayerHandler:setupModDataTable()
    ---@type diceDataType
    local tempTable = CommonMethods.DeepCopy(PLAYER_DICE_VALUES.DEFAULT_MOD_TABLE)
    --DiceSystem_Common.DebugWriteLog"[DiceSystem] Initializing new player dice data")

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
    --DiceSystem_Common.DebugWriteLog"[DiceSystem] Initializing!")
    if self.username == nil then
        self.username = getPlayer():getUsername()
    end
    -- This should happen only from that specific player, not an admin
    if (DICE_CLIENT_MOD_DATA ~= nil and DICE_CLIENT_MOD_DATA[self.username] == nil) or force then
        -- Do a shallow copy of the table in Data


        local tempTable = self:setupModDataTable()

        DICE_CLIENT_MOD_DATA[self.username] = {}
        copyTable(DICE_CLIENT_MOD_DATA[self.username], tempTable)

        -- Sync it now with the server
        self:syncPlayerTable()

        DiceSystem_Common.DebugWriteLog("Initialized player")
    elseif DICE_CLIENT_MOD_DATA[self.username] == nil then
        error("DiceSystem: Global mod data is broken")
    end
end

---Set if player has finished their setup via the UI
---@param isInitialized boolean
function PlayerHandler:setIsInitialized(isInitialized)
    self.diceData.isInitialized = isInitialized
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
    return self.diceData["current" .. stat]
end

---@param stat string
---@return integer
function PlayerHandler:getMaxStat(stat)
    if not self:checkDiceDataValidity() then return -1 end
    return self.diceData["max" .. stat]
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

    self.diceData[bonusStatStr] = val
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

    if result and self.diceData.isInitialized then
        local currStatStr = "current" .. stat
        local currentVal = self.diceData[currStatStr]

        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateCurrentStat',
            { stat = stat, currentVal = currentVal, username = self.username })
    end
end

--* Special cases for stats, armor *--

---Used to calculate armor bonus
---@param player IsoPlayer
---@return number
---@private
function PlayerHandler:calculateWornItemsProtection(player)
    local wornItems = player:getWornItems()
    local protection = 0
    for i = 1, wornItems:size() do
        ---@type InventoryItem
        local item = wornItems:get(i - 1):getItem()
        if instanceof(item, "Clothing") then
            ---@cast item Clothing
            protection = protection + item:getBulletDefense()
        end
    end

    return protection
end

---Should run ONLY on the actual client, not from admins or other players
---@return boolean
function PlayerHandler:handleArmorBonus()
    local pl = getPlayer()
    if self.username ~= pl:getUsername() then return false end
    if not self:checkDiceDataValidity() then return false end

    local protection = self:calculateWornItemsProtection(pl)

    -- Calculate the armor bonus
    local armorBonus = math.floor(protection / 100)
    if armorBonus < 0 then armorBonus = 0 end

    -- Hard cap it at 3
    if armorBonus > PLAYER_DICE_VALUES.MAX_ARMOR_BONUS then armorBonus = PLAYER_DICE_VALUES.MAX_ARMOR_BONUS end


    -- TODO Cache old armor bonus before updating it

    -- Set the correct amount of armor bonus
    self:setBonusStat("Armor", armorBonus)


    if self:isPlayerInitialized() then
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateArmorBonus',
            { armorBonus = armorBonus, username = self.username })
    end

    return true
end

--*  Skills handling *--

---Return skill points + bonus skill points
---@param skill string
---@return number
function PlayerHandler:getFullSkillPoints(skill)
    local points = self:getSkillPoints(skill)
    local bonusPoints = self:getBonusSkillPoints(skill)
    local specialPoints = self:getSpecialSkillPoints(skill)


    if points ~= -1 and bonusPoints ~= -1 then
        return points + bonusPoints + specialPoints
    else
        return -1
    end
end

---Specific case for Resolve, it should scale on armor bonus
---@param skill string
function PlayerHandler:getSpecialSkillPoints(skill)
    local specialPoints = 0
    if skill == "Resolve" then
        specialPoints = self:getBonusStat("Armor")
    end

    return specialPoints
end

---Get the amount of points for a specific skill.
---@param skill string
---@return number
function PlayerHandler:getSkillPoints(skill)
    if not self:checkDiceDataValidity() then return -1 end
    return self.diceData.skills[skill]
end

---Get the amount of bonus points for a specific skill.
---@param skill string
---@return number
function PlayerHandler:getBonusSkillPoints(skill)
    if not self:checkDiceDataValidity() then return -1 end
    return self.diceData.skillsBonus[skill]
end

---Increment a specific skillpoint
---@param skill string
---@return boolean
function PlayerHandler:increaseSkillPoint(skill)
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
function PlayerHandler:decreaseSkillPoint(skill)
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
        result = self:increaseSkillPoint(skill)
    elseif operation == "-" then
        result = self:decreaseSkillPoint(skill)
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
        --DiceSystem_Common.DebugWriteLog"DiceSystem: modData is nil, can't return skill point value")
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
    return self.diceData.occupation
end

---Set an occupation and its related bonuses
---@param occupation string
function PlayerHandler:setOccupation(occupation)
    --DiceSystem_Common.DebugWriteLog"Setting occupation")
    --DiceSystem_Common.DebugWriteLogPlayerStatsHandler.username)
    if self.diceData == nil then return end

    --DiceSystem_Common.DebugWriteLog"Setting occupation => " .. occupation)
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
    local val = self.diceData.statusEffects[status]
    --DiceSystem_Common.DebugWriteLog"Status: " .. status .. ",value: " .. tostring(val))
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

---Get total health (max + bonuses, if there are any)
---@return number
function PlayerHandler:getTotalHealth()
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

---Returns the max movement value + bonuses
---@return number
function PlayerHandler:getTotalMovement()
    return self:getMaxStat("Movement") + self:getMovementBonus() - self:getArmorBonus()
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
    self.diceData.currentMovement = movement
end

---Set the new correct max movement
---@param maxMov number
function PlayerHandler:setMaxMovement(maxMov)
    self.diceData.maxMovement = maxMov
    local movBonus = self:getMovementBonus()

    if self:getCurrentMovement() > maxMov + movBonus then
        self:setCurrentMovement(maxMov + movBonus)
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
function PlayerHandler.CheckInitializedStatus(username)
    if DICE_CLIENT_MOD_DATA[username] then
        return DICE_CLIENT_MOD_DATA[username].isInitialized
    else
        return false
    end
end

------------------------
--* Various events handling
Events.OnGameStart.Add(function()
    --DiceSystem_Common.DebugWriteLog"Initializing with OnGameStart")

    DiceSystem_Common.DebugWriteLog("PDRPDS v" .. tostring(DICE_SYSTEM_MOD_VERSION))

    for i=1, #DICE_SYSTEM_MOD_ADDONS do
        local addonTab = DICE_SYSTEM_MOD_ADDONS[i]
        DiceSystem_Common.DebugWriteLog("ADDON: " .. tostring(addonTab.name) .. " v" .. tostring(addonTab.version))
    end


    local handler = PlayerHandler:instantiate(getPlayer():getUsername())
    handler:initModData(false)
    local os_time = os.time
    local sTime = os_time()

    local function HandleArmorBonusAtStartup()
        local cTime = os_time()

        if cTime > sTime + 5 then
            handler:handleArmorBonus() -- Armor bonus must be calculated here
            Events.OnTick.Remove(HandleArmorBonusAtStartup)
        end


    end

    Events.OnTick.Add(HandleArmorBonusAtStartup)

end)

-- Static version of handleArmorBonus
Events.OnClothingUpdated.Add(function(pl)
    if pl ~= getPlayer() then return end

    ---@cast pl IsoPlayer

    local handler = PlayerHandler:instantiate(pl:getUsername())
    handler:handleArmorBonus() -- Armor bonus must be calculated here
end)



--------------------------------
--* Global mod data *--

---Ask ModData from server
local function OnConnected()
    ModData.request(DICE_SYSTEM_MOD_STRING)
    DICE_CLIENT_MOD_DATA = ModData.get(DICE_SYSTEM_MOD_STRING)

    if DICE_CLIENT_MOD_DATA == nil then
        DICE_CLIENT_MOD_DATA = {}
    end
end

Events.OnConnected.Add(OnConnected)


---Receive ModData from server
---@param key string
---@param data table
local function ReceiveGlobalModData(key, data)
    -- TODO Test if everything is correct, we used a copyTable here but I'm not sure if it was necessary
    -- Why the fuck are we even doing a copy table here?
    if key ~= DICE_SYSTEM_MOD_STRING then return end

    DICE_CLIENT_MOD_DATA = data     -- assign received data to a local reference

    --Update global mod data with local table (from global_mod_data.bin)
    ModData.add(DICE_SYSTEM_MOD_STRING, DICE_CLIENT_MOD_DATA)
end
Events.OnReceiveGlobalModData.Add(ReceiveGlobalModData)

--------------------------------

return PlayerHandler
