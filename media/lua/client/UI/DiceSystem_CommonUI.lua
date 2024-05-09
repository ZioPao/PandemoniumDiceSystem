local PlayerHandler = require("DiceSystem_PlayerHandling")

--* Helper functions

---Get a string for ISRichTextPanel containing a colored status effect string
---@param status string
---@param translatedStatus string
---@return string
local function GetColoredStatusEffect(status, translatedStatus)
    -- Pick from table colors
    --local translatedStatus = getText("IGUI_StsEfct_" .. status)

    local statusColors = DiceSystem_Common.statusEffectsColors[status]
    local colorString = string.format(" <RGB:%s,%s,%s> ", statusColors.r, statusColors.g, statusColors.b)
    return colorString .. translatedStatus
end

local function CalculateStatusEffectsMargin(parentWidth, text)
    return (parentWidth - getTextManager():MeasureStringX(UIFont.NewSmall, text)) / 2
end

---@class DiceCommonUI
local DiceCommonUI = {}
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
DiceCommonUI.FONT_SCALE = FONT_HGT_SMALL / 16


if DiceCommonUI.FONT_SCALE < 1 then
    DiceCommonUI.FONT_SCALE = 1
end

DiceCommonUI.cachedStatusEffects = {}
DiceCommonUI.BUTTON_WIDTH = 100

---Create a text panel
---@param parent ISPanel
---@param text String
---@param currentOffset number
function DiceCommonUI.AddCenteredTextLabel(parent, name, text, currentOffset)
    parent[name] = ISLabel:new((parent.width - getTextManager():MeasureStringX(UIFont.Large, text)) / 2, currentOffset,
        25, text, 1, 1, 1, 1, UIFont.Large, true)
    parent[name]:initialise()
    parent[name]:instantiate()
    parent:addChild(parent[name])
end

-- Status Effects Panel
function DiceCommonUI.AddStatusEffectsPanel(parent, height, currentOffset)
    parent.labelStatusEffectsList = ISRichTextPanel:new(0, currentOffset, parent.width, height)
    parent.labelStatusEffectsList:initialise()
    parent:addChild(parent.labelStatusEffectsList)

    parent.labelStatusEffectsList.marginTop = 0
    parent.labelStatusEffectsList.marginLeft = 0
    parent.labelStatusEffectsList.marginRight = 0
    parent.labelStatusEffectsList.autosetheight = false
    parent.labelStatusEffectsList.background = false
    parent.labelStatusEffectsList.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    parent.labelStatusEffectsList.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    parent.labelStatusEffectsList:paginate()
end

---Handles status effects in update
---@param parent any
---@param username string
function DiceCommonUI.UpdateStatusEffectsText(parent, username)
    local activeStatusEffects = PlayerHandler.GetActiveStatusEffectsByUsername(username)
    local amountActiveStatusEffects = #activeStatusEffects

    local indexTab = username .. tostring(parent)
    if DiceCommonUI.cachedStatusEffects and DiceCommonUI.cachedStatusEffects[indexTab] and DiceCommonUI.cachedStatusEffects[indexTab].size and DiceCommonUI.cachedStatusEffects[indexTab].size == amountActiveStatusEffects then
        --print("Updating from cache")
        parent.labelStatusEffectsList:setText(DiceCommonUI.cachedStatusEffects[indexTab].text)
        parent.labelStatusEffectsList.textDirty = true
        return
    end

    local formattedStatusEffects = {}
    local unformattedStatusEffects = {}
    local line = 1

    formattedStatusEffects[line] = ""
    unformattedStatusEffects[line] = ""

    for i = 1, #activeStatusEffects do
        local v = activeStatusEffects[i]
        local unformattedStatusText = getText("IGUI_StsEfct_" .. v)
        local formattedStatusText = GetColoredStatusEffect(v, unformattedStatusText)
        if i == 1 then
            -- First string
            formattedStatusEffects[line] = formattedStatusText
            unformattedStatusEffects[line] = unformattedStatusText
        elseif (i - 1) % 4 == 0 then -- We're gonna use max 4 per line
            -- Go to new line
            formattedStatusEffects[line] = formattedStatusEffects[line] .. " <LINE> "
            line = line + 1
            formattedStatusEffects[line] = formattedStatusText
            unformattedStatusEffects[line] = unformattedStatusText
        else
            -- Normal case
            formattedStatusEffects[line] = formattedStatusEffects[line] ..
                " <RGB:1,1,1> <SPACE> - <SPACE> " .. formattedStatusText
            unformattedStatusEffects[line] = unformattedStatusEffects[line] .. " - " .. unformattedStatusText
        end
    end

    local completeText = ""

    -- Margin is managed directly into the text
    for i = 1, line do
        local xLine = CalculateStatusEffectsMargin(parent.width, unformattedStatusEffects[i])
        formattedStatusEffects[i] = "<SETX:" .. xLine .. "> " .. formattedStatusEffects[i]
        completeText = completeText .. formattedStatusEffects[i]
    end

    parent.labelStatusEffectsList:setText(completeText)
    parent.labelStatusEffectsList.textDirty = true

    DiceCommonUI.cachedStatusEffects[indexTab] = {
        size = amountActiveStatusEffects,
        text = completeText
    }
end

---Removes a cached status effects table used for UIs
---@param index string
function DiceCommonUI.RemoveCachedStatusEffectsText(index)
    --print("Removing cached text")
    DiceCommonUI.cachedStatusEffects[index] = nil
end

function DiceCommonUI.AddPanel(parent, name, width, height, offsetX, offsetY)
    if offsetX == nil then offsetX = 0 end
    if offsetY == nil then offsetY = 0 end

    parent[name] = ISRichTextPanel:new(offsetX, offsetY, width, height)
    parent[name]:initialise()
    parent:addChild(parent[name])
    parent[name].autosetheight = false
    parent[name].background = false
    parent[name]:paginate()
end

return DiceCommonUI
