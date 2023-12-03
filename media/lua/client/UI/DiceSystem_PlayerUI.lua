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
local CommonUI = require("UI/DiceSystem_CommonUI")
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_SCALE = FONT_HGT_SMALL / 16

if FONT_SCALE < 1 then
    FONT_SCALE = 1
end

--* Helper functions

---Get a string for ISRichTextPanel containing a colored status effect string
---@param status string
---@return string
local function GetColoredStatusEffect(status)
    -- Pick from table colors
    local statusColors = DiceSystem_Common.statusEffectsColors[status]
    local colorString = string.format(" <RGB:%s,%s,%s> ", statusColors.r, statusColors.g, statusColors.b)
    return colorString .. status
end


----------------------------------

local PlayerHandler = require("DiceSystem_PlayerHandling")

local DiceMenu = ISCollapsableWindow:derive("DiceMenu")
DiceMenu.instance = nil

function DiceMenu:new(x, y, width, height)
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

--- Fill the skill panel. The various buttons will be enabled ONLY for the actual player.
function DiceMenu:fillSkillPanel()
    local yOffset = 0
    local frameHeight = 40
    local isInitialized = PlayerHandler.IsPlayerInitialized()
    local plUsername = getPlayer():getUsername()

    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]
        local panel = ISPanel:new(0, yOffset, self.width, frameHeight)

        if i % 2 == 0 then
            -- rgb(56, 57, 56)
            panel.backgroundColor = { r = 0.22, g = 0.22, b = 0.22, a = 1 }
        else
            -- rgb(71, 56, 51)
            panel.backgroundColor = { r = 0.28, g = 0.22, b = 0.2, a = 1 }
        end

        panel.borderColor = { r = 0, g = 0, b = 0, a = 1 }
        self.panelSkills:addChild(panel)

        local skillString = getText("IGUI_Skill_" .. skill)
        local label = ISLabel:new(10, frameHeight / 4, 25, skillString, 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        label:instantiate()
        panel:addChild(label)


        local btnWidth = 100

        -- Check if is initialized
        if not isInitialized or self:getIsAdminMode() then
            local btnPlus = ISButton:new(self.width - btnWidth, 0, btnWidth, frameHeight - 2, "+", self,
                self.onOptionMouseDown)
            btnPlus.internal = "PLUS_SKILL"
            btnPlus.skill = PLAYER_DICE_VALUES.SKILLS[i]
            btnPlus:initialise()
            btnPlus:instantiate()
            btnPlus:setEnable(true)
            self["btnPlus" .. PLAYER_DICE_VALUES.SKILLS[i]] = btnPlus
            panel:addChild(btnPlus)

            local btnMinus = ISButton:new(self.width - btnWidth * 2, 0, btnWidth, frameHeight - 2, "-", self,
                self.onOptionMouseDown)
            btnMinus.internal = "MINUS_SKILL"
            btnMinus.skill = PLAYER_DICE_VALUES.SKILLS[i]
            btnMinus:initialise()
            btnMinus:instantiate()
            btnMinus:setEnable(true)
            self["btnMinus" .. PLAYER_DICE_VALUES.SKILLS[i]] = btnMinus
            panel:addChild(btnMinus)
        elseif isInitialized then
            -- ROLL
            local btnRoll = ISButton:new(self.width - btnWidth * 2, 0, btnWidth * 2, frameHeight - 2, "Roll", self,
                self.onOptionMouseDown)
            btnRoll.internal = "SKILL_ROLL"
            btnRoll:initialise()
            btnRoll:instantiate()
            btnRoll.skill = PLAYER_DICE_VALUES.SKILLS[i]
            btnRoll:setEnable(plUsername == PlayerHandler.username)
            panel:addChild(btnRoll)
        end


        -- Added - 60 to account for eventual armor bonus
        local skillPointsPanel = ISRichTextPanel:new(self.width - btnWidth * 2 - 60, 0, 100, 25)

        skillPointsPanel:initialise()
        panel:addChild(skillPointsPanel)
        skillPointsPanel.autosetheight = true
        skillPointsPanel.background = false
        skillPointsPanel:paginate()
        self["labelSkillPoints" .. skill] = skillPointsPanel
        yOffset = yOffset + frameHeight

        self.panelSkills:setHeight(self.panelSkills:getHeight() + frameHeight)
    end
end

function DiceMenu:update()
    ISCollapsableWindow.update(self)

    local isInit = PlayerHandler.IsPlayerInitialized()
    local allocatedPoints = PlayerHandler.GetAllocatedSkillPoints()
    local plUsername = getPlayer():getUsername() -- TODO optimize this
    local isAdmin = self:getIsAdminMode()

    -- Show allocated points during init
    if not isInit or isAdmin then
        -- Points allocated label
        local pointsAllocatedString = getText("IGUI_SkillPointsAllocated") .. string.format(" %d/20", allocatedPoints)
        self.labelSkillPointsAllocated:setName(pointsAllocatedString)

        -- Occupations
        local comboOcc = self.comboOccupation
        local selectedOccupation = comboOcc:getOptionData(comboOcc.selected)
        PlayerHandler.SetOccupation(selectedOccupation)

        -- Status effects
        self.comboStatusEffects.disabled = not isAdmin

        -- Save button
        self.btnConfirm:setEnable(allocatedPoints == 20)
    else
        -- disable occupation choice and allocated skill points label if it's already initialized
        self.comboOccupation.disabled = true
        self.labelSkillPointsAllocated:setName("")

        self.comboStatusEffects.disabled = (plUsername ~= PlayerHandler.username)

        CommonUI.UpdateStatusEffectsText(self, plUsername)
    end

    local armorBonusPoints = PlayerHandler.GetArmorBonus()
    --print(armorBonusPoints)
    -- Show skill points
    for i = 1, #PLAYER_DICE_VALUES.SKILLS do
        local skill = PLAYER_DICE_VALUES.SKILLS[i]
        local skillPoints = PlayerHandler.GetSkillPoints(skill)
        local bonusSkillPoints = PlayerHandler.GetBonusSkillPoints(skill)
        local skillPointsString = " <RIGHT> " .. string.format("%d", skillPoints)

        --local skillPointsString
        if bonusSkillPoints ~= 0 then
            skillPointsString = skillPointsString .. string.format(" <RGB:0.94,0.82,0.09> <SPACE> + <SPACE> %d", bonusSkillPoints)
        end
        -- Specific case for Resolve, it should scale on armor bonus
        if skill == "Resolve" and armorBonusPoints ~= 0 then
            skillPointsString = skillPointsString .. string.format(" <RGB:1,0,0> <SPACE> + <SPACE> %d", armorBonusPoints)
        end

        --print(skillPointsString)

        self["labelSkillPoints" .. skill]:setText(skillPointsString)
        self["labelSkillPoints" .. skill].textDirty = true

        -- Handles buttons to assign skill points
        if not isInit or isAdmin then
            self["btnMinus" .. skill]:setEnable(skillPoints ~= 0)
            self["btnPlus" .. skill]:setEnable(skillPoints ~= 5 and allocatedPoints ~= 20)
        end
    end

    self.panelArmorBonus:setText(getText("IGUI_ArmorBonus", armorBonusPoints))
    self.panelArmorBonus.textDirty = true
    self.panelMovementBonus:setText(getText("IGUI_MovementBonus", PlayerHandler.GetMovementBonus()))
    self.panelMovementBonus.textDirty = true

    local currentHealth = PlayerHandler.GetCurrentHealth()
    local maxHealth = PlayerHandler.GetMaxHealth()
    self.panelHealth:setText(getText("IGUI_Health", PlayerHandler.GetCurrentHealth(),
        PlayerHandler.GetMaxHealth()))
    self.panelHealth.textDirty = true
    self.btnPlusHealth:setEnable(currentHealth < maxHealth)
    self.btnMinusHealth:setEnable(currentHealth > 0)

    local totMovement = PlayerHandler.GetMaxMovement() + PlayerHandler.GetMovementBonus()
    local currMovement = PlayerHandler.GetCurrentMovement()
    self.panelMovement:setText(getText("IGUI_Movement", currMovement, totMovement))
    self.panelMovement.textDirty = true
    self.btnPlusMovement:setEnable(currMovement < totMovement)
    self.btnMinusMovement:setEnable(currMovement > 0)
end

function DiceMenu:calculateHeight(y)
    local fixedFrameHeight = 40
    local finalheight = y + fixedFrameHeight*8 + 25
    self:setHeight(finalheight)
end

function DiceMenu:createChildren()
    local yOffset = 40
    local pl
    if isClient() then pl = getPlayerFromUsername(PlayerHandler.username) else pl = getPlayer() end
    local plDescriptor = pl:getDescriptor()
    local playerName = DiceSystem_Common.GetForenameWithoutTabs(plDescriptor) -- .. " " .. DiceSystem_Common.GetSurnameWithoutBio(plDescriptor)

    local isAdmin = self:getIsAdminMode()

    if isAdmin then
        playerName = "ADMIN MODE - " .. playerName
    end
    local frameHeight = 40 * FONT_SCALE

    --* Name Label *--
    CommonUI.AddCenteredTextLabel(self, "labelPlayer", playerName, yOffset)
    yOffset = yOffset + 25 + 10

    --* Status Effects Panel *--
    local labelStatusEffectsHeight = 25 * (FONT_SCALE + 0.5)
    CommonUI.AddStatusEffectsPanel(self, labelStatusEffectsHeight, yOffset)
    yOffset = yOffset + labelStatusEffectsHeight + 25

    local xFrameMargin = 10 * FONT_SCALE
    local comboBoxHeight = 25
    local marginPanelTop = (frameHeight/4)

    --* Occupation *--
    local occupationString = getText("IGUI_Occupation") .. ": "
    self.panelOccupation = ISRichTextPanel:new(0, yOffset, self.width/2, frameHeight)
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

    self.comboOccupation = DiceSystem_ComboBox:new(self.panelOccupation:getWidth()/2 - xFrameMargin, self.panelOccupation:getHeight()/5, self.width / 4, comboBoxHeight, self, self.onChangeOccupation, "OCCUPATIONS")
    self.comboOccupation.noSelectionText = ""
    self.comboOccupation:setEditable(true)

    for i = 1, #PLAYER_DICE_VALUES.OCCUPATIONS do
        local occ = PLAYER_DICE_VALUES.OCCUPATIONS[i]
        self.comboOccupation:addOptionWithData(getText("IGUI_Ocptn_" .. occ), occ)
    end
    local occupation = PlayerHandler.GetOccupation()
    if occupation ~= "" then
        --print(occupation)
        self.comboOccupation:select(occupation)
    end

    self.panelOccupation:addChild(self.comboOccupation)

    --* Status Effects *--
    local statusEffectString = getText("IGUI_StatusEffect") .. ": "
    self.panelStatusEffects = ISRichTextPanel:new(self.width/2, yOffset, self.width/2, frameHeight)
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

    self.comboStatusEffects = DiceSystem_ComboBox:new(self.panelStatusEffects:getWidth()/2 - xFrameMargin, self.panelStatusEffects:getHeight()/5, self.width / 4, comboBoxHeight, self, self.onChangeStatusEffect, "STATUS_EFFECTS")
    self.comboStatusEffects.noSelectionText = ""
    self.comboStatusEffects:setEditable(true)
    for i = 1, #PLAYER_DICE_VALUES.STATUS_EFFECTS do
        local statusEffect = PLAYER_DICE_VALUES.STATUS_EFFECTS[i]
        self.comboStatusEffects:addOptionWithData(getText("IGUI_StsEfct_" .. statusEffect), statusEffect)
    end
    self.panelStatusEffects:addChild(self.comboStatusEffects)

    yOffset = yOffset + frameHeight

    --* Armor Bonus *--
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
    self.panelHealth = ISRichTextPanel:new(0, yOffset, self.width, frameHeight)
    self.panelHealth:initialise()
    self:addChild(self.panelHealth)
    self.panelHealth.autosetheight = false
    self.panelHealth.background = false
    self.panelHealth:paginate()


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
    self.btnPlusMovement = ISButton:new(self.width / 1.333 , 0, self.width / 4, frameHeight, "+", self,
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
        local allocatedPoints = PlayerHandler.GetAllocatedSkillPoints()
        local pointsAllocatedString = getText("IGUI_SkillPointsAllocated") .. string.format(" %d/20", allocatedPoints)

        self.labelSkillPointsAllocated = ISLabel:new(
            (self.width - getTextManager():MeasureStringX(UIFont.Small, pointsAllocatedString)) / 2,
            yOffset + frameHeight /
            4, 25, pointsAllocatedString, 1, 1, 1, 1, UIFont.Small, true)
        self.labelSkillPointsAllocated:initialise()
        self.labelSkillPointsAllocated:instantiate()
        self:addChild(self.labelSkillPointsAllocated)
    end

    yOffset = yOffset + frameHeight

    self.panelSkills = ISPanel:new(0, yOffset, self.width, 0)       --Height doesn't really matter, but we will set in fillSkillPanel
    self:addChild(self.panelSkills)
    self:fillSkillPanel()

    --* Set correct height for the panel AFTER we're done with everything else *--
    self:calculateHeight(yOffset)

    if not PlayerHandler.IsPlayerInitialized() or isAdmin then
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
    local statusEffect = self.comboStatusEffects:getSelectedText()
    PlayerHandler.ToggleStatusEffectValue(statusEffect)
end

function DiceMenu:onOptionMouseDown(btn)
    if btn.internal == 'PLUS_HEALTH' then
        PlayerHandler.HandleCurrentHealth("+")
    elseif btn.internal == 'MINUS_HEALTH' then
        PlayerHandler.HandleCurrentHealth("-")
    elseif btn.internal == 'PLUS_MOVEMENT' then
        PlayerHandler.HandleCurrentMovement("+")
    elseif btn.internal == 'MINUS_MOVEMENT' then
        PlayerHandler.HandleCurrentMovement("-")
    elseif btn.internal == 'PLUS_SKILL' then
        PlayerHandler.HandleSkillPoint(btn.skill, "+")
    elseif btn.internal == 'MINUS_SKILL' then
        PlayerHandler.HandleSkillPoint(btn.skill, "-")
    elseif btn.internal == 'SKILL_ROLL' then
        local points = PlayerHandler.GetFullSkillPoints(btn.skill)
        DiceSystem_Common.Roll(btn.skill, points)
    elseif btn.internal == 'SAVE' then
        PlayerHandler.SetIsInitialized(true)
        DiceMenu.instance.btnConfirm:setEnable(false)

        -- If we're editing stuff from the admin, we want to be able to notify the other client to update their stats from the server
        if self:getIsAdminMode() then
            print("ADMIN MODE! Sending notification to other client")
            local receivingPl = getPlayerFromUsername(PlayerHandler.username)
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
    ISCollapsableWindow.close(self)
end

---Open the Dice Menu panel
---@param isAdminMode boolean set admin mode, admins will be able to edit a specific user stats
---@return ISCollapsableWindow
function DiceMenu.OpenPanel(isAdminMode)
    --local UI_SCALE = getTextManager():getFontHeight(UIFont.Small) / 14
    PlayerHandler.InitModData(false)

    if DiceMenu.instance then
        DiceMenu.instance:close()
    end

    if isAdminMode == nil then
        isAdminMode = false
    end


    print(FONT_SCALE)
    local width = 460 * FONT_SCALE
    local height = 700 * FONT_SCALE
    local pnl = DiceMenu:new(100, 200, width, height)
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
