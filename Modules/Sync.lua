local _, AddOn = ...
local Sync = AddOn:NewModule("Sync", "AceEvent-3.0", "AceTimer-3.0")
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local UI = AddOn.components.UI
local L = AddOn.components.Locale
local Dialog = AddOn.Libs.Dialog

local Responses = {
    Declined    = { id=1, msg=L['sync_response_declined'] },
    Unavailable = { id=2, msg=L['sync_response_unavailable'] },
    Unsupported = { id=3, msg=L['sync_response_unsupported'] },
}

local IdToResponseKey =
    Util(Responses):Copy():Map(function (e) return e.id end):Flip()()

local function GetResponseById(id)
    local key = IdToResponseKey[tonumber(id)]
    if key then
        return Responses[key]
    else
        return {}
    end
end

function Sync:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.handlers = {}
    self.type = nil
    self.target = nil
    self.streams = {}
    self.ts = 0
end

function Sync:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self:Show()
end

function Sync:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
end

function Sync:EnableOnStartup()
    return false
end

function Sync:Show()
    if self.frame then
        self.frame.statusBar.Reset()
        self.frame.type.Update()
        self.frame.target.Update()
        self.frame:Show()
    end
end

function Sync:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Sync:AddHandler(name, desc, send, receive)
    if _G.R2D2_Testing then return end
    
    if Util.Strings.IsEmpty(name) then error("AddHandler() : must provide name") end
    if Util.Strings.IsEmpty(desc) then error("AddHandler() : must provide description") end
    if not Util.Objects.IsFunction(send) then error("AddHandler() : must provide a function for send()") end
    if not Util.Objects.IsFunction(receive) then error("AddHandler() : must provide a function for receive()") end
    
    self.handlers[name] = {
        desc = desc,
        send = send,
        receive = receive,
    }
end

function Sync:HandlersSelect()
    return Util(self.handlers)
            :Copy()
            :Map(function (e) return e.desc end)()
end

function Sync:AddStream(name, type, data)
    Logging:Debug("AddStream() : %s, %s", name, AddOn:UnitName(name))
    self.streams[name] = {[type] = data}
end

function Sync:GetStream(name)
    Logging:Debug("GetStream() : %s, %s", name, AddOn:UnitName(name))
    return self.streams[name]
end

function Sync:DropStream(name)
    Logging:Debug("DropStream() : %s, %s", name, AddOn:UnitName(name))
    self.streams[name] = nil
end

local function AddNameToList(l, name, class)
    l[name] =
        UI.ColoredDecorator(AddOn.GetClassColor(class):GetRGB())
            :decorate(tostring(name))
end

function Sync:AvailableSyncTargets()
    local name, online, class, targets = nil, nil, nil, {}
    
    for i = 1, GetNumGroupMembers() do
        name, _, _, _, _, class, _, online = GetRaidRosterInfo(i)
        if online then
            AddNameToList(targets, AddOn:UnitName(name), class)
        end
    end
    
    for i = 1, GetNumGuildMembers() do
        name, _, _, _, _, _, _, _, online,_,class = GetGuildRosterInfo(i)
        if online then
            AddNameToList(targets, AddOn:UnitName(name), class)
        end
    end
    
    if not AddOn:DevModeEnabled() then
        targets[AddOn.playerName] = nil
    end
    
    if Util.Tables.Count(targets) == 0 then
        targets[1] = format("-- %s --", L['no_recipients_avail'])
    end
    
    table.sort(targets, function (a,b) return a > b end)
    Logging:Trace("%s", Util.Objects.ToString(targets))
    
    return targets
end

