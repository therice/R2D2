local name, AddOn = ...
local VersionCheck = AddOn:NewModule("VersionCheck", "AceTimer-3.0", "AceComm-3.0", "AceHook-3.0")
local ST = AddOn.Libs.ScrollingTable
local Logging = AddOn.components.Logging
local L = AddOn.components.Locale
local SemanticVersion = AddOn.components.Models.SemanticVersion
local Util = AddOn.Libs.Util
local UI = AddOn.components.UI
local Date = AddOn.components.Models.Date

local VersionZero = SemanticVersion(0,0,0,0)
local guildRanks, listOfNames, verTestCandidates, mostRecentVersion = {}, {}, {}, VersionZero

function VersionCheck:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.scrollCols = {
        {
            name     = "",
            width    = 20,
            sortnext = 2,
        },
        {
            name        = _G.NAME,
            width       = 150,
            defaultsort = ST.SORT_ASC
        },
        {
            name        = _G.RANK,
            width       = 90,
            comparesort = function(table, rowa, rowb, sortbycol)
                return UI.Sort(table, rowa, rowb, sortbycol,
                               function(row)
                                   return guildRanks[row.rank] or 100
                               end
                )
            end
        },
        {
            name        = L["version"],
            width       = 140,
            align       = "RIGHT",
            comparesort = function(table, rowa, rowb, sortbycol)
                return UI.Sort(table, rowa, rowb, sortbycol, function(row)
                    return row.version and row.version or VersionZero
                end)
            end,
            sort        = ST.SORT_DSC,
            sortnext    = 2
        },
    }
end

function VersionCheck:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self:RegisterComm(name)
    self:Show()
    guildRanks = AddOn:GetGuildRanks()
end


function VersionCheck:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
    self:UnregisterAllComm()
    self.frame.rows = {}
    wipe(listOfNames)
end

function VersionCheck:EnableOnStartup()
    return false
end

function VersionCheck:Show()
    self:AddEntry(AddOn.playerName, AddOn.playerClass, AddOn.guildRank, AddOn.version, AddOn.mode)
    self.frame:Show()
    self.frame.st:SetData(self.frame.rows)
end

function VersionCheck:Hide()
    self.frame:Hide()
end

function VersionCheck:OnCommReceived(prefix, serializedMsg, dist, sender)
    if prefix == name then
        local success, command, data = AddOn:Deserialize(serializedMsg)
        if success and command == AddOn.Constants.Commands.VersionCheckReply then
            if listOfNames[data[1]] then
                local name, class, guildRank, v, m = unpack(data)
                local version = SemanticVersion():reconstitute(v)
                local mode = AddOn.Mode():reconstitute(m)
                self:AddEntry(name, class, guildRank, version, mode)
            end
        end
    end
end

function VersionCheck:Query(group)
    Logging:Trace("Query(%s)", group)
    local C = AddOn.Constants
    
    if group == C.guild then
        GuildRoster()
        for i = 1, GetNumGuildMembers() do
            local name, rank, _,_,_,_,_,_, online,_, class = GetGuildRosterInfo(i)
            if online then
                self:AddEntry(name, class, rank)
            end
        end
    elseif group == "group" then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class, _, online = GetRaidRosterInfo(i)
            if online then
                self:AddEntry(name, class, _G.UNKNOWN)
            end
        end
    end
    
    AddOn:SendCommand(group, C.Commands.VersionCheck, AddOn.version, AddOn.mode)
    self:AddEntry(AddOn.playerName, AddOn.playerClass, AddOn.guildRank, AddOn.version, AddOn.mode)
    self:ScheduleTimer("QueryTimer", 5)
end

function VersionCheck:QueryTimer()
    for k, _ in pairs(self.frame.rows) do
        local cell = self.frame.st:GetCell(k, 4)
        if cell.value == L["waiting_for_response"] then
            cell.value = L["not_installed"]
        end
    end
    
    self:Update()
end


function VersionCheck:AddEntry(name, class, guildRank, version, mode)
    name = AddOn:UnitName(name)
    Logging:Trace("AddEntry(%s) : %s, %s, %s", tostring(name), tostring(class), tostring(guildRank), tostring(version))
    if version and (mostRecentVersion < version) then
        mostRecentVersion = version
    end
    
    local function NewRowCols()
        return {
            {
                value        = "",
                DoCellUpdate = AddOn.SetCellClassIcon,
                args         = { class },
            },
            {
                value = AddOn.Ambiguate(name),
                color = AddOn.GetClassColor(class)
            },
            {
                value     = guildRank,
                color     = self.GetVersionColor,
                colorargs = { self, version, mode }
            },
            {
                value        = (version and tostring(version)) or L["waiting_for_response"],
                color        = self.GetVersionColor,
                colorargs    = { self, version, mode },
                DoCellUpdate = self.SetCellMode,
                args         = mode
            },
        }
    end
    
    for _, v in ipairs(self.frame.rows) do
        if AddOn:UnitIsUnit(v.name, name) then
            v.cols = NewRowCols()
            v.rank = guildRank
            v.version = version
            return self:Update()
        end
    end
    
    Util.Tables.Push(self.frame.rows,
                     {
                         name = name,
                         rank = guildRank,
                         version = version,
                         cols = NewRowCols(),
                     }
    )
    listOfNames[name] = true
    self:Update()
