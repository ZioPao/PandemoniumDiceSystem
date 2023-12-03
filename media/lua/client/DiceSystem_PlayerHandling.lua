-- Player data saved locally here
DICE_CLIENT_MOD_DATA = {}

local PlayerStatsHandler = {}


--------------------------------
--* Global mod data *--

function OnConnected()
    print("Requested global mod data")
    ModData.request(DICE_SYSTEM_MOD_STRING)
    DICE_CLIENT_MOD_DATA = ModData.get(DICE_SYSTEM_MOD_STRING)

    if DICE_CLIENT_MOD_DATA == nil then
        DICE_CLIENT_MOD_DATA = {}
    else
        print("Found DICE_SYSTEM global mod data, sent it to client")
        print(DICE_CLIENT_MOD_DATA)
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




---This is a fairly aggressive way to sync the moddata table. Use it sparingly
---@param username any
local function SyncPlayerTable(username)
    sendClientCommand(getPlayer(), DICE_SYSTEM_MOD_STRING, "UpdatePlayerStats",
        { data = DICE_CLIENT_MOD_DATA[username], username = username })
end

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



--*  Skills handling *--

PlayerStatsHandler.GetFullSkillPoints = function(skill)
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    local points = diceData.skills[skill]
    local bonusPoints = diceData.skillsBonus[skill]

    -- TODO We must account better for this kind of stuff
    if skill == "Resolve" then
        bonusPoints = bonusPoints + diceData.armorBonus
    end

    return points + bonusPoints
end

---Get the amount of points for a specific skill.
---@param skill string
---@return number
PlayerStatsHandler.GetSkillPoints = function(skill)
    --print("DiceSystem: playerHandler searching for skill " .. skill)
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local points = diceData.skills[skill]
    if points ~= nil then
        return points
    else
        return -1
    end
end

PlayerStatsHandler.HandleSkillPoint = function(skill, operation)
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    local result = false

    if operation == "+" then
        result = PlayerStatsHandler.IncrementSkillPoint(diceData, skill)
    elseif operation == "-" then
        result = PlayerStatsHandler.DecrementSkillPoint(diceData, skill)
    end

    -- In case of failure, just return.
    if not result then return end

    --* Special cases

    -- Movement Bonus scales in Deft
    if skill == 'Deft' then
        local actualPoints = PlayerStatsHandler.GetSkillPoints(skill)
        local bonusPoints = PlayerStatsHandler.GetBonusSkillPoints(skill)
        PlayerStatsHandler.ApplyMovementBonus(actualPoints, bonusPoints)
    end

    -- DO NOT SYNC THIS!
    -- Sync it, even when it's not initialized, to prevent issues when other players
    -- send an updated mod data and our local player hasn't been initialized yet
   -- statsTable[PlayerStatsHandler.username].
    --sendClientCommand(DICE_SYSTEM_MOD_STRING, '')
    --SyncTable(PlayerStatsHandler.username)

    return result
end


---Increment a specific skillpoint
---@param diceData table
---@param skill string
---@return boolean
PlayerStatsHandler.IncrementSkillPoint = function(diceData, skill)
    local result = false

    if diceData.allocatedPoints < 20 and diceData.skills[skill] < 5 then
        diceData.skills[skill] = diceData.skills[skill] + 1
        diceData.allocatedPoints = diceData.allocatedPoints + 1
        result = true
    end

    return result
end

---Decrement a specific skillpoint
---@param diceData table
---@param skill string
---@return boolean
PlayerStatsHandler.DecrementSkillPoint = function(diceData, skill)
    local result = false
    if diceData.skills[skill] > 0 then
        diceData.skills[skill] = diceData.skills[skill] - 1
        diceData.allocatedPoints = diceData.allocatedPoints - 1
        result = true
    end

    return result
end

PlayerStatsHandler.GetBonusSkillPoints = function(skill)
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local points = diceData.skillsBonus[skill]
    if points ~= nil then
        return points
    else
        return -1
    end
