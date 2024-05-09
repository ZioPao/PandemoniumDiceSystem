--[[
Main interface
    Name of the player on top
    Occupation dropdown menu
        The player can choose this only ONCE, unless they have a special item to reset the whole skill assignment
    Status effects dropdown menu
        The player can change this whenever they want. It'll affect eventual rolls
    Status effects should be shown near a player's name, on top of their head.
        Multiple status effects can be selected; in that case, in the select you will read "X status effects selected" instead.
    Armor Bonus (Only visual, dependent on equipped clothing)
    Movement Bonus (Only visual, dependent on Deft skill and armor bonus)
    Health handling bar
        Players should be able to change the current amount of health
    Movement handling bar
        Players should be able to change the current movement value
    Skill points section
        Maximum of 20 assignable points
        When setting this up, the player can assign points to each skill
        When a player has already setup their skills, they will be able to press "Roll" for each skill.
        When a player press on "Roll", results must be shown in the chat

Admin utilities
    An Item that users can use to reset their skills\occupations
    Menu with a list of players, where admins can open a specific player dice menu.
]]
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_SCALE = FONT_HGT_SMALL / 16

if FONT_SCALE < 1 then
    FONT_SCALE = 1
end



----------------------------------
local PlayerHandler = require("DiceSystem_PlayerHandling")
local CommonUI = require("UI/DiceSystem_CommonUI")

---@class DiceMenu : ISCollapsableWindow
---@field playerHandler PlayerHandler
local DiceMenu = ISCollapsableWindow:derive("DiceMenu")
DiceMenu.instance = nil



--- Init a new Dice Menu panel
---@param x number
---@param y number
---@param width number
---@param height number
---@param playerHandler PlayerHandler
---@return ISCollapsableWindow
function DiceMenu:new(x, y, width, height, playerHandler)
    local o = {}
    o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.width = width
    o.height = height
    o.resizable = false
    o.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1.0 }
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    o.moveWithMouse = true

    o.playerHandler = playerHandler
    o.plUsername = getPlayer():getUsername() -- TODO optimize this


    DiceMenu.instance = o
    return o
end

--* Setters and getters*--

function DiceMenu:setAdminMode(isAdminMode)
    self.isAdminMode = isAdminMode
end

function DiceMenu:getIsAdminMode()
    return self.isAdminMode
end


--* Skill Panels creation

---Add the label to a single skill panel
---@param parent ISPanel
---@param skill string
---@param x number
---@param frameHeight number
function DiceMenu:addSkillPanelLabel(parent, skill, x, frameHeight)
    local skillString = getText("IGUI_Skill_" .. skill)
    local label = ISLabel:new(x, frameHeight / 4, 25, skillString, 1, 1, 1, 1, UIFont.Small, true)
    self["label"..skill] = label        -- Reference for later
    label:initialise()
    label:instantiate()
    parent:addChild(label)
end


---@param parent ISPanel
---@param skill string
---@param isInitialized boolean
---@param frameHeight number
---@param plUsername string
function DiceMenu:addSkillPanelButtons(parent, skill, isInitialized, frameHeight, plUsername)
    local btnWidth = CommonUI.BUTTON_WIDTH

    -- Check if is initialized
    if not isInitialized or self:getIsAdminMode() then
        local btnPlus = ISButton:new(self.width - btnWidth, 0, btnWidth, frameHeight - 2, "+", self,
            self.onOptionMouseDown)
        btnPlus.internal = "PLUS_SKILL"
        btnPlus.skill = skill
        btnPlus:initialise()
        btnPlus:instantiate()
        btnPlus:setEnable(true)
        self["btnPlus" .. skill] = btnPlus
        parent:addChild(btnPlus)

        local btnMinus = ISButton:new(self.width - btnWidth * 2, 0, btnWidth, frameHeight - 2, "-", self,
            self.onOptionMouseDown)
        btnMinus.internal = "MINUS_SKILL"
        btnMinus.skill = skill
        btnMinus:initialise()
        btnMinus:instantiate()
        btnMinus:setEnable(true)
        self["btnMinus" .. skill] = btnMinus
        parent:addChild(btnMinus)
    elseif isInitialized then
        -- ROLL
        local btnRoll = ISButton:new(self.width - btnWidth * 2, 0, btnWidth * 2, frameHeight - 2, "Roll", self,
            self.onOptionMouseDown)
        btnRoll.internal = "SKILL_ROLL"
        btnRoll:initialise()
        btnRoll:instantiate()
        btnRoll.skill = skill
        btnRoll:setEnable(plUsername == self.playerHandler.username)
        parent:addChild(btnRoll)
    end
