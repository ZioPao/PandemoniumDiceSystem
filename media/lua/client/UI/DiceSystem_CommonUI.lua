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

DiceCommonUI.FRAME_HEIGHT = 40 * DiceCommonUI.FONT_SCALE
DiceCommonUI.X_MARGIN = 2

---Create a text panel
---@param parent ISPanel
---@param text String
---@param y number
---@return number
function DiceCommonUI.AddCenteredTextLabel(parent, name, text, y)
    local x = (parent.width - getTextManager():MeasureStringX(UIFont.Large, text)) / 2
    local height = 25

    parent[name] = ISLabel:new(x, y, height, text, 1, 1, 1, 1, UIFont.Large, true)
    parent[name]:initialise()
    parent[name]:instantiate()
    parent:addChild(parent[name])

    return y + height
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
        --DiceSystem_Common.DebugWriteLog"Updating from cache")
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
    --DiceSystem_Common.DebugWriteLog"Removing cached text")
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




--* SKILL PANEL SPECIFIC *--

---Add the label to a single skill panel
---@param container ISPanel
---@param skill string
---@param x number
---@param frameHeight number
function DiceCommonUI.AddSkillPanelLabel(parent, container, skill, x, frameHeight)
    local skillString = getText("IGUI_Skill_" .. skill)
    local label = ISLabel:new(x, frameHeight / 4, 25, skillString, 1, 1, 1, 1, UIFont.Small, true)
    parent["label"..skill] = label        -- Reference for later
    label:initialise()
    label:instantiate()
    container:addChild(label)
end


---@param container ISPanel
---@param ph PlayerHandler
---@param skill string
---@param isEditing boolean
---@param frameHeight number
---@param plUsername string
function DiceCommonUI.AddSkillPanelButtons(parent, container, ph, skill, isEditing, frameHeight, plUsername)
    local btnWidth = DiceCommonUI.BUTTON_WIDTH

    -- Check if is initialized
    if isEditing then
        local btnPlus = ISButton:new(parent.width - btnWidth - DiceCommonUI.X_MARGIN*2, 0, btnWidth, frameHeight, "+", parent,
            parent.onOptionMouseDown)
        btnPlus.internal = "PLUS_SKILL"
        btnPlus.skill = skill
        btnPlus:initialise()
        btnPlus:instantiate()
        btnPlus:setEnable(true)
        parent["btnPlus" .. skill] = btnPlus
        container:addChild(btnPlus)

        local btnMinus = ISButton:new(parent.width - btnWidth * 2 - DiceCommonUI.X_MARGIN*2, 0, btnWidth, frameHeight, "-", parent,
            parent.onOptionMouseDown)
        btnMinus.internal = "MINUS_SKILL"
        btnMinus.skill = skill
        btnMinus:initialise()
        btnMinus:instantiate()
        btnMinus:setEnable(true)
        parent["btnMinus" .. skill] = btnMinus
        container:addChild(btnMinus)
    else
        -- ROLL
        local btnRoll = ISButton:new(parent.width - btnWidth * 2 - DiceCommonUI.X_MARGIN*2, 0, btnWidth * 2, frameHeight, "Roll", parent,
            parent.onOptionMouseDown)
        btnRoll.internal = "SKILL_ROLL"
        btnRoll:initialise()
        btnRoll:instantiate()
        btnRoll.skill = skill
        btnRoll:setEnable(plUsername == ph.username)      -- TODO will this work here?
        container:addChild(btnRoll)

        parent['roll'..skill] = btnRoll
    end
end

---@param parent ISPanel
---@param container ISPanel
---@param skill string
function DiceCommonUI.AddSkillPanelPointsLabel(parent, container, skill)
    -- Added - 80 to account for eventual stats bonuses, such as armor bonus
    local specialPointsWidth = 80
    local skillPointsPanel = ISRichTextPanel:new(parent.width - DiceCommonUI.BUTTON_WIDTH * 2 - specialPointsWidth, 0, 100, 25)

    skillPointsPanel:initialise()
    container:addChild(skillPointsPanel)
    skillPointsPanel.autosetheight = true
    skillPointsPanel.background = false
    skillPointsPanel:paginate()
    parent["labelSkillPoints" .. skill] = skillPointsPanel
end


---@param parent ISPanel
---@param skill string
---@param isAlternativeColor boolean
---@param yOffset number
---@param frameHeight number
---@return ISPanel
function DiceCommonUI.CreateBaseSingleSkillPanel(parent, skill, isAlternativeColor, yOffset, frameHeight)
    local skillPanel = ISPanel:new(DiceCommonUI.X_MARGIN, yOffset, parent.width - DiceCommonUI.X_MARGIN*2, frameHeight)
    parent["skillPanel"..skill] = skillPanel      -- Add a reference that we can call later

    if not isAlternativeColor then
        -- rgb(56, 57, 56)
        skillPanel.backgroundColor = { r = 0.22, g = 0.22, b = 0.22, a = 1 }
    else
        -- rgb(71, 56, 51)
        skillPanel.backgroundColor = { r = 0.28, g = 0.22, b = 0.2, a = 1 }
    end

    skillPanel.borderColor = { r = 1, g = 1, b = 1, a = 0.8 }

    return skillPanel
end


--* BUTTON LOGIC *--


---@param btn ISButton
---@param ph PlayerHandler
function DiceCommonUI.HandleButtons(btn, ph)
    if btn.internal == "PLUS_STAT" then
        ph:handleStat(btn.stat, "+")
    elseif btn.internal == "MINUS_STAT" then
        ph:handleStat(btn.stat, "-")
    elseif btn.internal == 'PLUS_SKILL' then
        ph:handleSkillPoint(btn.skill, "+")
    elseif btn.internal == 'MINUS_SKILL' then
        ph:handleSkillPoint(btn.skill, "-")
    end

end


--* UPDATE LOGIC *--

---@param parent ISPanel
---@param skill string
---@param enableMinus boolean
---@param enablePlus boolean
function DiceCommonUI.UpdateBtnSkillModifier(parent, skill, enableMinus, enablePlus)
    parent["btnMinus" .. skill]:setEnable(enableMinus)
    parent["btnPlus" .. skill]:setEnable(enablePlus)
end


--* VARIOUS *--
---For positive values, we need to add a + character
---@param val number
---@return string
function DiceCommonUI.GetSign(val)
    if val > 0 then return "+" else return "" end
end



return DiceCommonUI