end

PlayerStatsHandler.GetAllocatedSkillPoints = function()
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]

    if diceData == nil then
        --print("DiceSystem: modData is nil, can't return skill point value")
        return -1
    end

    local allocatedPoints = diceData.allocatedPoints
    if allocatedPoints ~= nil then return allocatedPoints else return -1 end
end

--* Occupations *--

---Returns the player's occupation
---@return string
PlayerStatsHandler.GetOccupation = function()
    -- This is used in the prerender for our special combobox. We'll add a bit of added logic to be sure that it doesn't break
    if DICE_CLIENT_MOD_DATA and PlayerStatsHandler.username and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].occupation
    end

    return ""
end

---Set an occupation and its related bonuses
---@param occupation string
PlayerStatsHandler.SetOccupation = function(occupation)
    --print("Setting occupation")
    --print(PlayerStatsHandler.username)
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData == nil then return end

    --print("Setting occupation => " .. occupation)
    diceData.occupation = occupation
    local bonusData = PLAYER_DICE_VALUES.OCCUPATIONS_BONUS[occupation]

    -- Reset diceData.skillBonus
    for k, v in pairs(diceData.skillsBonus) do
        diceData.skillsBonus[k] = 0
    end

    for key, bonus in pairs(bonusData) do
        diceData.skillsBonus[key] = bonus
    end
end

--* Status Effect *--
PlayerStatsHandler.ToggleStatusEffectValue = function(statusEffect)
    -- Add a check in the UI to make it clear that we have selected them or something
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData.statusEffects[statusEffect] ~= nil then
        diceData.statusEffects[statusEffect] = not diceData.statusEffects[statusEffect]
    end

    -- We need to force set an update since this is gonna be visible to all players!
    local isActive = diceData.statusEffects[statusEffect]
    local pl = getPlayerFromUsername(PlayerStatsHandler.username)
    local userID = nil
    if pl then
        userID = pl:getOnlineID()
    end

    sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateStatusEffect', {username = PlayerStatsHandler.username, userID = userID, statusEffect = statusEffect, isActive = isActive })
    --SyncPlayerTable(PlayerStatsHandler.username)
    
    --print("Setting occupation => " .. occupation)
end

PlayerStatsHandler.GetStatusEffectValue = function(status)
    local val = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].statusEffects[status]
    --print("Status: " .. status .. ",value: " .. tostring(val))
    return val
end

-- -- TODO This should be deleted and we should use GetActiveStatusEffectsByUsername
-- ---Returns the currently active status effects 
-- ---@return table
-- PlayerStatsHandler.GetActiveStatusEffects = function()
--     local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
--     local statusEffects = diceData.statusEffects
--     local list = {}
--     for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
--         local x = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
--         if statusEffects[x] ~= nil and statusEffects[x] == true then
--             table.insert(list, x)
--         end
--     end

--     return list
-- end

---Get a certain player active status effects from the cache
---@return table
PlayerStatsHandler.GetActiveStatusEffectsByUsername = function(username)
    local pl = getPlayerFromUsername(username)

    if pl then
        local plID = pl:getOnlineID()
        local effectsTable = StatusEffectsUI.nearPlayersStatusEffects[plID]
        if effectsTable == nil then return {} else return effectsTable end
    end

    return {}
end


--* Health *--
PlayerStatsHandler.GetCurrentHealth = function()
    if DICE_CLIENT_MOD_DATA and PlayerStatsHandler.username and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].currentHealth
    end

    return -1
end

PlayerStatsHandler.GetMaxHealth = function()
    if DICE_CLIENT_MOD_DATA and PlayerStatsHandler.username and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].maxHealth
    end

    return -1
end