function Sync:GetFrame()
    if self.frame then return self.frame end
    
    local f = UI:CreateFrame("R2D2_Sync", "Sync",  L["r2d2_sync"], 250, 150)
    f:SetWidth(400)
    
    local type =
        UI('Dropdown')
            .SetWidth(f.content:GetWidth() * 0.4 - 20)
            .SetPoint("TOPLEFT", f.content, "TOPLEFT", 10, -50)
            .SetParent(f)()
    type:SetCallback(
            "OnValueChanged",
            function(_,_, key) self.type = key end
    )
    f.type = type
    function f.type.Update()
        local syncTypes, syncTypesSort = self:HandlersSelect(), {}
        for i, v in pairs(Util.Tables.ASort(syncTypes, function(a,b) return a[2] < b[2] end)) do
            syncTypesSort[i] = v[1]
        end
        
        if not self.type then
            self.type = syncTypesSort[1]
        end
        
        f.type:SetList(syncTypes, syncTypesSort)
        f.type:SetValue(self.type)
        f.type:SetText(syncTypes[self.type])
    end

    local typeLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 15, -35)
    typeLabel:SetTextColor(1, 1, 1)
    typeLabel:SetText(L['sync_type'])
    f.typeLabel = typeLabel
    
    local target =
        UI('Dropdown')
            .SetWidth(f.content:GetWidth() * 0.6 - 20)
            .SetPoint("LEFT", f.type.frame, "RIGHT", 20, 0)
            .SetParent(f)()
    target:SetCallback(
            "OnValueChanged",
            function(_,_, key) self.target = key end
    )
    f.target = target
    function f.target.Update()
        f.target:SetList(self:AvailableSyncTargets())
    end
    
    
    local targetLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetLabel:SetPoint("BOTTOMLEFT", f.target.frame, "TOPLEFT", 0, 5)
    targetLabel:SetTextColor(1, 1, 1)
    targetLabel:SetText(L['sync_target'])
    f.targetLabel = targetLabel
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    close:SetScript("OnClick", function() self:Disable() end)
    f.close = close
    
    local help =  UI:CreateButton(nil, f.content)
    help:SetNormalTexture("Interface/GossipFrame/ActiveQuestIcon")
    help:SetSize(15,15)
    help:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -10, -10)
    help:SetScript("OnLeave", function() UI:HideTooltip() end)
    help:SetScript("OnEnter", function()
        UI:CreateTooltip(L["sync_header"], " ", L["sync_detailed_description"])
    end)
    f.help = help
    
    local sync = UI:CreateButton(L['sync'], f.content)
    sync:SetPoint("RIGHT", f.close, "LEFT", -25)
    sync:SetScript(
            "OnClick",
            function()
                if not self.target then
                    return AddOn:Print(L["sync_target_not_specified"])
                end
                if not self.type then
                    return AddOn:Print(L["sync_type_not_specified"])
                end
                
                Logging:Debug("Sync() : %s, %s, %s", tostring(self.target), tostring(self.type), Util.Objects.ToString(self.handlers[self.type]))
                self:SendSyncSYN(self.target, self.type, self.handlers[self.type].send())
            end
    )
    self.sync = sync
    
    local statusBar = CreateFrame("StatusBar", nil, f.content, "TextStatusBar")
    statusBar:SetSize(f.content:GetWidth() - 20, 15)
    statusBar:SetPoint("TOPLEFT", f.type.frame, "BOTTOMLEFT", 0, -10)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.1, 0, 0.6, 0.8)
    statusBar:SetMinMaxValues(0, 100)
    statusBar:Hide()
    f.statusBar = statusBar
    
    statusBar.text = f.statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusBar.text:SetPoint("CENTER", f.statusBar)
    statusBar.text:SetTextColor(1,1,1)
    statusBar.text:SetText("")
    
    function f.statusBar.Reset()
        f.statusBar:Hide()
        f.statusBar.text:Hide()
    end
    
    function f.statusBar.Update(value, text)
        f.statusBar:Show()
        if tonumber(value) then f.statusBar:SetValue(value) end
        f.statusBar.text:Show()
        f.statusBar.text:SetText(text)
    end
    
    self.frame = f
    return self.frame
end


function Sync.ConfirmSyncOnShow(frame, data)
    UI.DecoratePopup(frame)
    
    local sender,_, text = unpack(data)
    frame.text:SetText(format(L["incoming_sync_message"], text, sender))
end


local function SendSyncData(target, type)
    Logging:Debug("SendSyncData() : Sending %s to %s", type, target)
    local C = AddOn.Constants
    
    local stream = Sync:GetStream(target)
    local toSend = AddOn:PrepareForSend(C.Commands.Sync, AddOn.playerName, type, stream[type])
    
    -- sending to ourselves
    if AddOn:UnitIsUnit(target, "player") then
        AddOn:SendCommMessage(C.name, toSend, C.Channels.Whisper, AddOn.playerName, "BULK", Sync.OnDataTransmit, Sync)
    -- sending to others
    else
        AddOn:SendCommMessage(C.name, toSend, C.Channels.Whisper, target, "BULK", Sync.OnDataTransmit, Sync)
    end
    
    Logging:Debug("SendSyncData() : Sent %s to %s", type, target)
