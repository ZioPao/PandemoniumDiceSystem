--This table will describe how much added bonus we should add to each skill.

-- Different naming style 'cause of IGUI crap and I don't wanna manage two naming styles
local occupationsBonusData = {
    Medic = {},
    PeaceOfficer = {},
    Soldier = {Resolve = 1, Sharp = 2},
    Outlaw = {},
    Artisan = {}
}

--------------------------------

local globalModData = ModData.get(DICE_SYSTEM_MOD_STRING)
local PlayerStatsHandler = {}


--*  Skills handling *--

---Get the amount of points for a specific skill.
---@param skill string
---@return number
PlayerStatsHandler.GetSkillPoints = function(skill)

    --print("DiceSystem: playerHandler searching for skill " .. skill)
    local diceData = globalModData[PlayerStatsHandler.username]
    if diceData == nil then
        print("DiceSystem: modData is nil, can't return skill point value")
        return -1
     end

     local points = diceData.skills[skill]
     if points ~= nil then
        return points
    else
        return -1
    end

end

PlayerStatsHandler.IncrementSkillPoint = function(skill)
    print("DiceSystem: adding to skill " .. skill)
    local diceData = globalModData[PlayerStatsHandler.username]

    if diceData.allocatedPoints < 20 and diceData.skills[skill] < 5 then
        diceData.skills[skill] = diceData.skills[skill] + 1
        diceData.allocatedPoints = diceData.allocatedPoints + 1

        -- TODO I don't like this
        if skill == 'Deft' then
            PlayerStatsHandler.SetMovementBonus(diceData.skills[skill])
        end

        return true
    else
        return false
    end
end

PlayerStatsHandler.DecrementSkillPoint = function(skill)
    local diceData = globalModData[PlayerStatsHandler.username]

    if diceData.skills[skill] > 0 then
        diceData.skills[skill] = diceData.skills[skill] - 1
        diceData.allocatedPoints = diceData.allocatedPoints - 1
        if skill == 'Deft' then
            PlayerStatsHandler.SetMovementBonus(diceData.skills[skill])
        end
        return true
    else
        return false
    end

end

PlayerStatsHandler.GetBonusSkillPoints = function(skill)
    local diceData = globalModData[PlayerStatsHandler.username]
    if diceData == nil then
        print("DiceSystem: modData is nil, can't return skill point value")
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

    local diceData = globalModData[PlayerStatsHandler.username]

    if diceData == nil then
        print("DiceSystem: modData is nil, can't return skill point value")
        return -1
     end

     local allocatedPoints = diceData.allocatedPoints
     if allocatedPoints ~= nil then return allocatedPoints else return -1 end


end

--* Occupations *--

PlayerStatsHandler.GetOccupation = function()
    return globalModData[PlayerStatsHandler.username].occupation
end

PlayerStatsHandler.SetOccupation = function(occupation)
    local diceData = globalModData[PlayerStatsHandler.username]

    --print("Setting occupation => " .. occupation)
    diceData.occupation = occupation
    local bonusData = occupationsBonusData[occupation]


    for key, bonus in pairs(bonusData) do
        diceData.skillsBonus[key] = bonus
    end
end

PlayerStatsHandler.GetOccupationBonus = function(occupation, skill)
    if occupationsBonusData[occupation][skill] ~= nil then
        return occupationsBonusData[occupation][skill]
    end
    return 0
end


--* Health *--
PlayerStatsHandler.GetCurrentHealth = function()
    return globalModData[PlayerStatsHandler.username].currentHealth
end

PlayerStatsHandler.GetMaxHealth = function()
    return globalModData[PlayerStatsHandler.username].maxHealth

end

PlayerStatsHandler.IncrementCurrentHealth = function()
    local diceData = globalModData[PlayerStatsHandler.username]
    if diceData.currentHealth < diceData.maxHealth then
        diceData.currentHealth = diceData.currentHealth + 1
        return true
    end

    return false
end

PlayerStatsHandler.DecrementCurrentHealth = function()
    local diceData = globalModData[PlayerStatsHandler.username]
    if diceData.currentHealth > 0 then
        diceData.currentHealth = diceData.currentHealth - 1
        return true
    end

    return false
end

--* Movement *--
PlayerStatsHandler.GetCurrentMovement = function()
    return globalModData[PlayerStatsHandler.username].currentMovement
end

PlayerStatsHandler.SetCurrentMovement = function(movement)
    globalModData[PlayerStatsHandler.username].currentMovement = movement
end

PlayerStatsHandler.GetMaxMovement = function()
    return globalModData[PlayerStatsHandler.username].maxMovement
end

PlayerStatsHandler.SetMovementBonus = function(deftPoints)
    -- Movement starts at 5
    --print("Setting bonus")
    local addedBonus = math.floor(deftPoints/2)
    globalModData[PlayerStatsHandler.username].movementBonus = addedBonus
end

PlayerStatsHandler.GetMovementBonus = function()

    return globalModData[PlayerStatsHandler.username].movementBonus

end


-- * Initialization

--- Creates a new ModData for a player
PlayerStatsHandler.InitModData = function(force)
	ModData.request(DICE_SYSTEM_MOD_STRING)
    PlayerStatsHandler.username = getPlayer():getUsername()

    if globalModData[PlayerStatsHandler.username] == nil or force then
        globalModData[PlayerStatsHandler.username] = {
            isInitialized = false,
            occupation = "",
            statusEffects = {""},

            currentHealth = 5,
            maxHealth = 5,

            armorBonus = 0,

            currentMovement = 5,
            maxMovement = 5,
            movementBonus = 0,

            allocatedPoints = 0,

            skills = {
                Charm = 0,
                Brutal = 0,
                Resolve = 0,
                Sharp = 0,
                Deft = 0,
                Wit = 0,
                Luck = 0
            },

            skillsBonus = {
                Charm = 0,
                Brutal = 0,
                Resolve = 0,
                Sharp = 0,
                Deft = 0,
                Wit = 0,
                Luck = 0
            }
        }
    end
end

---Set if player has finished their setup via the UI
---@param val any
PlayerStatsHandler.SetIsInitialized = function(val)
    globalModData[PlayerStatsHandler.username].isInitialized = val
end

PlayerStatsHandler.IsPlayerInitialized = function()

    local isInit = globalModData[PlayerStatsHandler.username].isInitialized

    if isInit == nil then
        return false
    end

    return isInit

end

--* Admin functions *--

PlayerStatsHandler.CleanModData = function()
    globalModData[PlayerStatsHandler.username] = nil
end

PlayerStatsHandler.SetUser = function(user)
    -- TODO an admin should be able to "ping" another client and ask him to send the data. Or use global mod data and be done with it
    PlayerStatsHandler.username = user
end

---------------

-- Various events handling
Events.OnGameStart.Add(PlayerStatsHandler.InitModData)
Events.OnPlayerDeath.Add(PlayerStatsHandler.CleanModData)


return PlayerStatsHandler