
-------------
---@class DiceSystem_ComboBox : ISComboBox
---@field playerHandler PlayerHandler
DiceSystem_ComboBox = ISComboBox:derive("DiceSystem_ComboBox")


DiceSystem_ComboBoxOccupationPopup = ISComboBoxPopup:derive("DiceSystem_ComboBoxOccupationPopup")





---@class DiceSystem_ComboBoxStatusPopup : ISComboBoxPopup
---@field playerHandler PlayerHandler
DiceSystem_ComboBoxStatusPopup = ISComboBoxPopup:derive("DiceSystem_ComboBoxStatusPopup")

function DiceSystem_ComboBoxOccupationPopup:doDrawItem(y, item, alt)
    if self.parentCombo:hasFilterText() then
        if not item.text:lower():contains(self.parentCombo:getFilterText():lower()) then
            return y
        end
    end
    if item.height == 0 then
        item.height = self.itemheight
    end
    local highlight = (self:isMouseOver() and not self:isMouseOverScrollBar()) and self.mouseoverselected or
        self.selected
    if self.parentCombo.joypadFocused then
        highlight = self.selected
    end
    if highlight == item.index then
        local selectColor = self.parentCombo.backgroundColorMouseOver
        self:drawRect(0, (y), self:getWidth(), item.height - 1, selectColor.a, selectColor.r, selectColor.g,
            selectColor.b)

        if self:isMouseOver() and not self:isMouseOverScrollBar() then
            local textWid = getTextManager():MeasureStringX(self.font, item.text)
            local scrollBarWid = self:isVScrollBarVisible() and 13 or 0
            if 10 + textWid > self.width - scrollBarWid then
                self.tooWide = item
                self.tooWideY = y
            end
        end
    end
    local itemPadY = self.itemPadY or (item.height - self.fontHgt) / 2

    -- #ffde16
    local color = { r = 1, g = 0.871, b = 0.086, a = 1 }
    self:drawText(item.text, 10, y + itemPadY, color.r, color.g, color.b, color.a, self.font)
    y = y + item.height
    return y
end

function DiceSystem_ComboBoxOccupationPopup:new(x, y, width, height)
    local o = ISComboBoxPopup:new(x, y, width, height)
    setmetatable(o, self)
    return o
end

--**************************************************--

function DiceSystem_ComboBoxStatusPopup:doDrawItem(y, item, alt)
    if self.parentCombo:hasFilterText() then
        if not item.text:lower():contains(self.parentCombo:getFilterText():lower()) then
            return y
        end
    end
    if item.height == 0 then
        item.height = self.itemheight
    end
    local highlight = (self:isMouseOver() and not self:isMouseOverScrollBar()) and self.mouseoverselected or
        self.selected
    if self.parentCombo.joypadFocused then
        highlight = self.selected
    end
    if highlight == item.index then
        local selectColor = self.parentCombo.backgroundColorMouseOver
        self:drawRect(0, (y), self:getWidth(), item.height - 1, selectColor.a, selectColor.r, selectColor.g,
            selectColor.b)

        if self:isMouseOver() and not self:isMouseOverScrollBar() then
            local textWid = getTextManager():MeasureStringX(self.font, item.text)
            local scrollBarWid = self:isVScrollBarVisible() and 13 or 0
            if 10 + textWid > self.width - scrollBarWid then
                self.tooWide = item
                self.tooWideY = y
            end
        end
    end
    local itemPadY = self.itemPadY or (item.height - self.fontHgt) / 2
    local color = { r = 1, b = 1, g = 1, a = 1 }
    --DiceSystem_Common.DebugWriteLogitem.text)

    local statusEffectTrimmed = item.text:gsub("%s+", "")

    if self.playerHandler:getStatusEffectValue(statusEffectTrimmed) then
        --DiceSystem_Common.DebugWriteLog"Active!")
        color.r = 0
        color.g = 1
        color.b = 0
    end


    self:drawText(item.text, 10, y + itemPadY, color.r, color.g, color.b, color.a, self.font)
    y = y + item.height
    return y
end

---Creates the combo box for the occupations
---@param x number
---@param y number
---@param width number
---@param height number
---@param playerHandler PlayerHandler
---@return ISComboBoxPopup
function DiceSystem_ComboBoxStatusPopup:new(x, y, width, height, playerHandler)
    local o = ISComboBoxPopup:new(x, y, width, height)
    setmetatable(o, self)

    o.playerHandler = playerHandler

    return o
end

--**************************************************--