end

local SyncSYNInterval = 15

function Sync:SendSyncSYN(target, type, data)
    Logging:Debug("SendSyncSYN() : %s, %s", target, type)
    
    if time() - self.ts < (AddOn:DevModeEnabled() and 0 or SyncSYNInterval) then
        return AddOn:Print(format(L["sync_rate_exceeded"], SyncSYNInterval))
    end
    
    AddOn:SendCommand(target, AddOn.Constants.Commands.SyncSYN, AddOn.playerName, type)
    self:AddStream(target, type, data)
    self.ts = time()
end

function Sync:SyncSYNReceived(sender, type)
    Logging:Debug("SyncSYNReceived() : %s, %s", sender, type)
    
    -- don't allow for other players to spam sync requests should
    -- we not have the sync interface open
    --
    -- prevents malicious activity and also general interruption of game play
    if not self:IsEnabled() or (not self.frame and not self.frame:IsVisible()) then
        return self:DeclineSync(sender, type, Responses.Unavailable.id)
    end
    
    local handler = self.handlers[type]
    
    if handler then
        Dialog:Spawn(AddOn.Constants.Popups.ConfirmSync, {sender, type, handler.desc})
    else
        self:DeclineSync(sender, type, Responses.Unsupported.id)
    end
end

local function GetDateTime()
    return date("%m/%d/%y %H:%M:%S", time())
end


function Sync:SyncACKReceived(sender, type)
    Logging:Debug("SyncACKReceived() : %s, %s", sender, type)
    local stream = self:GetStream(sender)
    if not stream or not stream[type] then
        Logging:Warn("SyncACKReceived() : '%s' data unavailable for syncing to %s", type, sender)
        return AddOn:Print(format(L["sync_error"], type, sender))
    end
    SendSyncData(sender, type)
    self:DropStream(sender)
    AddOn:Print(format(L['sync_starting'], GetDateTime(), type, sender))
end

function Sync:SyncNACKReceived(sender, type, responseId)
    Logging:Debug("SyncNACKReceived() : %s, %s, %s", sender, type, tostring(responseId))
    self:DropStream(sender)
    local response = GetResponseById(responseId)
    AddOn:Print(format(response.msg, sender, type))
end

function Sync:SyncDataReceived(sender, type, data)
    Logging:Debug("SyncDataReceived() : %s, %s", tostring(sender), tostring(type))
    
    self.frame.statusBar.Update(nil, L["data_received"])
    local handler = self.handlers[type]
    if handler then
        handler.receive(data)
    else
        Logging:Warn("SyncDataReceived() : unsupported type %s from %s", type, sender)
    end
    AddOn:Print(format(L['sync_receipt_compelete'], GetDateTime(), type, sender))
end

function Sync.OnSyncAccept(_, data)
    Logging:Debug("OnSyncAccept() : %s", Util.Objects.ToString(data))
    local sender, type = unpack(data)
    AddOn:SendCommand(sender, AddOn.Constants.Commands.SyncACK, AddOn.playerName, type)
    Sync.frame.statusBar.Update(nil, _G.RETRIEVING_DATA)
end

function Sync.OnSyncDelcine(_, data)
    Logging:Debug("OnSyncDelcine() : %s", Util.Objects.ToString(data))
    local sender, type = unpack(data)
    Sync:DeclineSync(sender, type, Responses.Declined.id)
end

function Sync:DeclineSync(sender, type, reason)
    Logging:Debug("DeclineSync : %s, %s, %s", tostring(sender), tostring(type), tostring(reason))
    AddOn:SendCommand(sender, AddOn.Constants.Commands.SyncNACK, AddOn.playerName, type, reason)
end

function Sync:OnDataTransmit(num, total)
    if not self:IsEnabled() or not self.frame then return end
    Logging:Debug("OnDataTransmit(%d, %d)", num, total)
    local pct = (num/total) * 100
    self.frame.statusBar.Update(
            pct,
            Util.Numbers.Round2(pct) .. "% - " .. Util.Numbers.Round2(num/1000) .."KB / ".. Util.Numbers.Round2(total/1000) .. "KB"
    )
    
    if num == total then
        AddOn:Print(format(L["sync_complete"], GetDateTime()))
        Logging:Debug("OnDataTransmit() : Data transmission complete")
    end
end