end

---@param parent ISPanel
---@param skill string
function DiceMenu:addSkillPanelPoints(parent, skill)
    -- Added - 60 to account for eventual armor bonus
    local skillPointsPanel = ISRichTextPanel:new(self.width - CommonUI.BUTTON_WIDTH * 2 - 60, 0, 100, 25)

    skillPointsPanel:initialise()
    parent:addChild(skillPointsPanel)
    skillPointsPanel.autosetheight = true
    skillPointsPanel.background = false
    skillPointsPanel:paginate()
    self["labelSkillPoints" .. skill] = skillPointsPanel
end


---@param skill string
---@param plUsername string
---@param isAlternativeColor boolean
---@param isInitialized boolean
---@param yOffset number
---@param frameHeight number
---@return ISPanel skillPanel
function DiceMenu:createSingleSkillPanel(skill, plUsername, isAlternativeColor, isInitialized, yOffset, frameHeight)

    local skillPanel = ISPanel:new(0, yOffset, self.width, frameHeight)
    self["skillPanel"..skill] = skillPanel      -- Add a reference that we can call later

    if not isAlternativeColor then
        -- rgb(56, 57, 56)
        skillPanel.backgroundColor = { r = 0.22, g = 0.22, b = 0.22, a = 1 }
    else
        -- rgb(71, 56, 51)
        skillPanel.backgroundColor = { r = 0.28, g = 0.22, b = 0.2, a = 1 }
    end

    skillPanel.borderColor = { r = 0, g = 0, b = 0, a = 1 }

    local xOffset = 10
    self:addSkillPanelLabel(skillPanel, skill, xOffset, frameHeight)
    self:addSkillPanelButtons(skillPanel, skill, isInitialized, frameHeight, plUsername)
    self:addSkillPanelPoints(skillPanel, skill)


    return skillPanel
end



--- Fill the skill panel. The various buttons will be enabled ONLY for the actual player.
function DiceMenu:fillSkillsContainer()
    local yOffset = 0
    local frameHeight = 40
    local isInitialized = self.playerHandler:isPlayerInitialized()
    local plUsername = getPlayer():getUsername()

    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]

        -- TODO Fix warning
        local skillPanel = self:createSingleSkillPanel(skill, plUsername, i % 2 ~= 0, isInitialized, yOffset, frameHeight)
        yOffset = yOffset + frameHeight

        self.skillsPanelContainer:addChild(skillPanel)
        self.skillsPanelContainer:setHeight(self.skillsPanelContainer:getHeight() + frameHeight)

    end
end

