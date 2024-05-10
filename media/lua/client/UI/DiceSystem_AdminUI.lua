require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"

--**************--
-- Various utilities
local function FetchPlayers()
    local players
    if isClient() then
        ModData.request(DICE_SYSTEM_MOD_STRING) -- Request it again
        players = getOnlinePlayers()
    else
        players = ArrayList.new()
        players:add(getPlayer())
    end

    return players
end


local os_time = os.time
local eTime = 0

local function WaitAndFetchPlayersLoop()
    local cTime = os_time()

    if cTime > eTime then
        local players = FetchPlayers()
        if DiceMenuAdminViewer and DiceMenuAdminViewer.instance and DiceMenuAdminViewer.instance.mainCategory then
            DiceMenuAdminViewer.instance.mainCategory:initList(players)
        end

        Events.OnTick.Remove(WaitAndFetchPlayersLoop)
    end
end

local function WaitAndFetchPlayers(_eTime)
    eTime = _eTime + os_time()
    Events.OnTick.Add(WaitAndFetchPlayersLoop)
end

--*****************

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local HEADER_HGT = FONT_HGT_MEDIUM + 2 * 2
local ENTRY_HGT = FONT_HGT_MEDIUM + 2 * 2

local PlayerHandler = require("DiceSystem_PlayerHandling")
local DiceMenu = require("UI/DiceSystem_PlayerUI")

---@class DiceMenuAdminViewer : ISCollapsableWindow
DiceMenuAdminViewer = ISCollapsableWindow:derive("DiceMenuAdminViewer")
DiceMenuAdminViewer.messages = {}

function DiceMenuAdminViewer.OnOpenPanel()
    ModData.request(DICE_SYSTEM_MOD_STRING) -- Request it again
    if DiceMenuAdminViewer.instance then
        DiceMenuAdminViewer.instance:close()
    end

    local x = getCore():getScreenWidth() / 2
    local y = getCore():getScreenHeight() / 2

    local modal = DiceMenuAdminViewer:new(x, y, 350, 500)
    modal:initialise()
    modal:addToUIManager()
    modal.instance:setKeyboardFocus()

    return modal
end

function DiceMenuAdminViewer:new(x, y, width, height)
    local o = {}
    o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.width = width
    o.height = height
    o.resizable = false
    o.moveWithMouse = true

    DiceMenuAdminViewer.instance = o
    return o
end

function DiceMenuAdminViewer:initialise()
    local top = 50

    self.panel = ISTabPanel:new(10, top, (self.width - 10 * 2) / 1.5, self.height + top - 10)
    self.panel:initialise()
    self.panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.panel.target = self
    self.panel.equalTabWidth = false
    self.panel.tabTransparency = 0
    self.panel.tabHeight = 0
    self:addChild(self.panel)

    local btnY = self.panel:getHeight() / 2 - top
    local btnX = self.panel:getRight() + 10

    local btnSize = (self:getWidth() - self.panel:getWidth()) - 30 -- You must account for the padding, 10 and -20


    local openIco = getTexture("media/ui/openPanelIcon.png")        -- Document icons created by Freepik - Flaticon - Document
    local refreshListIco = getTexture("media/ui/refreshIcon.png")   -- Refresh icons created by Dave Gandy - Flaticon - Refresh
    local deleteDataIco = getTexture("media/ui/deleteDataIcon.png") -- www.flaticon.com/free-icons/delete Delete icons created by Kiranshastry - Flaticon

    -- Middle button
    self.btnRefreshList = ISButton:new(btnX, btnY, btnSize, btnSize / 1.5, "", self, DiceMenuAdminViewer.onClick)
    self.btnRefreshList.internal = "REFRESH"
    self.btnRefreshList:setTooltip(getText("IGUI_Dice_RefreshPlayersListTooltip"))
    self.btnRefreshList:setImage(refreshListIco)
    self.btnRefreshList.anchorTop = false
    self.btnRefreshList.anchorBottom = true
    self.btnRefreshList:initialise()
    self.btnRefreshList:instantiate()
    self.btnRefreshList.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    self:addChild(self.btnRefreshList)

    self.btnOpenPanel = ISButton:new(btnX, btnY - self.btnRefreshList:getHeight() - 10, btnSize, btnSize / 1.5, "", self,
        DiceMenuAdminViewer.onClick)
    self.btnOpenPanel.internal = "OPEN"
    self.btnOpenPanel:setTooltip(getText("IGUI_Dice_OpenPanelTooltip"))
    self.btnOpenPanel:setImage(openIco)
    self.btnOpenPanel.anchorTop = false
    self.btnOpenPanel.anchorBottom = true
    self.btnOpenPanel:initialise()
    self.btnOpenPanel:instantiate()
    self.btnOpenPanel.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    self:addChild(self.btnOpenPanel)

    self.btnDeleteData = ISButton:new(btnX, btnY + self.btnRefreshList:getHeight() + 10, btnSize, btnSize / 1.5, "", self,
        DiceMenuAdminViewer.onClick)
    self.btnDeleteData.internal = "DELETE_DATA"
    self.btnDeleteData:setTooltip(getText("IGUI_Dice_DeleteDataTooltip"))
    self.btnDeleteData:setImage(deleteDataIco)
    self.btnDeleteData:setBorderRGBA(1, 1, 1, 1)
    self.btnDeleteData:setTextureRGBA(1, 1, 1, 1)
    self.btnDeleteData.anchorTop = false
    self.btnDeleteData.anchorBottom = true
    self.btnDeleteData:initialise()
    self.btnDeleteData:instantiate()
    self.btnDeleteData.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    self:addChild(self.btnDeleteData)


    self.mainCategory = DiceMenuAdminScrollingTable:new(0, 0, self.panel.width, self.panel.height, self)
    self.mainCategory:initialise()
    self.panel:addView("Players", self.mainCategory)
    self.panel:activateView("Players")

    local players = FetchPlayers()
    self.mainCategory:initList(players)
