-- Caching stuff

-- TODO Status effects of already logged in players do not show up
------------------

-- Mostly composed of static functions, to be used to set stuff from external sources

---@class StatusEffectsHandler
local StatusEffectsHandler = {}
StatusEffectsHandler.nearPlayersStatusEffects = {}
StatusEffectsHandler.renderDistance = 50


---Used to update the local status effects table
---@param userID number
---@param statusEffects table
function StatusEffectsHandler.UpdateLocalStatusEffectsTable(userID, statusEffects)
    StatusEffectsHandler.mainPlayer = getPlayer()
    local receivedPlayer = getPlayerByOnlineID(userID)
    local dist = StatusEffectsHandler.TryDistTo(StatusEffectsHandler.mainPlayer, receivedPlayer)
    if dist < StatusEffectsHandler.renderDistance then
        StatusEffectsHandler.nearPlayersStatusEffects[userID] = {}
        local newStatusEffectsTable = {}
        for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
            local x = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
            if statusEffects[x] ~= nil and statusEffects[x] == true then
                --print(x)
                table.insert(newStatusEffectsTable, x)
            end
        end

        if table.concat(newStatusEffectsTable) ~= table.concat(StatusEffectsHandler.nearPlayersStatusEffects[userID]) then
            --print("Changing table! Some stuff is different")
            StatusEffectsHandler.nearPlayersStatusEffects[userID] = newStatusEffectsTable
            --else
            --print("Same effects! No change needed")
        end
    else
        StatusEffectsHandler.nearPlayersStatusEffects[userID] = {}
    end
end

---Set the colors table. Used to handle colorblind option
---@param colors table r,g,b
function StatusEffectsHandler.SetColorsTable(colors)
    StatusEffectsHandler.colorsTable = colors
end

---Set the Y offset for the status effects on top of the players heads
---@param offset number
function StatusEffectsHandler.SetUserOffset(offset)
    StatusEffectsHandler.userOffset = offset
end

---Returns the y offset for status effects
---@return number
function StatusEffectsHandler.GetUserOffset()
    return StatusEffectsHandler.userOffset
end


function StatusEffectsHandler.TryDistTo(localPlayer, onlinePlayer)
    local dist = 10000000000 -- Fake number, just to prevent problems later.
    if localPlayer and onlinePlayer then
        if onlinePlayer:getCurrentSquare() ~= nil then
            dist = localPlayer:DistTo(onlinePlayer)
        end
    end

    return dist
end

return StatusEffectsHandler