function DiceMenu:update()
    ISCollapsableWindow.update(self)

    local isInit = self.playerHandler:isPlayerInitialized()
    local allocatedPoints = self.playerHandler:getAllocatedSkillPoints()
    local isAdmin = self:getIsAdminMode()

    -- Show allocated points during init
    if not isInit or isAdmin then
        -- Points allocated label
        local pointsAllocatedString = getText("IGUI_SkillPointsAllocated") .. string.format(" %d/%d", allocatedPoints, PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)
        self.labelSkillPointsAllocated:setName(pointsAllocatedString)

        -- Occupations
        local comboOcc = self.comboOccupation
        local selectedOccupation = comboOcc:getOptionData(comboOcc.selected)
        self.playerHandler:setOccupation(selectedOccupation)

        -- Status effects
        self.comboStatusEffects.disabled = not isAdmin

        -- Save button
        self.btnConfirm:setEnable(allocatedPoints == PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)
    else
        -- disable occupation choice and allocated skill points label if it's already initialized
        self.comboOccupation.disabled = true
        self.labelSkillPointsAllocated:setName("")

        self.comboStatusEffects.disabled = (self.plUsername ~= self.playerHandler.username)
        CommonUI.UpdateStatusEffectsText(self, self.plUsername)
    end

    local armorBonusPoints = self.playerHandler:getArmorBonus()

    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]
        local skillPoints = self.playerHandler:getSkillPoints(skill)
        local bonusSkillPoints = self.playerHandler:getBonusSkillPoints(skill)
        local skillPointsString = " <RIGHT> " .. string.format("%d", skillPoints)
        if bonusSkillPoints ~= 0 then
            skillPointsString = skillPointsString ..
            string.format(" <RGB:0.94,0.82,0.09> <SPACE> + <SPACE> %d", bonusSkillPoints)
        end

        -- Specific case for Resolve, it should scale on armor bonus
        if skill == "Resolve" and armorBonusPoints ~= 0 then
            skillPointsString = skillPointsString .. string.format(" <RGB:1,0,0> <SPACE> + <SPACE> %d", armorBonusPoints)
        end


        self["labelSkillPoints" .. skill]:setText(skillPointsString)
        self["labelSkillPoints" .. skill].textDirty = true

        -- Handles buttons to assign skill points
        if not isInit or isAdmin then
            self["btnMinus" .. skill]:setEnable(skillPoints ~= 0)
            self["btnPlus" .. skill]:setEnable(skillPoints ~= PLAYER_DICE_VALUES.MAX_PER_SKILL_ALLOCATED_POINTS and
            allocatedPoints ~= PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)
        end
    end

    self.panelArmorBonus:setText(getText("IGUI_PlayerUI_ArmorBonus", armorBonusPoints))
    self.panelArmorBonus.textDirty = true

    self.panelMovementBonus:setText(getText("IGUI_PlayerUI_MovementBonus", self.playerHandler:getMovementBonus()))
    self.panelMovementBonus.textDirty = true

    local currentHealth = self.playerHandler:getCurrentHealth()
    local maxHealth = self.playerHandler:getMaxHealth()
    self.panelHealth:setText(getText("IGUI_PlayerUI_Health", self.playerHandler:getCurrentHealth(),
        self.playerHandler:getMaxHealth()))
    self.panelHealth.textDirty = true
    self.btnPlusHealth:setEnable(currentHealth < maxHealth)
    self.btnMinusHealth:setEnable(currentHealth > 0)

    local totMovement = self.playerHandler:getMaxMovement() + self.playerHandler:getMovementBonus()
    local currMovement = self.playerHandler:getCurrentMovement()
    self.panelMovement:setText(getText("IGUI_PlayerUI_Movement", currMovement, totMovement))
    self.panelMovement.textDirty = true
    self.btnPlusMovement:setEnable(currMovement < totMovement)
    self.btnMinusMovement:setEnable(currMovement > 0)
end

function DiceMenu:calculateHeight(y)
    local fixedFrameHeight = 40
    local finalheight = y + fixedFrameHeight * 8 + 25
    self:setHeight(finalheight)
end