PlayerStatsHandler.HandleCurrentHealth = function(operation)
    local result = false
    if operation == "+" then
        result = PlayerStatsHandler.IncrementCurrentHealth()
    elseif operation == "-" then
        result = PlayerStatsHandler.DecrementCurrentHealth()
    end

    if result and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].isInitialized then
        local currentHealth = PlayerStatsHandler.GetCurrentHealth()
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateCurrentHealth', {currentHealth = currentHealth, username = PlayerStatsHandler.username})
    end
end


PlayerStatsHandler.IncrementCurrentHealth = function()
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData.currentHealth < diceData.maxHealth then
        diceData.currentHealth = diceData.currentHealth + 1
        return true
    end

    return false
end

PlayerStatsHandler.DecrementCurrentHealth = function()
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData.currentHealth > 0 then
        diceData.currentHealth = diceData.currentHealth - 1
        return true
    end

    return false
end

--* Movement *--

PlayerStatsHandler.HandleCurrentMovement = function(operation)
    local result = false
    if operation == "+" then
        result = PlayerStatsHandler.IncrementCurrentMovement()
    elseif operation == "-" then
        result = PlayerStatsHandler.DecrementCurrentMovement()
    end

    if result and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].isInitialized then
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateCurrentMovement', {currentMovement = PlayerStatsHandler.GetCurrentMovement(), username = PlayerStatsHandler.username})
    end
end

PlayerStatsHandler.IncrementCurrentMovement = function()
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData.currentMovement < diceData.maxMovement + diceData.movementBonus then
        diceData.currentMovement = diceData.currentMovement + 1
        return true
    end

    return false
end

PlayerStatsHandler.DecrementCurrentMovement = function()
    local diceData = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username]
    if diceData.currentMovement > 0 then
        diceData.currentMovement = diceData.currentMovement - 1
        return true
    end
    return false
end

---Returns current movmenet
---@return number
PlayerStatsHandler.GetCurrentMovement = function()
    if DICE_CLIENT_MOD_DATA and PlayerStatsHandler.username and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].currentMovement
    end

    return -1
end

PlayerStatsHandler.SetCurrentMovement = function(movement)
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].currentMovement = movement
end

---Returns the max movement value
---@return number
PlayerStatsHandler.GetMaxMovement = function()
    if DICE_CLIENT_MOD_DATA and PlayerStatsHandler.username and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].maxMovement
    end

    return -1
end

PlayerStatsHandler.ApplyMovementBonus = function(deftPoints, deftBonusPoints)
    local movBonus = math.floor((deftPoints + deftBonusPoints) / 2)
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].movementBonus = movBonus
end

PlayerStatsHandler.SetMovementBonus = function(deftPoints)
    local addedBonus = math.floor(deftPoints / 2)
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].movementBonus = addedBonus
end

PlayerStatsHandler.GetMovementBonus = function()
    if DICE_CLIENT_MOD_DATA and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].movementBonus
    end

    return -1
end

local function AdjustCurrentMovement()
    local maxMov = PlayerStatsHandler.GetMaxMovement()
    local movBonus = PlayerStatsHandler.GetMovementBonus()

    if PlayerStatsHandler.GetCurrentMovement() > maxMov + movBonus then
        DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].currentMovement = maxMov + movBonus
    end
end


PlayerStatsHandler.SetMaxMovement = function(maxMov)
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].maxMovement = maxMov
    AdjustCurrentMovement()
end

-- * Armor Bonus
---Check the armor bonus for a certain player
---@param pl IsoPlayer
---@return boolean
PlayerStatsHandler.CalculateArmorBonus = function(pl)
    -- !!! This could be run on any client.
    if pl == nil then return false end
    if pl ~= getPlayer() then return false end


    if DICE_CLIENT_MOD_DATA == nil or DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] == nil then return false end

    --getBulletDefense()
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
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].armorBonus = armorBonus

    -- We need to scale the movement accordingly
    local maxMov = PLAYER_DICE_VALUES.DEFAULT_MOVEMENT - armorBonus
    PlayerStatsHandler.SetMaxMovement(maxMov)

    -- TODO Cache old max movement before updating it
    if PlayerStatsHandler.IsPlayerInitialized() then
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateArmorBonus', {armorBonus = armorBonus, username = PlayerStatsHandler.username})
        sendClientCommand(DICE_SYSTEM_MOD_STRING, 'UpdateMaxMovement', {maxMovement = maxMov, username = PlayerStatsHandler.username})
    end

    return true
