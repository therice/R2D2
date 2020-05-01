local _, AddOn = ...
local Standby = AddOn:NewModule("Standby", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local UI = AddOn.components.UI
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Objects = Util.Objects
local Strings = Util.Strings
local StandbyMember = AddOn.components.Models.StandbyMember
local COpts = UI.ConfigOptions
local ST = AddOn.Libs.ScrollingTable

Standby.defaults = {
    profile = {
        enabled     = false,
        standby_pct = 0.80,
        verify_after_each_award = false,
    }
}

Standby.options = {
    ignore_enable_disable = true,
    name = L['standby'],
    desc = L['standby_desc'],
    args = {
        enabled = {
            type = 'group',
            name = L['standby_toggle'],
            inline = true,
            order = 1,
            args = {
                enabled = COpts.Toggle(L['enable'], 0, L['standby_toggle_desc']),
            }
        },
        settings = {
            type = 'group',
            name = L['settings'],
            inline = true,
            order = 2,
            args = {
                verify_after_each_award = COpts.Toggle(
                        L['verify_after_each_award'], 1, L['verify_after_each_award_desc'],
                        function () return not Standby.db.profile.enabled end,
                        {width='full'}
                ),
                standby_pct = COpts.Range(
                        L['standby_pct'], 2, 0, 1, 0.01,
                        {
                            isPercent = true,
                            desc = L['standby_pct_desc'],
                            disabled = function () return not Standby.db.profile.enabled end
                        }
                ),
            }
        },
        open = {
            order = 5,
            name = "Open Standby/Bench Roster",
            desc = "Desc",
            type = "execute",
            func = function()
                AddOn:CallModule("Standby")
            end,
        },
    }
}

local ROW_HEIGHT, NUM_ROWS = 20, 10
local MenuFrame

-- todo : write roster to db, clear it upon raid end, use db to populate roster on reload
function Standby:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    self.scrollCols = {
        -- 1 class icon
        {
            name  = "",
            width = ROW_HEIGHT,
        },
        -- 2 player name
        {
            name        = _G.NAME,
            width       = 100,
            defaultsort = ST.SORT_ASC,
            sortnext    = 1,
        },
        -- 3 added
        {
            name        = L['added'],
            width       = 115,
            defaultsort = ST.SORT_DSC,
            sortnext    = 2,
        },
        -- 4 last pinged
        {
            name        = L['pinged'],
            width       = 115,
            defaultsort = ST.SORT_DSC,
            sortnext    = 2,
        },
        -- 5 last status
        {
            name        = L['status'],
            width       = 55,
            defaultsort = ST.SORT_DSC,
            sortnext    = 2,
        },
        -- 6 remove icon
        {
            name = "",
            width = ROW_HEIGHT
        },
    }
    self.db = AddOn.db:RegisterNamespace(self:GetName(), Standby.defaults)
    self.roster = {}
    self:RegisterMessage(C.Messages.PlayerNotFound, function(...) Standby:PlayerNotFound(...) end)
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.StandbyRightClick, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
end

-- enable/disable only for showing UI, functional behavior controlled by 'enabled' setting
function Standby:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self:BuildData()
    self:Show()
end

function Standby:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
end

function Standby:EnableOnStartup()
    return false
end

function Standby:Show()
    self.frame:Show()
end

function Standby:Hide()
    if self.frame then
        self.frame.moreInfo:Hide()
        self.frame:Hide()
    end
end

function Standby:GetFrame()
    if self.frame then return self.frame end
    local f = UI:CreateFrame("R2D2_Standby", "Standby",  L["r2d2_standby_bench_frame"], 250, 300)
    f:SetWidth(225)
    
    local st = ST:CreateST(self.scrollCols, NUM_ROWS, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    st.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    st:EnableSelection(true)
    st:RegisterEvents({
                          ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                              if row then
                                  if button == "RightButton" then
                                      MenuFrame.name = data[realrow].name
                                      MSA_ToggleDropDownMenu(1, nil, MenuFrame, cellFrame, 0, 0);
                                  elseif button == "LeftButton" then
                                      self:UpdateMoreInfo(self:GetName(), f, realrow, data)
                                  end
                              end
                              return false
                          end,
                          ["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                              if row then self:UpdateMoreInfo(self:GetName(), f, realrow, data) end
                              return false
                          end,
                          ["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                              -- todo : hide this based upon no row being selected
                              if row then
                                  if f.st:GetSelection() then
                                      self:UpdateMoreInfo(self:GetName(), f, realrow, data)
                                  else
                                      if self.frame then self.frame.moreInfo:Hide() end
                                  end
                              end
                              return false
                          end,
                      })
    f.st = st
    
    AddOn.EmbedMoreInfoWidgets(self:GetName(), f, function(m, f) self:UpdateMoreInfo(m, f) end)
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("RIGHT", f.moreInfoBtn, "LEFT", -10, 0)
    close:SetScript("OnClick", function() self:Disable() end)
    f.closeBtn = close
    
    f:SetWidth(st.frame:GetWidth() + 20)
    return f
end


Standby.RightClickEntries = {
    -- level 1
    {
        -- 1 Title, player name
        {
            text = function(name) return AddOn.Ambiguate(name) end,
            isTitle = true,
            notCheckable = true,
            disabled = true,
        },
        -- 2 Spacer
        {
            text = "",
            notCheckable = true,
            disabled = true,
        },
        -- 3 Ping
        {
            text = L["ping"],
            notCheckable = true,
            func = function(name)
                Standby:PingPlayer(name)
            end,
        },
    }
}

Standby.RightClickMenu = UI.RightClickMenu(
    function() return AddOn.isMasterLooter end,
    Standby.RightClickEntries,
    function(info, menu, level, entry, value) end
)

function Standby:UpdateMoreInfo(module, f, row, data)
    local moreInfo = AddOn:MoreInfoEnabled(module)
    local player
    
    if data and row then
        player = data[row].player
    else
        local selection = f.st:GetSelection()
        player = selection and f.st:GetRow(selection).player or nil
    end
    
    if not moreInfo or not player then
        return f.moreInfo:Hide()
    end
    
    local tip = f.moreInfo
    tip:SetOwner(f, "ANCHOR_RIGHT")
    if Util.Tables.Count(player.contacts) > 0 then
        tip:AddDoubleLine(L["contact"], Strings.Join("/", L["pinged"], L["status"]))
        tip:AddLine(" ")
        
        for name, status in pairs(player.contacts) do
            tip:AddDoubleLine(name, status:GetText(), 1, 1, 1)
        end
    else
        tip:AddLine(L["no_contacts_for_standby_member"])
    end
    
    tip:Show()
    tip:SetAnchorType("ANCHOR_RIGHT", 0, -tip:GetHeight())
end

function Standby:BuildData()
    if not self.frame then return end
    
    self.frame.rows = {}
    local row = 1
    for name, player in pairs(self.roster) do
        if Objects.IsTable(player) then
            self.frame.rows[row] = {
                name = name,
                player = player,
                num = row,
                cols = {
                    {value = player.class, DoCellUpdate = AddOn.SetCellClassIcon, args = {player.class}},
                    {value = AddOn.Ambiguate(name), color = AddOn.GetClassColor(player.class)},
                    {value = player:JoinedTimestamp() or ""},
                    {value = player:PingedTimestamp() or ""},
                    {DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellStatus)},
                    {DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellDelete)},
                }
            }
            row = row +1
        end
    end
    self.frame.st:SetData(self.frame.rows)
end

function Standby:RefreshData()
    if self.frame then
        self:BuildData()
        self:UpdateMoreInfo(self:GetName(), self.frame)
    end
end

function Standby.SetCellDelete(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    if not frame.created then
        frame:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        frame:SetScript("OnEnter", function()
            UI:CreateTooltip(L['double_click_to_delete_this_entry'])
        end)
        frame:SetScript("OnLeave", function() UI:HideTooltip() end)
        frame.created = true
    end
    
    frame:SetScript("OnClick", function()
        local player = data[realrow].player
        if frame.lastClick and GetTime() - frame.lastClick <= 0.5 then
            frame.lastClick = nil
            Standby:RemovePlayer(player)
            tremove(data, realrow)
            table:SortData()
        else
            frame.lastClick = GetTime()
        end
    end)
end

function Standby.SetCellStatus(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local player = data[realrow].player
    frame.text:SetText(player.status:OnlineText())
end

-- Standby must be enabled AND
-- Must be Master Looter AND
-- Must be in Group OR Development Mode Enabled
function Standby:IsOperationRequired()
    return self.db.profile.enabled and
            AddOn.isMasterLooter and
            (IsInGroup() or AddOn:DevModeEnabled())
end

function Standby:PingPlayers()
    for name, _ in pairs(self.roster) do
        self:PingPlayer(name)
    end
end

function Standby:PingPlayer(playerName)
    Logging:Debug("PingPlayer(%s)", tostring(playerName))
    
    local player = self.roster[playerName]
    if not player then return end
    
    local C = AddOn.Constants
    local contacts = Tables.New(AddOn.Ambiguate(player.name))
    for name, _ in pairs(player.contacts) do Tables.Push(contacts, AddOn.Ambiguate(name)) end
    -- if the contact isn't online, it will result in a system message - which we trap and forward on to PlayerNotFound
    -- via ChatFrame_AddMessageEventFilter() in Addon.lua
    Tables.Call(contacts, function(contact) AddOn:SendCommand(contact, C.Commands.StandbyPing, playerName) end)
end

-- @param from who sent ping ack, will be null if not called as result of a message
-- @param playerName the name of the player or contact for which ack was sent
function Standby:PingAck(from, playerName)
    Logging:Debug("PingAck(%s) : %s", tostring(from), tostring(playerName))
    if self:IsOperationRequired() then
        -- player name is always required
        if playerName then
            local standbyMember
            -- if from is specified, then the playerName should be the actual roster member's name
            -- not a contact, as it's specified in StandbyPing as an argument
            if from then
                standbyMember = self.roster[playerName]
            -- otherwise, we need to search for it
            else
                _, standbyMember = Tables.FindFn(
                        self.roster,
                        function(player) return player:IsPlayerOrContact(playerName) end
                )
            end
    
            if standbyMember then
                standbyMember:UpdateStatus(from and from or playerName, not Strings.IsEmpty(from))
                Logging:Debug("%s / %s : %s", tostring(from), tostring(playerName), Objects.ToString(standbyMember:toTable()))
                self:RefreshData()
            end
        end
    end
end

function Standby:PlayerNotFound(_, playerName)
    Logging:Trace("PlayerNotFound(%s)", tostring(playerName))
    self:PingAck(nil, playerName)
end


function Standby:AddPlayerFromMessage(msg, sender)
    local C = AddOn.Constants
    
    if self:IsOperationRequired() then
        local contacts = Tables.New(AddOn:GetArgs(msg, 3))
        local class = AddOn:GetUnitClass(sender)
        
        if Tables.Count(contacts) == 1 then
            contacts = {}
        else
            contacts = Tables.Sub(contacts, 1, Tables.Count(contacts) - 1)
        end
        
        Logging:Trace("AddPlayerFromMessage(%s) : %s", sender, Objects.ToString(contacts))
        
        self:AddPlayer(StandbyMember(sender, class, contacts))
        SendChatMessage(
                format(L["whisper_standby_ack"], Tables.Count(contacts) > 0 and Tables.Concat(contacts, ",") or "N/A"),
                C.Channels.Whisper, nil, sender
        )
    else
        SendChatMessage(
                format(L["whisper_standby_ignored"], AddOn.masterLooter),
                C.Channels.Whisper, nil, sender
        )
    end
end

-- @param player an instance of StandbyMember
function Standby:AddPlayer(player)
    -- only the master looter directly modifies the roster
    -- everyone else gets information via broadcasts
    if self:IsOperationRequired() then
        self.roster[player.name] = player
        self:RefreshData()
    end
end

function Standby:RemovePlayer(player)
    if self:IsOperationRequired() and player then
        Standby.roster[player.name] = nil
    end
end

function Standby:ResetRoster()
    if self.db.profile.enabled then self.roster = {} end
end

function Standby:PruneRoster()
    if self:IsOperationRequired() and self.db.profile.verify_after_each_award then
        local removed = false
        
        for _, player in pairs(self.roster) do
            if not player:IsOnline() then
                self:RemovePlayer(player)
                removed = true
            end
        end
        
        if removed then self:RefreshData() end
    end
end

function Standby:GetAwardRoster()
    if self:IsOperationRequired() then
        -- this is the trigger than award is being done, so if we check after each award then
        -- schedule pings and cleanup before returning result
        if  self.db.profile.verify_after_each_award then
            self:ScheduleTimer(function() self:PingPlayers() end, 2)
            self:ScheduleTimer(function() self:PruneRoster() end, 7)
        end
        
        local roster = {}
        for name, _ in pairs(self.roster) do
            Tables.Push(roster, name)
        end
        
        -- return roster of names and award %
        return roster, self.db.profile.standby_pct
    end
end