end

function DiceMenuAdminViewer:prerender()
    local z = 20
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    local title = getText("IGUI_DiceAdminMenu")
    self:drawText(title, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, title) / 2), z, 1, 1, 1, 1,
        UIFont.Medium)
end

function DiceMenuAdminViewer:onClick(button)
    if button.internal == "OPEN" then
        ModData.request(DICE_SYSTEM_MOD_STRING)
        local player = self.mainCategory.datas.items[self.mainCategory.datas.selected].item
        PlayerHandler:instantiate(player:getUsername())
        DiceMenu.OpenPanel(true)
    elseif button.internal == 'REFRESH' then
        local players = FetchPlayers()
        self.mainCategory:initList(players)
    elseif button.internal == 'DELETE_DATA' then
        -- Get selected player
        ModData.request(DICE_SYSTEM_MOD_STRING)
        local player = self.mainCategory.datas.items[self.mainCategory.datas.selected].item

        local playerID = player:getOnlineID()
        PlayerHandler.CleanModData(playerID)
        processAdminChatMessage("Reset " .. player:getUsername() .. " data")


        -- Updates the list after 1 sec to be sure that it's been synced with the server
        -- TODO This would make sense if we were syncing everything with the server constantly, not anymore.
        WaitAndFetchPlayers(1)
    end
end

function DiceMenuAdminViewer:setKeyboardFocus()
    local view = self.panel:getActiveView()
    if not view then return end
    Core.UnfocusActiveTextEntryBox()
    --view.filterWidgetMap.Type:focus()
end

function DiceMenuAdminViewer:update()
    ISCollapsableWindow.update(self)
    local selection = self.mainCategory.datas.selected
    local isBtnActive = self.mainCategory.datas:size() > 0 and selection ~= 0
    self.btnOpenPanel:setEnable(isBtnActive)
    self.btnDeleteData:setEnable(isBtnActive)
end

function DiceMenuAdminViewer:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

--************************************************************************--


DiceMenuAdminScrollingTable = ISPanel:derive("DiceMenuAdminScrollingTable")

function DiceMenuAdminScrollingTable:new(x, y, width, height, viewer)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)

    o.listHeaderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.3 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    o.totalResult = 0
    o.viewer = viewer
    DiceMenuAdminScrollingTable.instance = o
    return o
end

function DiceMenuAdminScrollingTable:createChildren()
    local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local bottomHgt = 5 + FONT_HGT_SMALL * 2 + 5 + btnHgt + 20 + FONT_HGT_LARGE + HEADER_HGT + ENTRY_HGT

    self.datas = ISScrollingListBox:new(0, HEADER_HGT, self.width, self.height - bottomHgt + 10)
    self.datas:initialise()
    self.datas:instantiate()
    self.datas.itemheight = FONT_HGT_SMALL + 4 * 2
    self.datas.selected = 0
    self.datas.joypadParent = self
    self.datas.font = UIFont.NewSmall
    self.datas.doDrawItem = self.drawDatas
    self.datas.drawBorder = true
    self.datas:addColumn("", 0)
    self:addChild(self.datas)
end

function DiceMenuAdminScrollingTable:initList(module)
    self.datas:clear()
    for i = 0, module:size() - 1 do
        local pl = module:get(i)
        local username = pl:getUsername()
        --check if there are dice data for that specific player
        if PlayerHandler.CheckInitializedStatus(username) then
            self.datas:addItem(username, pl)
        end
    end
end

function DiceMenuAdminScrollingTable:update()
    self.datas.doDrawItem = self.drawDatas
end

function DiceMenuAdminScrollingTable:drawDatas(y, item, alt)
    if y + self:getYScroll() + self.itemheight < 0 or y + self:getYScroll() >= self.height then
        return y + self.itemheight
    end
    local a = 0.9

    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
    end

    if alt then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.6, 0.5, 0.5)
    end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight, a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    local xOffset = 10
    self:drawText(item.text, xOffset, y + 4, 1, 1, 1, a, self.font)
    return y + self.itemheight
end

----------------------------------------------

require "ISUI/ISAdminPanelUI"
require "ServerPointsAdminPanel"
local _ISAdminPanelUICreate = ISAdminPanelUI.create

---@diagnostic disable-next-line: duplicate-set-field
function ISAdminPanelUI:create()
    _ISAdminPanelUICreate(self)

    local lastButton = self.children[self.IDMax-1].internal == "CANCEL" and self.children[self.IDMax-2] or self.children[self.IDMax-1]
    self.btnOpenAdminDiceMenu = ISButton:new(lastButton.x, lastButton.y + 5 + lastButton.height, self.sandboxOptionsBtn.width, self.sandboxOptionsBtn.height, getText("IGUI_DiceAdminMenu"), self, DiceMenuAdminViewer.OnOpenPanel)
    self.btnOpenAdminDiceMenu:initialise()
    self.btnOpenAdminDiceMenu:instantiate()
    self.btnOpenAdminDiceMenu.borderColor = self.buttonBorderColor
    self:addChild(self.btnOpenAdminDiceMenu)

end