function DiceMenu:createChildren()
    local yOffset = 40
    local pl
    if isClient() then pl = getPlayerFromUsername(self.playerHandler.username) else pl = getPlayer() end
    local plDescriptor = pl:getDescriptor()
    local playerName = DiceSystem_Common.GetForenameWithoutTabs(plDescriptor) -- .. " " .. DiceSystem_Common.GetSurnameWithoutBio(plDescriptor)

    local isAdmin = self:getIsAdminMode()

    if isAdmin then
        playerName = "ADMIN MODE - " .. playerName
    end

    local frameHeight = 40 * FONT_SCALE


    --* Name Label *--
    CommonUI.AddCenteredTextLabel(self, "nameLabel", playerName, yOffset)
    yOffset = yOffset + 25 + 10 -- TODO Janky

    --* Status Effects Panel *--
    local labelStatusEffectsHeight = 25 * (FONT_SCALE + 0.5)
    CommonUI.AddStatusEffectsPanel(self, labelStatusEffectsHeight, yOffset)
    yOffset = yOffset + labelStatusEffectsHeight + 25

    local xFrameMargin = 10 * FONT_SCALE
    local comboBoxHeight = 25 -- TODO This should scale?
    local marginPanelTop = (frameHeight / 4)

    --* Occupation *--
    local occupationString = getText("IGUI_Occupation") .. ": "
    self.panelOccupation = ISRichTextPanel:new(0, yOffset, self.width / 2, frameHeight)
    self.panelOccupation.marginLeft = xFrameMargin
    self.panelOccupation.marginTop = marginPanelTop
    self.panelOccupation.autosetheight = false
    self.panelOccupation.background = true
    self.panelOccupation.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panelOccupation.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panelOccupation:initialise()
    self.panelOccupation:instantiate()
    self.panelOccupation:setText(occupationString)
    self:addChild(self.panelOccupation)
    self.panelOccupation:paginate()

    self.comboOccupation = DiceSystem_ComboBox:new(self.panelOccupation:getWidth() / 2 - xFrameMargin,
        self.panelOccupation:getHeight() / 5, self.width / 4, comboBoxHeight, self, self.onChangeOccupation,
        "OCCUPATIONS", self.playerHandler)
    self.comboOccupation.noSelectionText = ""
    self.comboOccupation:setEditable(true)

    for i = 1, #PLAYER_DICE_VALUES.OCCUPATIONS do
        local occ = PLAYER_DICE_VALUES.OCCUPATIONS[i]
        self.comboOccupation:addOptionWithData(getText("IGUI_Ocptn_" .. occ), occ)
    end
    local occupation = self.playerHandler:getOccupation()
    if occupation ~= "" then
        --print(occupation)
        self.comboOccupation:select(occupation)
    end

    self.panelOccupation:addChild(self.comboOccupation)

    --* Status Effects Selector *--
    local statusEffectString = getText("IGUI_StatusEffect") .. ": "
    self.panelStatusEffects = ISRichTextPanel:new(self.width / 2, yOffset, self.width / 2, frameHeight)
    self.panelStatusEffects.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panelStatusEffects.marginLeft = xFrameMargin
    self.panelStatusEffects.marginTop = marginPanelTop
    self.panelStatusEffects.autosetheight = false
    self.panelStatusEffects.background = true
    self.panelStatusEffects.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panelStatusEffects.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panelStatusEffects:initialise()
    self.panelStatusEffects:instantiate()
    self.panelStatusEffects:setText(statusEffectString)
    self:addChild(self.panelStatusEffects)
    self.panelStatusEffects:paginate()

    self.comboStatusEffects = DiceSystem_ComboBox:new(self.panelStatusEffects:getWidth() / 2 - xFrameMargin,
        self.panelStatusEffects:getHeight() / 5, self.width / 4, comboBoxHeight, self, self.onChangeStatusEffect,
        "STATUS_EFFECTS", self.playerHandler)
    self.comboStatusEffects.noSelectionText = ""
    self.comboStatusEffects:setEditable(true)
    for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
        local statusEffect = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
        self.comboStatusEffects:addOptionWithData(getText("IGUI_StsEfct_" .. statusEffect), statusEffect)
    end
    self.panelStatusEffects:addChild(self.comboStatusEffects)

    yOffset = yOffset + frameHeight

    --* Armor Class *--
    -- TODO Replace with AddPanel
    self.panelArmorBonus = ISRichTextPanel:new(0, yOffset, self.width / 2, frameHeight)
    self.panelArmorBonus:initialise()
    self:addChild(self.panelArmorBonus)
    self.panelArmorBonus.autosetheight = false
    self.panelArmorBonus.marginTop = marginPanelTop
    self.panelArmorBonus.background = true
    self.panelArmorBonus.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panelArmorBonus.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panelArmorBonus:paginate()

    --* Movement Bonus *--
    self.panelMovementBonus = ISRichTextPanel:new(self.width / 2, yOffset, self.width / 2, frameHeight)
    self.panelMovementBonus:initialise()
    self:addChild(self.panelMovementBonus)
    self.panelMovementBonus.marginLeft = 20
    self.panelMovementBonus.marginTop = marginPanelTop
    self.panelMovementBonus.autosetheight = false
    self.panelMovementBonus.background = true
    self.panelMovementBonus.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panelMovementBonus.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panelMovementBonus:paginate()


    yOffset = yOffset + frameHeight

    --* Health Line *--
    CommonUI.AddPanel(self, "panelHealth", self.width, frameHeight, 0, yOffset)
    --CommonUI.AddHealthPanel(self, yOffset, self.width, frameHeight)

    --LEFT MINUS BUTTON
    self.btnMinusHealth = ISButton:new(0, 0, self.width / 4, frameHeight, "-", self, self.onOptionMouseDown)
    self.btnMinusHealth.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.btnMinusHealth.internal = "MINUS_HEALTH"
    self.btnMinusHealth:initialise()
    self.btnMinusHealth:instantiate()
    self.btnMinusHealth:setEnable(true)
    self.panelHealth:addChild(self.btnMinusHealth)

    --RIGHT PLUS BUTTON
    self.btnPlusHealth = ISButton:new(self.width / 1.333, 0, self.width / 4, frameHeight, "+", self,
        self.onOptionMouseDown)
    self.btnPlusHealth.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.btnPlusHealth.internal = "PLUS_HEALTH"
    self.btnPlusHealth:initialise()
    self.btnPlusHealth:instantiate()
    self.btnPlusHealth:setEnable(true)
    self.panelHealth:addChild(self.btnPlusHealth)


    yOffset = yOffset + frameHeight


    --* Movement Line *--
    self.panelMovement = ISRichTextPanel:new(0, yOffset, self.width, frameHeight)
    self.panelMovement:initialise()
    self:addChild(self.panelMovement)
    self.panelMovement.autosetheight = false
    self.panelMovement.background = false
    self.panelMovement:paginate()

    --LEFT MINUS BUTTON
    self.btnMinusMovement = ISButton:new(0, 0, self.width / 4, frameHeight, "-", self, self.onOptionMouseDown)
    self.btnMinusMovement.internal = "MINUS_MOVEMENT"
    self.btnMinusMovement.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.btnMinusMovement:initialise()
    self.btnMinusMovement:instantiate()
    self.btnMinusMovement:setEnable(true)
    self.panelMovement:addChild(self.btnMinusMovement)

    --RIGHT PLUS BUTTON
    self.btnPlusMovement = ISButton:new(self.width / 1.333, 0, self.width / 4, frameHeight, "+", self,
        self.onOptionMouseDown)
    self.btnPlusMovement.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.btnPlusMovement.internal = "PLUS_MOVEMENT"
    self.btnPlusMovement:initialise()
    self.btnPlusMovement:instantiate()
    self.btnPlusMovement:setEnable(true)
    self.panelMovement:addChild(self.btnPlusMovement)

    yOffset = yOffset + frameHeight

    --* Skill points *--
    local arePointsAllocated = false
    if not arePointsAllocated then
        local allocatedPoints = self.playerHandler:getAllocatedSkillPoints()
        local pointsAllocatedString = getText("IGUI_SkillPointsAllocated") ..
        string.format(" %d/%d", allocatedPoints, PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)

        self.labelSkillPointsAllocated = ISLabel:new(
            (self.width - getTextManager():MeasureStringX(UIFont.Small, pointsAllocatedString)) / 2,
            yOffset + frameHeight /
            4, 25, pointsAllocatedString, 1, 1, 1, 1, UIFont.Small, true)
        self.labelSkillPointsAllocated:initialise()
        self.labelSkillPointsAllocated:instantiate()
        self:addChild(self.labelSkillPointsAllocated)
    end

    yOffset = yOffset + frameHeight

    self.skillsPanelContainer = ISPanel:new(0, yOffset, self.width, 0) --Height doesn't really matter, but we will set in fillSkillPanel
    self:addChild(self.skillsPanelContainer)
    self:fillSkillsContainer()

    --* Set correct height for the panel AFTER we're done with everything else *--
    self:calculateHeight(yOffset)

    if not self.playerHandler:isPlayerInitialized() or isAdmin then
        self.btnConfirm = ISButton:new(10, self.height - 35, 100, 25, getText("IGUI_Dice_Save"), self,
            self.onOptionMouseDown)
        self.btnConfirm.internal = "SAVE"
        self.btnConfirm:initialise()
        self.btnConfirm:instantiate()
        self.btnConfirm:setEnable(true)
        self:addChild(self.btnConfirm)
    end

    self.btnClose = ISButton:new(self.width - 100 - 10, self.height - 35, 100, 25, getText("IGUI_Dice_Close"), self,
        self.onOptionMouseDown)
    self.btnClose.internal = "CLOSE"
    self.btnClose:initialise()
    self.btnClose:instantiate()
    self.btnClose:setEnable(true)
    self:addChild(self.btnClose)