function DiceSystem_ComboBox:createChildren()
    if self.contents == "OCCUPATIONS" then
        self.popup = DiceSystem_ComboBoxOccupationPopup:new(0, 0, 100, 50)
    else
        self.popup = DiceSystem_ComboBoxStatusPopup:new(0, 0, 100, 50, self.playerHandler)
    end

    self.popup:initialise()
    self.popup:instantiate()
    self.popup:setFont(self.font, 4)
    self.popup:setAlwaysOnTop(true)
    self.popup.drawBorder = true
    self.popup:setCapture(true)
    DiceSystem_ComboBox.SharedPopup = self.popup
end

function DiceSystem_ComboBox:onMouseUp(x, y)
    if self.disabled or not self.sawMouseDown then return end
    self.sawMouseDown = false
    self.expanded = not self.expanded
    if self.expanded then
        self:showPopup()
    else
        self:hidePopup()
        self.mouseOver = self:isMouseOver()
    end
end

function DiceSystem_ComboBox:hidePopup()
    getSoundManager():playUISound("UIToggleComboBox")
    self.popup:removeFromUIManager()
end

function DiceSystem_ComboBox:prerender()
    if not self.disabled then
        self.fade:setFadeIn(self.joypadFocused or self:isMouseOver())
        self.fade:update()
    end

    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b);

    if self.expanded then
    elseif not self.joypadFocused then
        self:drawRect(0, 0, self.width, self.height, self.backgroundColorMouseOver.a * 0.5 * self.fade:fraction(),
            self.backgroundColorMouseOver.r, self.backgroundColorMouseOver.g, self.backgroundColorMouseOver.b);
    else
        self:drawRect(0, 0, self.width, self.height, self.backgroundColorMouseOver.a, self.backgroundColorMouseOver.r,
            self.backgroundColorMouseOver.g, self.backgroundColorMouseOver.b);
    end
    local alpha = math.min(self.borderColor.a + 0.2 * self.fade:fraction(), 1.0)
    if not self.disabled then
        self:drawRectBorder(0, 0, self.width, self.height, alpha, self.borderColor.r, self.borderColor.g,
            self.borderColor.b);
    else
        self:drawRectBorder(0, 0, self.width, self.height, alpha, 0.5, 0.5, 0.5);
    end

    local fontHgt = getTextManager():getFontHeight(self.font)
    local y = (self.height - fontHgt) / 2

    local boxLabelString
    local boxLabelColor = { r = 1, b = 1, g = 1 }
    if self.contents == "OCCUPATIONS" then
        boxLabelString = getText("IGUI_Ocptn_" .. self.playerHandler:getOccupation())
        boxLabelColor.r = 1
        boxLabelColor.g = 0.871
        boxLabelColor.b = 0.086
    else
        boxLabelString = "Open List"
        boxLabelColor.r = self.textColor.r
        boxLabelColor.g = self.textColor.g
        boxLabelColor.b = self.textColor.b
    end
    self:drawText(boxLabelString, 10, y, boxLabelColor.r, boxLabelColor.g, boxLabelColor.b, self.textColor.a, self.font)

    if self:isMouseOver() and not self.expanded and self:getOptionTooltip(self.selected) then
        local text = self:getOptionTooltip(self.selected)
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
        end
        if not self.tooltipUI:getIsVisible() then
            if string.contains(text, "\n") then
                self.tooltipUI.maxLineWidth = 1000 -- don't wrap the lines
            else
                self.tooltipUI.maxLineWidth = 300
            end
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
        end
        self.tooltipUI.description = text
        self.tooltipUI:setX(self:getMouseX() + 23)
        self.tooltipUI:setY(self:getMouseY() + 23)
    else
        if self.tooltipUI and self.tooltipUI:getIsVisible() then
            self.tooltipUI:setVisible(false)
            self.tooltipUI:removeFromUIManager()
        end
    end

    if not self.disabled then
        self:drawTexture(self.image, self.width - self.image:getWidthOrig() - 3,
            (self.baseHeight / 2) - (self.image:getHeight() / 2), 1, 1, 1, 1)
    else
        self:drawTexture(self.image, self.width - self.image:getWidthOrig() - 3,
            (self.baseHeight / 2) - (self.image:getHeight() / 2), 1, 0.5, 0.5, 0.5)
    end
end

---comment
---@param x number
---@param y number
---@param width number
---@param height number
---@param target any
---@param onChange any
---@param contents any
---@param playerHandler PlayerHandler
---@return ISComboBox
function DiceSystem_ComboBox:new(x, y, width, height, target, onChange, contents, playerHandler)
    local o = ISComboBox:new(x, y, width, height, target, onChange, nil, nil)
    setmetatable(o, self)
    self.__index = self

    o.contents = contents
    o.playerHandler = playerHandler
    return o
end