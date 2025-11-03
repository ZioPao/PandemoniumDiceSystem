DiceSystem_Common = {}

-- ---Returns the occupation bonus for a certain skill
-- ---@param occupation string
-- ---@param skill string
-- ---@return integer
-- function DiceSystem_Common.GetOccupationBonus(occupation, skill)
--     if PLAYER_DICE_VALUES.OCCUPATIONS_BONUS[occupation][skill] ~= nil then
--         return PLAYER_DICE_VALUES.OCCUPATIONS_BONUS[occupation][skill]
--     end
--     return 0
-- end

---Assign the correct color table for status effects
---@param colorsTable table
function DiceSystem_Common.SetStatusEffectsColorsTable(colorsTable)
    DiceSystem_Common.statusEffectsColors = colorsTable
end


function DiceSystem_Common.GetSkillName(skill)
    return getText("IGUI_Skill_"..skill)
end

--- Do a roll for a specific skill and print the result into chat. If something goes
---@param skill string
---@param points number
---@return number
function DiceSystem_Common.Roll(skill, points)
    local rolledValue = ZombRand(20) + 1
    local additionalMsg = ""
    if rolledValue == 1 then
        -- crit fail
        additionalMsg = "<SPACE> <RGB:1,0,0> CRITICAL FAILURE! "
    elseif rolledValue == 20 then
        -- crit success
        additionalMsg = "<SPACE> <RGB:0,1,0> CRITICAL SUCCESS! "
    end

    local finalValue = rolledValue + points
    local message = "(||DICE_SYSTEM_MESSAGE||) rolled " ..
        DiceSystem_Common.GetSkillName(skill) .. " " .. additionalMsg .. tostring(rolledValue) .. "+" .. tostring(points) .. "=" .. tostring(finalValue)

    -- send to chat
    if isClient() then
        DiceSystem_ChatOverride.NotifyRoll(message)
    end

    return finalValue
end

---Get the forename without the tabulations added by Buffy's bios
---@param plDescriptor SurvivorDesc
function DiceSystem_Common.GetForenameWithoutTabs(plDescriptor)
    local forenameWithTabs = plDescriptor:getForename()
    local forename = string.gsub(forenameWithTabs, "^%s*(%a+)", "%1")
    if forename == nil then forename = "" end
    return forename
end


---Writes a log in the console with [DiceSystem] as a prefix
---@param text string
function DiceSystem_Common.DebugWriteLog(text)
    --writeLog("DiceSystem", text)
    print("[DiceSystem] " .. tostring(text))
end

-- if isDebugEnabled() then
--     ---Writes a log in the console ONLY if debug is enabled
--     ---@param text string
--     function DiceSystem_Common.DebugWriteLog(text)
--         --writeLog("DiceSystem", text)
--         DiceSystem_Common.DebugWriteLog"[DiceSystem] " .. tostring(text))
--     end
-- else
--     ---Placeholder, to prevent non essential calls
--     function DiceSystem_Common.DebugWriteLog()
--         return
--     end
-- end

--*HELPERS


function DiceSystem_Common.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == 'table' then
            copy[k] = DiceSystem_Common.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end