end

function DiceMenu:onChangeStatusEffect()
    local statusEffect = self.comboStatusEffects:getSelectedText():gsub("%s+", "") -- We trim it because of stuff like On Fire. We need to get OnFire
    self.playerHandler:toggleStatusEffectValue(statusEffect)
end

function DiceMenu:onOptionMouseDown(btn)
    if btn.internal == 'PLUS_HEALTH' then
        self.playerHandler:handleCurrentHealth("+")
    elseif btn.internal == 'MINUS_HEALTH' then
        self.playerHandler:handleCurrentHealth("-")
    elseif btn.internal == 'PLUS_MOVEMENT' then
        self.playerHandler:handleCurrentMovement("+")
    elseif btn.internal == 'MINUS_MOVEMENT' then
        self.playerHandler:handleCurrentMovement("-")
    elseif btn.internal == 'PLUS_SKILL' then
        self.playerHandler:handleSkillPoint(btn.skill, "+")
    elseif btn.internal == 'MINUS_SKILL' then
        self.playerHandler:handleSkillPoint(btn.skill, "-")
    elseif btn.internal == 'SKILL_ROLL' then
        local points = self.playerHandler:getFullSkillPoints(btn.skill)
        DiceSystem_Common.Roll(btn.skill, points)
    elseif btn.internal == 'SAVE' then
        self.playerHandler:setIsInitialized(true)
        DiceMenu.instance.btnConfirm:setEnable(false)

        -- If we're editing stuff from the admin, we want to be able to notify the other client to update their stats from the server
        if self:getIsAdminMode() then
            print("ADMIN MODE! Sending notification to other client")
            local receivingPl = getPlayerFromUsername(self.playerHandler.username)
            sendClientCommand(DICE_SYSTEM_MOD_STRING, 'NotifyAdminChangedClientData',
                { userID = receivingPl:getOnlineID() })
        end

        self:close()
    elseif btn.internal == 'CLOSE' then
        self:close()
    end