end

function VersionCheck:Update()
    self.frame.st:SortData()
end

function VersionCheck:GetVersionColor(ver, mode)
    -- Logging:Debug("GetVersionColor(%s, %s)", tostring(ver), tostring(mode))
    local green, yellow, red, grey = {r=0,g=1,b=0,a=1}, {r=1,g=1,b=0,a=1}, {r=1,g=0,b=0,a=1}, {r=0.75,g=0.75,b=0.75,a=1}
    -- if development mode
    if mode and mode:Enabled(AddOn.Constants.Modes.Develop) then return yellow end
    if ver and (ver == mostRecentVersion) then return green end
    if ver and (ver < mostRecentVersion) then return red end
    return grey
end

function VersionCheck.SetCellMode(rowFrame, f, data, cols, row, realrow, column, fShow, table, ...)
    local mode = data[realrow].cols[column].args
    local modeDeco = UI.ColoredDecorator(1, 1, 0)
    
    if mode then
        -- add the modes that are enabled to tooltip
        local modes = {}
        for k, v in pairs(AddOn.Constants.Modes) do
            if v ~= AddOn.Constants.Modes.Standard and mode:Enabled(v) then
                Util.Tables.Push(modes, modeDeco:decorate(tostring(k)))
            end
        end
        
        f:SetScript("OnEnter", function()
            UI:CreateTooltip(UI.ColoredDecorator(0, 1, 0):decorate(L["modes"] .. '\n'), unpack(modes))
            table.DefaultEvents.OnEnter(rowFrame, f, data, cols, row, realrow, column, table)
        end)
        f:SetScript("OnLeave", function()
            UI:HideTooltip()
            table.DefaultEvents.OnLeave(rowFrame, f, data, cols, row, realrow, column, table)
        end)
    else
        f:SetScript("OnEnter", function()
            table.DefaultEvents.OnEnter(rowFrame, f, data, cols, row, realrow, column, table)
        end)
    end
    table.DoCellUpdate(rowFrame, f, data, cols, row, realrow, column, fShow, table)
end

function VersionCheck:GetFrame()
    if self.frame then return self.frame end
    local f = UI:CreateFrame("R2D2_VersionCheck", "VersionCheck",  L["r2d2_version_check_frame"], 250)
    
    local b1 = UI:CreateButton(_G.GUILD, f.content)
    b1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    b1:SetScript("OnClick", function() self:Query("guild") end)
    f.guildBtn = b1
    
    local b2 = UI:CreateButton(_G.GROUP, f.content)
    b2:SetPoint("LEFT", b1, "RIGHT", 15, 0)
    b2:SetScript("OnClick", function() self:Query("group") end)
    f.raidBtn = b2
    
    local b3 = UI:CreateButton(_G.CLOSE, f.content)
    b3:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    b3:SetScript("OnClick", function() self:Disable() end)
    f.closeBtn = b3
    
    local st = ST:CreateST(self.scrollCols, 12, 20, nil, f.content)
    st.frame:SetPoint("TOPLEFT",f,"TOPLEFT",10,-35)
    f:SetWidth(st.frame:GetWidth()+20)
    f.rows = {}
    f.st = st
    return f
end

function VersionCheck:TrackVersion(name, version, mode)
    verTestCandidates[name] = {
        version,
        mode,
        Date()
    }
end

function VersionCheck:PrintOutOfDateClients()
    local outOfDate, isGrouped = {}, IsInGroup()
    for name, data in pairs(verTestCandidates) do
        if (isGrouped and AddOn.candidates[name]) or not isGrouped then
            local version, _, _ = data[1], data[2], data[3]
            if version < AddOn.version then
                Util.Tables.Push(AddOn:GetUnitClassColoredName(name) .. ' : ' .. tostring(version))
            end
        end
    end
    
    if Util.Tables.Count(outOfDate) > 0 then
        AddOn:Print(L["the_following_versions_are_out_of_date"])
        for _, v in pairs(outOfDate) do
            AddOn:Print(v)
        end
    else
        AddOn:Print(L["everyone_up_to_date"])
    end
end

function VersionCheck.CheckVersion(base, new)
    local C = AddOn.Constants
    
    base = base or AddOn.version
    if base < new then
        return C.VersionStatus.OutOfDate
    else
        return C.VersionStatus.Current
    end
end

