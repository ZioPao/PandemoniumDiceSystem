local PlayerHandler = require("DiceSystem_PlayerHandling")

DiceSystem_ChatOverride = {}
DiceSystem_ChatOverride.currentMsg = ""

---Returns a formatted string to display status effects
---@param username string
---@return string
local function GetStatusEffectsString(username)
    local effectsTable = PlayerHandler.GetActiveStatusEffectsByUsername(username)
    local formattedString = ""
    for i = 1, #effectsTable do
        local effect = effectsTable[i]
        local color = DiceSystem_Common.statusEffectsColors[effect]
        formattedString = formattedString ..
            string.format(" <RGB:%.2f,%.2f,%.2f> [%s] <SPACE> <RGB:1,1,1> ", color.r, color.g, color.b, effect)
    end
    return formattedString
end

function DiceSystem_ChatOverride.getTextWithPrefix(originalFunc)
    ---Correct the message which has been fucked by zomboid chat handling
    ---@param message string
    ---@return string
    local function FixOriginalMessage(message)
        local correctedMessage = string.gsub(message, "&lt;", "<")
        correctedMessage = string.gsub(correctedMessage, "&gt;", ">")

        return correctedMessage
    end

    local function GetTimestamp(message)
        local timestampPattern = "%[%d%d:%d%d]"
        return string.match(message, timestampPattern)
    end

    local function GetUsername(message)
        local pattern = "%[([^%]]+)%]:" -- love you chatgpt
        local matchedUsername = string.match(message, pattern)

        if matchedUsername then
            return matchedUsername
        else
            error("Couldn't find username!")
        end
    end

    ---Assemble the final roll message
    ---@param message string
    ---@param timestamp string
    ---@param username string
    ---@return string
    local function GetAssembledMessage(message, timestamp, username)
        local player = getPlayerFromUsername(username)

        if player == nil then error("Player not found!") end

        if timestamp == nil then
            timestamp = ""
        end


        local plDescriptor = player:getDescriptor()
        local forename = DiceSystem_Common.GetForenameWithoutTabs(plDescriptor)

        local statusEffectsString = GetStatusEffectsString(username)
        local _, endMatch = string.find(message, '(||DICE_SYSTEM_MESSAGE||)')
        local separatedMsg = string.sub(message, endMatch + 2, string.len(message))
        local finalMsg = string.format("<RGB:1,1,1> %s <SPACE> %s <SPACE> %s <SPACE> %s", timestamp, forename,
            statusEffectsString, separatedMsg)
        return finalMsg
    end


    return function(self, ...)
        local originalMsg = originalFunc(self, ...)
        self:setOverHeadSpeech(true)
        --DiceSystem_Common.DebugWriteLogoriginalMsg)

        if string.find(originalMsg, '(||DICE_SYSTEM_MESSAGE||)') == nil then return originalMsg end

        local correctedMsg = FixOriginalMessage(originalMsg)
        local timestamp = GetTimestamp(correctedMsg)
        local username = GetUsername(correctedMsg)

        local rollMsg = GetAssembledMessage(correctedMsg, timestamp, username)
        --DiceSystem_Common.DebugWriteLogrollMsg)
        self:setOverHeadSpeech(false)
        return rollMsg
    end
end

function DiceSystem_ChatOverride.Apply(class, methodName)
    local metatable = __classmetatables[class]
    local ogMethod = metatable.__index[methodName]
    metatable.__index[methodName] = DiceSystem_ChatOverride[methodName](ogMethod)
end

function DiceSystem_ChatOverride.NotifyRoll(message)
    DiceSystem_ChatOverride.currentMsg = message
    processSayMessage(message)
end

DiceSystem_ChatOverride.Apply(zombie.chat.ChatMessage.class, "getTextWithPrefix")
