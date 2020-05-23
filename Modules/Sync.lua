local _, AddOn = ...
local Sync = AddOn:NewModule("Sync", "AceEvent-3.0", "AceTimer-3.0")
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local UI = AddOn.components.UI
local L = AddOn.components.Locale

function Sync:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.handlers = {}
    self.syncType = nil
    self.syncTarget = nil
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
        self.frame.syncType.Update()
        self.frame.syncTarget.Update()
        self.frame:Show()
    end
end

function Sync:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Sync:HandlersSelect()
    return Util(self.handlers)
            :Map(function (e) return e.desc end)
            :Copy()()
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

function Sync:AddHandler(name, desc, send, receive)
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

function Sync:GetFrame()
    if self.frame then return self.frame end
    
    local f = UI:CreateFrame("R2D2_Sync", "Sync",  L["r2d2_sync"], 250, 150)
    f:SetWidth(400)
    
    
    local syncType =
        UI('Dropdown')
            .SetWidth(f.content:GetWidth() * 0.4 - 20)
            .SetPoint("TOPLEFT", f.content, "TOPLEFT", 10, -50)
            .SetParent(f)()
    syncType:SetCallback(
            "OnValueChanged",
            function(_,_, key) self.syncType = key end
    )
    f.syncType = syncType
    function f.syncType.Update()
        local syncTypes, syncTypesSort = self:HandlersSelect(), {}
        for i, v in pairs(Util.Tables.ASort(syncTypes, function(a,b) return a[2] < b[2] end)) do
            syncTypesSort[i] = v[1]
        end
        
        if not self.syncType then
            self.syncType = syncTypesSort[1]
        end
        
        f.syncType:SetList(syncTypes, syncTypesSort)
        f.syncType:SetValue(self.syncType)
        f.syncType:SetText(syncTypes[self.syncType])
    end

    local syncLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    syncLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 15, -35)
    syncLabel:SetTextColor(1, 1, 1)
    syncLabel:SetText(L['sync_type'])
    f.syncLabel = syncLabel
    
    local syncTarget =
        UI('Dropdown')
            .SetWidth(f.content:GetWidth() * 0.6 - 20)
            .SetPoint("LEFT", f.syncType.frame, "RIGHT", 20, 0)
            .SetParent(f)()
    syncTarget:SetCallback(
            "OnValueChanged",
            function(_,_, key) self.syncTarget = key end
    )
    f.syncTarget = syncTarget
    function f.syncTarget.Update()
        f.syncTarget:SetList(self:AvailableSyncTargets())
    end
    
    
    local targetLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetLabel:SetPoint("BOTTOMLEFT", f.syncTarget.frame, "TOPLEFT", 0, 5)
    targetLabel:SetTextColor(1, 1, 1)
    targetLabel:SetText(L['sync_target'])
    f.targetLabel = targetLabel
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    close:SetScript("OnClick", function() self:Disable() end)
    f.close = close
    
    self.frame = f
    return self.frame
end