end

--- Returns the current value of armor bonus
---@return number
PlayerStatsHandler.GetArmorBonus = function()
    if DICE_CLIENT_MOD_DATA and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] then
        return DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].armorBonus
    end

    return -1
end


-- * Initialization

--- Creates a new ModData for a player
---@param force boolean Force initializiation for the current player
PlayerStatsHandler.InitModData = function(force)

    --print("[DiceSystem] Initializing!")



    if PlayerStatsHandler.username == nil then
        PlayerStatsHandler.username = getPlayer():getUsername()
    end
    -- This should happen only from that specific player, not an admin
    if (DICE_CLIENT_MOD_DATA ~= nil and DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] == nil) or force then
        --print("[DiceSystem] Initializing new player dice data")
        local tempTable = {}
        tempTable = {
            isInitialized = false,
            occupation = "",
            statusEffects = {},

            currentHealth = PLAYER_DICE_VALUES.DEFAULT_HEALTH,
            maxHealth = PLAYER_DICE_VALUES.DEFAULT_HEALTH,

            armorBonus = 0,

            currentMovement = PLAYER_DICE_VALUES.DEFAULT_MOVEMENT,
            maxMovement = PLAYER_DICE_VALUES.DEFAULT_MOVEMENT,
            movementBonus = 0,

            allocatedPoints = 0,

            skills = {},
            skillsBonus = {}
        }

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


        --PlayerStatsHandler.CalculateArmorBonus(getPlayer())

        DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] = {}
        copyTable(DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username], tempTable)

        -- Sync it now
        SyncPlayerTable(PlayerStatsHandler.username)
        print("DiceSystem: initialized player")
    
    elseif DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] == nil then
        error("DiceSystem: Global mod data is broken")
    end
end

---Set if player has finished their setup via the UI
---@param isInitialized boolean
PlayerStatsHandler.SetIsInitialized = function(isInitialized)
    -- Syncs it with server
    DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].isInitialized = isInitialized

    -- Maybe the unique case where this is valid
    if isInitialized then
        SyncPlayerTable(PlayerStatsHandler.username)
    end
end

PlayerStatsHandler.IsPlayerInitialized = function()
    if DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username] == nil then
        --error("Couldn't find player dice data!")
        return
    end


    local isInit = DICE_CLIENT_MOD_DATA[PlayerStatsHandler.username].isInitialized

    if isInit == nil then
        return false
    end

    return isInit
end

--* Admin functions *--

---Start cleaning process for a specific user
---@param userID number
PlayerStatsHandler.CleanModData = function(userID, username)
    sendClientCommand(DICE_SYSTEM_MOD_STRING, "ResetServerDiceData", { userID = userID, username = username })

    --statsTable[username] = nil
    --SyncTable(username)
end

PlayerStatsHandler.SetUser = function(user)
    PlayerStatsHandler.username = user
end

---Check if player is initialized and ready to use the system
---@param username any
---@return boolean
PlayerStatsHandler.CheckInitializedStatus = function(username)
    if DICE_CLIENT_MOD_DATA[username] then
        return DICE_CLIENT_MOD_DATA[username].isInitialized
    else
        return false
    end
end
---------------

-- Various events handling
Events.OnGameStart.Add(PlayerStatsHandler.InitModData)
Events.OnClothingUpdated.Add(PlayerStatsHandler.CalculateArmorBonus)

return PlayerStatsHandler
