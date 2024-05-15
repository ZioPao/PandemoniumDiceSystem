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
---@field isEditing boolean
local DiceMenu = ISCollapsableWindow:derive("DiceMenu")
DiceMenu.instance = nil



--- Init a new Dice Menu panel
---@param x number
---@param y number
---@param width number
---@param height number
---@param playerHandler PlayerHandler
---@return DiceMenu
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

---Setup initialization for the menu. Set isEditing var for future setup
function DiceMenu:initialise()
    ISCollapsableWindow.initialise(self)
    self.isEditing = not self.playerHandler:isPlayerInitialized() or self:getIsAdminMode()
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
---@param container ISPanel
---@param skill string
---@param x number
---@param frameHeight number
function DiceMenu:addSkillPanelLabel(container, skill, x, frameHeight)
    CommonUI.AddSkillPanelLabel(self, container, skill, x, frameHeight)
end

---@param container ISPanel
---@param skill string
---@param isEditing boolean
---@param frameHeight number
---@param plUsername string
function DiceMenu:addSkillPanelButtons(container, skill, isEditing, frameHeight, plUsername)
    local ph = self.playerHandler
    CommonUI.AddSkillPanelButtons(self, container, ph, skill, isEditing, frameHeight, plUsername)
end

---@param container ISPanel
---@param skill string
function DiceMenu:addSkillPanelPoints(container, skill)
    CommonUI.AddSkillPanelPointsLabel(self, container, skill)
end

---@param skill string
---@param plUsername string
---@param isAlternativeColor boolean
---@param isEditing boolean
---@param yOffset number
---@param frameHeight number
---@return ISPanel skillPanel
function DiceMenu:createSingleSkillPanel(skill, plUsername, isAlternativeColor, isEditing, yOffset, frameHeight)
    local skillPanel = CommonUI.CreateBaseSingleSkillPanel(self, skill, isAlternativeColor, yOffset, frameHeight)

    local xOffset = 10
    self:addSkillPanelLabel(skillPanel, skill, xOffset, frameHeight)
    self:addSkillPanelButtons(skillPanel, skill, isEditing, frameHeight, plUsername)
    self:addSkillPanelPoints(skillPanel, skill)

    return skillPanel
end

--- Fill the skill panel. The various buttons will be enabled ONLY for the actual player.

function DiceMenu:fillSkillsContainer()
    local yOffset = 0
    local frameHeight = CommonUI.FRAME_HEIGHT

    --print("Filling skill container")
    local plUsername = getPlayer():getUsername()

    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]

        -- TODO Fix warning

        local skillPanel = self:createSingleSkillPanel(skill, plUsername, i % 2 ~= 0, self.isEditing, yOffset, frameHeight)
        yOffset = yOffset + frameHeight

        self.skillsPanelContainer:addChild(skillPanel)
        self.skillsPanelContainer:setHeight(self.skillsPanelContainer:getHeight() + frameHeight)
    end
end

--* UPDATE SECTION *--


---@param allocatedPoints number
function DiceMenu:updateAllocatedSkillPointsPanel(allocatedPoints)
    if self.isEditing then
        local pointsAllocatedString = getText("IGUI_SkillPointsAllocated") ..
            string.format(" %d/%d", allocatedPoints, PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)
        self.labelSkillPointsAllocated:setName(pointsAllocatedString)
    else
        self.labelSkillPointsAllocated:setName("")
    end
end

function DiceMenu:updateOccupationsButton()
    if self.isEditing then
        local comboOcc = self.comboOccupation
        local selectedOccupation = comboOcc:getOptionData(comboOcc.selected)
        self.playerHandler:setOccupation(selectedOccupation)
    else
        self.comboOccupation.disabled = true
    end
end

---@param isAdminMode boolean
function DiceMenu:updateStatusEffectsButton(isAdminMode)
    -- Status effects
    if self.isEditing then
        -- when in edit mode, this must be disabled, unless it's an admin?
        self.comboStatusEffects.disabled = not isAdminMode
    else
        self.comboStatusEffects.disabled = (self.plUsername ~= self.playerHandler.username)
    end
end

---@param allocatedPoints number
function DiceMenu:updateBottomPanelButtons(allocatedPoints)
    if self.isEditing then
        -- Save button
        self.btnConfirm:setEnable(allocatedPoints == PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS)
    end