end

function DiceMenu:setVisible(visible)
    self.javaObject:setVisible(visible)
end

-------------------------------------

function DiceMenu:close()
    self:removeFromUIManager()
    local tableIndex = self.plUsername .. tostring(self)
    CommonUI.RemoveCachedStatusEffectsText(tableIndex)
    ISCollapsableWindow.close(self)
end

---Open the Dice Menu panel
---@param isAdminMode boolean set admin mode, admins will be able to edit a specific user stats
---@return ISCollapsableWindow
function DiceMenu.OpenPanel(isAdminMode, username)
    --local UI_SCALE = getTextManager():getFontHeight(UIFont.Small) / 14
    local playerHandler = PlayerHandler:instantiate(username)
    playerHandler:initModData(false)

    if DiceMenu.instance then
        DiceMenu.instance:close()
    end

    if isAdminMode == nil then
        isAdminMode = false
    end


    --print(FONT_SCALE)
    local width = 460 * FONT_SCALE
    local height = 700 * FONT_SCALE
    local pnl = DiceMenu:new(100, 200, width, height, playerHandler)
    pnl:setAdminMode(isAdminMode)
    pnl:initialise()
    pnl:addToUIManager()
    pnl:bringToTop()
    return pnl
end

function DiceMenu.ClosePanel()
    -- TODO This can create problems
    if DiceMenu.instance then
        DiceMenu.instance:close()
    end
end

--****************************--


return DiceMenu