end

function DiceMenu:updatePanelLine(name, currVal, maxVal)
    local panelId = "panel" .. name
    local btnPlusId = "btnPlus" .. name
    local btnMinusId = "btnMinus" .. name

    self[panelId]:setText(getText("IGUI_PlayerUI_" .. name, currVal, maxVal))
    self[panelId].textDirty = true

    self[btnPlusId]:setEnable(currVal < maxVal)
    self[btnMinusId]:setEnable(currVal > 0)
end

function DiceMenu:updateBonusValues()
    -- Armor Bonus + Movement Bonus
    local armorBonus = self.playerHandler:getArmorBonus()
    self.panelArmorBonus:setText(getText("IGUI_PlayerUI_ArmorBonus", armorBonus))
    self.panelArmorBonus.textDirty = true

    local movementBonus = self.playerHandler:getMovementBonus()
    self.panelMovementBonus:setText(getText("IGUI_PlayerUI_MovementBonus", movementBonus))
    self.panelMovementBonus.textDirty = true
end

---@param allocatedPoints number
function DiceMenu:updateSkills(allocatedPoints)
    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]
        local skillPoints = self.playerHandler:getSkillPoints(skill)
        local bonusSkillPoints = self.playerHandler:getBonusSkillPoints(skill)
        local skillPointsString = " <RIGHT> " .. string.format("%d", skillPoints)
        if bonusSkillPoints ~= 0 then
            skillPointsString = skillPointsString ..
                string.format(" <RGB:0.94,0.82,0.09> <SPACE> + <SPACE> %d", bonusSkillPoints)
        end

        -- Account for cases such as Resolve + Armor Bonus
        local specialPoints = self.playerHandler:getSpecialSkillPoints(skill)
        if specialPoints and specialPoints ~= 0 then
            skillPointsString = skillPointsString .. string.format(" <RGB:1,0,0> <SPACE> + <SPACE> %d", specialPoints)
        end


        self["labelSkillPoints" .. skill]:setText(skillPointsString)
        self["labelSkillPoints" .. skill].textDirty = true

        -- Handles buttons to assign skill points
        if self.isEditing then
            self:updateBtnModifierSkill(skill, skillPoints, allocatedPoints)
        end
    end
end

---@param skill string
---@param skillPoints number
---@param allocatedPoints number
function DiceMenu:updateBtnModifierSkill(skill, skillPoints, allocatedPoints)

    local enableMinus = skillPoints ~= 0
    local enablePlus = skillPoints ~= PLAYER_DICE_VALUES.MAX_PER_SKILL_ALLOCATED_POINTS and allocatedPoints ~= PLAYER_DICE_VALUES.MAX_ALLOCATED_POINTS

    CommonUI.UpdateBtnSkillModifier(self, skill, enableMinus, enablePlus)
end

function DiceMenu:update()
    ISCollapsableWindow.update(self)

    local allocatedPoints = self.playerHandler:getAllocatedSkillPoints()

    local isAdminMode = self:getIsAdminMode()

    -- Status effects panel
    self:updateStatusEffectsButton(isAdminMode)

    -- Occupations panel
    self:updateOccupationsButton()

    -- Bar with bonus values
    self:updateBonusValues()

    -- Points allocated label
    self:updateAllocatedSkillPointsPanel(allocatedPoints)


    local currHealth = self.playerHandler:getCurrentHealth()
    local totalHealth = self.playerHandler:getTotalHealth()
    self:updatePanelLine("Health", currHealth, totalHealth)

    local currMovement = self.playerHandler:getCurrentMovement()
    local totalMovement = self.playerHandler:getTotalMovement()
    self:updatePanelLine("Movement", currMovement, totalMovement)

    -- Update skills panel
    self:updateSkills(allocatedPoints)


    -- Show allocated points during init
    self:updateBottomPanelButtons(allocatedPoints)

    if not self.isEditing then
        CommonUI.UpdateStatusEffectsText(self, self.plUsername)
    end
end

function DiceMenu:calculateHeight(y)
    local finalheight = y + CommonUI.FRAME_HEIGHT * 8 + 25
    self:setHeight(finalheight)
end

--* END UPDATE SECTION *--

------------------------------------

--* PANELS CREATION *--


---@param playerName string
---@param y number
---@return number
function DiceMenu:addNameLabel(playerName, y)
    y = CommonUI.AddCenteredTextLabel(self, "nameLabel", playerName, y)
    return y + 10
end

---@param name string
---@param y number
---@param frameHeight number
function DiceMenu:createPanelLine(name, y, frameHeight)
    local upperName = name:upper()
    local panelId = "panel" .. name
    self[panelId] = ISRichTextPanel:new(0, y, self.width, frameHeight)
    self[panelId]:initialise()
    self:addChild(self[panelId])
    self[panelId].autosetheight = false
    self[panelId].background = false
    self[panelId]:paginate()

    --LEFT MINUS BUTTON
    local btnMinusId = "btnMinus" .. name
    self[btnMinusId] = ISButton:new(0, 0, self.width / 4, frameHeight, "-", self, self.onOptionMouseDown)
    self[btnMinusId].internal = "MINUS_STAT"
    self[btnMinusId].stat = name
    self[btnMinusId].borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self[btnMinusId]:initialise()
    self[btnMinusId]:instantiate()
    self[btnMinusId]:setEnable(true)
    self[panelId]:addChild(self[btnMinusId])

    --RIGHT PLUS BUTTON
    local btnPlusId = "btnPlus" .. name
    self[btnPlusId] = ISButton:new(self.width / 1.333, 0, self.width / 4, frameHeight, "+", self,
        self.onOptionMouseDown)
    self[btnPlusId].borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self[btnPlusId].internal = "PLUS_STAT"
    self[btnPlusId].stat = name
    self[btnPlusId]:initialise()
    self[btnPlusId]:instantiate()
    self[btnPlusId]:setEnable(true)
    self[panelId]:addChild(self[btnPlusId])
end


---@param y number
function DiceMenu:createBottomSection(y)
    --* Set correct height for the panel AFTER we're done with everything else *--
    self:calculateHeight(y)

    local btnY = self.height - 35

    if self.isEditing then
        self.btnConfirm = ISButton:new(10, btnY, 100, 25, getText("IGUI_Dice_Save"), self,
            self.onOptionMouseDown)
        self.btnConfirm.internal = "SAVE"
        self.btnConfirm:initialise()
        self.btnConfirm:instantiate()
        self.btnConfirm:setEnable(true)
        self:addChild(self.btnConfirm)
    end

    self.btnClose = ISButton:new(self.width - 100 - 10, btnY, 100, 25, getText("IGUI_Dice_Close"), self,
        self.onOptionMouseDown)
    self.btnClose.internal = "CLOSE"
    self.btnClose:initialise()
    self.btnClose:instantiate()
    self.btnClose:setEnable(true)
    self:addChild(self.btnClose)
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

    local frameHeight = CommonUI.FRAME_HEIGHT


    --* Name Label *--
    yOffset = self:addNameLabel(playerName, yOffset)

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
    self:createPanelLine("Health", yOffset, frameHeight)
    yOffset = yOffset + frameHeight

    --* Movement Line *--
    self:createPanelLine("Movement", yOffset, frameHeight)
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
    self:createBottomSection(yOffset)
end

--* END PANELS CREATION *--


function DiceMenu:onChangeStatusEffect()
    local statusEffect = self.comboStatusEffects:getSelectedText():gsub("%s+", "") -- We trim it because of stuff like On Fire. We need to get OnFire
    self.playerHandler:toggleStatusEffectValue(statusEffect)
end

function DiceMenu:onOptionMouseDown(btn)
    CommonUI.HandleButtons(btn, self.playerHandler)
    
    if btn.internal == 'SKILL_ROLL' then
        local points = self.playerHandler:getFullSkillPoints(btn.skill)
        DiceSystem_Common.Roll(btn.skill, points)
    elseif btn.internal == 'SAVE' then
        self.playerHandler:setIsInitialized(true)
        self.playerHandler:syncPlayerTable()




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

-------------------------------------

function DiceMenu:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    local tableIndex = self.plUsername .. tostring(self)
    CommonUI.RemoveCachedStatusEffectsText(tableIndex)
end

---Open the Dice Menu panel
---@param isAdminMode boolean set admin mode, admins will be able to edit a specific user stats
---@param username string
---@return ISCollapsableWindow
function DiceMenu.OpenPanel(isAdminMode, username)
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
