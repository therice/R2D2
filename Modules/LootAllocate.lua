local name, AddOn = ...
local LootAllocate  = AddOn:NewModule("LootAllocate", "AceComm-3.0", "AceTimer-3.0", "AceEvent-3.0", "AceBucket-3.0")
local Dialog        = AddOn.Libs.Dialog
local Logging       = AddOn.Libs.Logging
local L             = AddOn.components.Locale
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util
local Models        = AddOn.components.Models

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 15, 0.2
local GuildRankSort, ResponseSort, EpSort, GpSort, PrSort
local MenuFrame, FilterMenu, Enchanters
-- session is a number mapping to item
-- sessionButtons is mapping of session to IconBordered instances
-- lootTable is a mapping of session to AllocateEntry instances
local session, sessionButtons, lootTable, guildRanks, active = 1, {}, {}, {}, false
local updatePending, updateIntervalRemaining, updateFrame = false, 0, CreateFrame("FRAME")

LootAllocate.defaults = {
    profile = {
        awardReasons = {

        }
    }
}

-- Copy defaults from GearPoints into our defaults for buttons/responses
-- This actually should be done via the AddOn's DB once it's initialized, but we currently
-- don't allow users to change these values (either here or from GearPoints) so we can
-- do it before initialization. If we allow for these to be configured by user, then will
-- need to copy from DB
do
    local AwardReasons = LootAllocate.defaults.profile.awardReasons
    local GP = AddOn:GetModule("GearPoints")
    local AwardScaling = GP.defaults.profile.award_scaling
    local NonUserVisibleAwards =
        Util(AwardScaling)
            :CopyFilter(function (v) return not v.user_visible end, true, nil, true)
            :Keys()()

    AwardReasons.numAwardReasons = Util.Tables.Count(NonUserVisibleAwards)
    local sortLevel = 401
    for index, award in ipairs(NonUserVisibleAwards) do
        -- Logging:Trace("%s", Util.Objects.ToString(AwardScaling[award]))
        Util.Tables.Insert(AwardReasons, index, { color = AwardScaling[award].color, sort=sortLevel, text = L[award], award_scale=award})
        sortLevel = sortLevel + 1
    end
end

function LootAllocate:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    self.scrollCols = {
        { name = "",                DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellClass),    colName = "class",      sortnext = 2,       width = 20, }, -- 1 Class
        { name = _G.NAME,			DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellName),		colName = "name",		defaultsort = 1,	width = 120,}, -- 2 Candidate Name
        { name = _G.RANK,			DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellRank),		colName = "rank",		sortnext = 4,		width = 95, comparesort = GuildRankSort,}, -- 3 Guild rank
        { name = L["response"],	    DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellResponse),	colName = "response",   sortnext = 7,		width = 240,comparesort = ResponseSort,}, -- 4 Response
        { name = L["ep_abbrev"],	DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellEp),		colName = "ep",		    sortnext = 6,		width = 45, comparesort = EpSort,}, -- 5 EP
        { name = L["gp_abbrev"],	DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellGp),		colName = "gp",		    sortnext = 9,		width = 45, comparesort = GpSort,}, -- 6 GP
        { name = L["pr_abbrev"],	DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellPr),		colName = "pr",		    sortnext = 13,	    width = 45, comparesort = PrSort,}, -- 7 PR
        { name = _G.ITEM_LEVEL_ABBR,DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellIlvl),	    colName = "ilvl",		sortnext = 9,		width = 45, }, -- 8 Total ilvl
        { name = L["diff"],		    DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellDiff),		colName = "diff",							width = 40, }, -- 9 ilvl difference
        { name = L["g1"],			DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellGear),		colName = "gear1",                          width = 20, align = "CENTER", }, -- 10 Current gear 1
        { name = L["g2"],			DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellGear),		colName = "gear2",	                        width = 20, align = "CENTER", }, -- 11 Current gear 2
        { name = L["notes"],		DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellNote),		colName = "note",							width = 50, align = "CENTER", }, -- 12 Note icon
        { name = _G.ROLL,			DoCellUpdate = UI.ScrollingTableDoCellUpdate(LootAllocate.SetCellRoll), 	colName = "roll",		sortnext = 5,		width = 50, align = "CENTER", }, -- 13 Roll
    }
    self.db = AddOn.db:RegisterNamespace(self:GetName(), LootAllocate.defaults)
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.AllocateRightClick, UIParent)
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.AllocateFilter, UIParent)
    Enchanters = MSA_DropDownMenu_Create(C.DropDowns.Enchanters, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
    MSA_DropDownMenu_Initialize(Enchanters, self.EnchantersMenu)
end

function LootAllocate:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self:RegisterComm(name, "OnCommReceived")
    -- Update "Out of instance" text when any raid members change zone
    self:RegisterBucketEvent({"UNIT_PHASE", "ZONE_CHANGED_NEW_AREA"}, 1, "Update")
    self.frame = self:GetFrame()
    self:ScheduleTimer("CandidateCheck", 5)
    guildRanks = AddOn:GetGuildRanks()
    updateFrame:Show()
    updatePending = false
    updateIntervalRemaining = 0
end

function LootAllocate:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:SetParent(nil)
    self.frame = nil
    Util.Tables.Wipe(AddOn.lootStatus)
    Util.Tables.Wipe(lootTable)
    active = false
    session = 1
    self:UnregisterAllComm()
    updateFrame:Hide()
    updatePending = false
    updateIntervalRemaining = 0
end

function LootAllocate:EnableOnStartup()
    return false
end

function LootAllocate:Hide()
    self.frame.moreInfo:Hide()
    self.frame:Hide()
end

function LootAllocate:Show()
    -- Logging:Trace("Show()")
    if self.frame and lootTable[session] then
        if self:HasUnawardedItems() then active = true end
        self.frame:Show()
        self:SwitchSession(session)
    else
        AddOn:Print(L["session_not running"])
    end
end

function LootAllocate:HasUnawardedItems()
    for _,v in pairs(lootTable) do
        if not v.awarded then return true end
    end
    return false
end

-- lt is a table of ItemEntry(s), which is passed in from AddOn (via Comm)
-- when LootTable command is received (provided applicable conditions are met)
function LootAllocate:ReceiveLootTable(lt)
    active = true
    --Logging:Debug("ReceiveLootTable(BEFORE) : %s", Util.Objects.ToString(lt, 4))
    lootTable = Util(lt):Copy():Map(function(entry) return entry:ToAllocateEntry() end)()
    --Logging:Debug("ReceiveLootTable(AFTER) : %s", Util.Objects.ToString(lootTable, 4))
    self:Setup(lootTable)
    if not AddOn.enabled then return end
    self:Show()
end

-- @param session the session id
-- @return the AllocateEntry for the specified session id
function LootAllocate.GetLootTableEntry(session)
    -- Logging:Debug("GetLootTableEntry(%d) : %s", session, Util.Objects.ToString(lootTable[session].candidates))
    if not Util.Objects.IsNumber(session) then session = tonumber(session) end
    return lootTable[session]
end

-- @param session the session id
-- @param candidate the candidate name
--@return the CandidateResponse for the specified session id and candidate name
function LootAllocate.GetLootTableEntryResponse(session, candidate)
    return LootAllocate.GetLootTableEntry(session):GetCandidateResponse(candidate)
end

function LootAllocate:EndSession(hide)
    if active then
        Logging:Debug("EndSession(%s)", tostring(hide))
        active = false
        self:Update(true)
        if hide then self:Hide() end
    end
end

-- entry must be of type Item.AllocateEntry
function LootAllocate:SetupSession(session, entry)
    entry.added = true
    -- Logging:Trace("SetupSession(%s) : %s", tostring(session), Util.Objects.ToString(entry))
    for name, v in pairs(AddOn.candidates) do
        entry:AddCandidateResponse(name, v.class, v.rank)
    end
    -- Init session toggle
    sessionButtons[session] = self:UpdateSessionButton(session, entry.texture, entry.link, entry.awarded)
    sessionButtons[session]:Show()
end

-- entries is a table of Item.AllocateEntry(s)
function LootAllocate:Setup(entries)
    for session, entry in ipairs(entries) do
        if not entry.added then
            self:SetupSession(session, entry)
        end
    end
    -- Hide unused session buttons
    for i = #lootTable+1, #sessionButtons do
        sessionButtons[i]:Hide()
    end
    session = 1
    self:BuildScrollingTable()
    self:SwitchSession(session)

    local autoRolls = false
    if AddOn.isMasterLooter and autoRolls then
        self:DoAllRandomRolls()
    end
end

function LootAllocate:SwitchSession(sess)
    -- Logging:Debug("SwitchSession(%d)", sess)
    
    local C = AddOn.Constants
    session = sess
    local entry = LootAllocate.GetLootTableEntry(sess)
    self.frame.itemIcon:SetNormalTexture(entry.texture)
    self.frame.itemIcon:SetBorderColor("purple")
    self.frame.itemText:SetText(entry.link)
    self.frame.iState:SetText(self:GetItemStatus(entry.link))
    self.frame.itemLvl:SetText(_G.ITEM_LEVEL_ABBR..": " .. entry:GetLevelText())
    self.frame.gp:SetText("GP: " .. AddOn:GearPointsModule():GetGpTextColored(entry, nil))
    self.frame.itemType:SetText(entry:GetTypeText())

    --[[
    if entry.owner then
        self.frame.ownerString.icon:Hide()
        self.frame.ownerString.owner:SetText(entry.owner)
        self.frame.ownerString.owner:SetTextColor(1,1,1,1)
        self.frame.ownerString.owner:Show()
    else
        self.frame.ownerString.icon:Hide()
        self.frame.ownerString.owner:Hide()
    end
    --]]

    self:UpdateSessionButtons()
    local j = 1
    for i in ipairs(self.frame.st.cols) do
        self.frame.st.cols[i].sort = nil
        if self.frame.st.cols[i].colName == "response" then j = i end
    end
    self.frame.st.cols[j].sort = 1
    FauxScrollFrame_OnVerticalScroll(self.frame.st.scrollframe, 0, self.frame.st.rowHeight, function() self.frame.st:Refresh() end)
    self:Update(true)

    AddOn:SendMessage(C.Messages.SessionChangedPost, sess)
end

function LootAllocate:GetCurrentSession()
    return session
end

--- Find an un-awarded session.
-- @return number|nil Number of the first session with an un-awarded item, or nil if everything is awarded.
function LootAllocate:FetchUnawardedSession()
    for k,v in ipairs(lootTable) do
        if not v.awarded then return k end
    end
    return nil
end

function LootAllocate:SetCandidateData(session, candidate, data, val)
    local function Set(session, candidate, data, val)
        --Logging:Debug("SetCandidateData(%s, %s) : data=%s val=%s", session, candidate, Util.Objects.ToString(data), Util.Objects.ToString(val))
        LootAllocate.GetLootTableEntryResponse(session, candidate):Set(data, val)
    end
    local ok, _ = pcall(Set, session, candidate, data, val)
    if not ok then
        Logging:Warn("SetCandidateData() : Error for candidate %s", candidate)
    end
end

function LootAllocate:GetCandidateData(session, candidate, data)
    local function Get(session, candidate, data)
        return LootAllocate.GetLootTableEntryResponse(session, candidate):Get(data)
    end
    
    local ok, arg = pcall(Get, session, candidate, data)
    if not ok then
        Logging:Warn("GetCandidateData() : Error for candidate %s", candidate)
    else
        return arg
    end
end

-- this seems like it shouldn't be needed and could be evaluated for elimination
function LootAllocate:CandidateCheck()
    -- our name isn't present, assume not received
    if not AddOn.candidates[AddOn.playerName] and Util.Strings.IsSet(AddOn.masterLooter) then
        local C = AddOn.Constants
        Logging:Warn("CandidateCheck() : Failed (our name is not present on candidate list)")
        AddOn:SendCommand(AddOn.masterLooter, C.Commands.CandidatesRequest)
        self:ScheduleTimer("CandidateCheck", 5)
    end
end

function LootAllocate:AnnounceResponse(session, name)
    local ML = AddOn:MasterLooterModule()
    
    if AddOn.isMasterLooter and ML:DbValue('announceResponses') then
        local userResponse = LootAllocate.GetLootTableEntryResponse(session, name)
        if userResponse and tonumber(userResponse.response) ~= nil then
            local entry = LootAllocate.GetLootTableEntry(session)
            local pointRecord = AddOn:PointsModule().GetEntry(name)
            local response = AddOn:GetResponse(entry.typeCode or entry.equipLoc, userResponse.response)
            local baseGp, awardGp = entry:GetGp(response.award_scale)
    
            local announceSettings = ML:DbValue('announceResponseText')
            local channel, text = announceSettings.channel, announceSettings.text
            
            -- L["response_to_item_detailed"] = "%s (PR %.2f) specified %s for %s (GP %d/%d)"
            local announcement = format(text,
                                        AddOn.Ambiguate(name),
                                        (pointRecord and pointRecord:GetPR() or 0.0),
                                        (response and response.text or "???"),
                                        entry.link,
                                        awardGp and awardGp or baseGp,
                                        baseGp
            )
            
            AddOn:SendAnnouncement(announcement, channel)
        end
    end
end

function LootAllocate:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)
    
    local C = AddOn.Constants
    if prefix == C.name then
        local success, command, data = AddOn:ProcessReceived(serializedMsg)
        local fromMl = AddOn:UnitIsUnit(sender, AddOn.masterLooter)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, from=%s, dist=%s, fromMl=%s, data=%s,",
                      tostring(success), command, tostring(sender), tostring(dist),
                      tostring(fromMl),
                      Logging:IsEnabledFor(Logging.Level.Trace) and Util.Objects.ToString(data, 1) or '[omitted]'
        )
        
        if success then
            if command == C.Commands.ChangeResponse then
                local ses, name, response = unpack(data)
                self:SetCandidateData(ses, name, "response", response)
                self:Update()
            elseif command == C.Commands.LootAck then
                local name, ilvl, sessionData = unpack(data)
                for key, d in pairs(sessionData) do
                    for sess, value in pairs(d) do
                        self:SetCandidateData(sess, name, key, value)
                    end
                end
                for i = 1, #lootTable do
                    self:SetCandidateData(i, name, "ilvl", ilvl)
                    if not sessionData.response[i] then
                        if self:GetCandidateData(i, name, "response") == "ANNOUNCED" then
                            self:SetCandidateData(i, name, "response", "WAIT")
                        end
                    elseif sessionData.response[i] == true then
                        self:SetCandidateData(i, name, "response", "AUTOPASS")
                    end
                end

                self:Update()
            elseif command == C.Commands.Awarded and fromMl then
                -- moved moreInfoData out of here int common UI functions Core/UI.lua
                -- self:ScheduleTimer(function() moreInfoData = AddOn:GetLootDbStatistics() end, 1)
                local awardSession, winner = unpack(data)
                local entry = self.GetLootTableEntry(awardSession)
                if not entry then
                    Logging:Warn("No Loot Table Entry for session %d", awardSession)
                    return
                end

                local oldWinner = entry.awarded
                for s2, e2 in ipairs(lootTable) do
                    if AddOn:ItemIsItem(e2.link, entry.link) then
                        -- re-awarded
                        if oldWinner and not AddOn:UnitIsUnit(oldWinner, winner) then
                            self:SetCandidateData(s2, oldWinner, "response", self:GetCandidateData(s2, oldWinner, "real_response"))
                        end
                        self:SetCandidateData(s2, winner, "real_response", self:GetCandidateData(s2, winner, "response"))
                        self:SetCandidateData(s2, winner, "response", "AWARDED")
                    end
                end

                entry.awarded = winner

                local nextSession = self:FetchUnawardedSession()
                if AddOn.isMasterLooter and nextSession then
                    self:SwitchSession(nextSession)
                else
                    self:SwitchSession(session)
                end
            elseif command == C.Commands.OfflineTimer and fromMl then
                for i = 1, #lootTable do
                    for candidate in pairs(lootTable[i].candidates) do
                        if self:GetCandidateData(i, candidate, "response") == "ANNOUNCED" then
                            Logging:Warn("No response from %s for item %d", candidate, i)
                            self:SetCandidateData(i, candidate, "response", "NOTHING")
                        end
                    end
                end
                self:Update()
            elseif command == C.Commands.Response then
                local session, name, t = unpack(data)
                for key, value in pairs(t) do
                    self:SetCandidateData(session, name, key, value)
                end
                self:Update()

                -- Announce the response, this is relevant when run via Master Looter
                self:AnnounceResponse(session, name)
            elseif command == C.Commands.Rolls then
                if fromMl then
                    local session, table = unpack(data)
                    for name, roll in pairs(table) do
                        self:SetCandidateData(session, name, "roll", roll)
                    end
                    self:Update()
                else
                    Logging:Warn("Non-MasterLooter %s sent rolls", sender)
                end
            elseif command == C.Commands.Roll then
                local name, roll, sessions = unpack(data)
                for _, ses in ipairs(sessions) do
                    self:SetCandidateData(ses, name, "roll", roll)
                end
                self:Update()
            elseif command == C.Commands.LootTableAdd and fromMl then
                local oldLen = #lootTable
                for index, entry in pairs(unpack(data)) do
                    -- Logging:Debug("LootTableAdd(%s, %s) : %s", tostring(oldLen), tostring(index), Util.Objects.ToString(entry, 4))
                    lootTable[index] = Models.ItemEntry:new():reconstitute(entry):ToAllocateEntry()
                end

                local autoRolls = false
                for i = oldLen + 1, #lootTable do
                    self:SetupSession(i, lootTable[i])
                    if AddOn.isMasterLooter and autoRolls then self:DoRandomRolls(i) end
                end
                self:SwitchSession(session)
            end
        end
    end

end

function LootAllocate:BuildScrollingTable()
    local rows = {}
    local i = 1
    for name in pairs(AddOn.candidates) do
        local data = {}
        for num, col in ipairs(self.scrollCols) do
            data[num] = {value = "", colName = col.colName}
        end
        rows[i] = {
            name = name,
            cols = data,
        }
        i = i + 1
    end
    
    Logging:Debug("BuildScrollingTable() : Adding %d candidates to table", (i - 1))
    
    self.frame.st:SetData(rows)
end

function ResponseSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
        function(row)
            local lte = LootAllocate.GetLootTableEntry(session)
            return AddOn:GetResponse(
                    lte.typeCode or lte.equipLoc,
                    lte:GetCandidateResponse(row.name).response
            ).text
        end
    )
end

function GuildRankSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                function(row)
                    local lte = LootAllocate.GetLootTableEntry(session)
                    return guildRanks[lte:GetCandidateResponse(row.name).rank] or 100
                end
    )
end

function EpSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                function(row)
                    local entry = AddOn:PointsModule().GetEntry(row.name)
                    return entry and entry.ep or 0
                end
    )
end

function GpSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                function(row)
                    local entry = AddOn:PointsModule().GetEntry(row.name)
                    return entry and entry.gp or 1
                end
    )
end

function PrSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                function(row)
                    local entry = AddOn:PointsModule().GetEntry(row.name)
                    return entry and entry:GetPR() or 0.0
                end
    )
end


-- @param session the session id
-- @param name the candidate name
-- @param reason the reason for award
-- @return the data (ItemAward) for displaying an award pop-up
function LootAllocate:GetAwardPopupData(session, name, reason)
    return LootAllocate.GetLootTableEntry(session):GetItemAward(session, name, reason)
end

-- @param session the session id
-- @param isRoll is this for a roll
-- @param noAutopass should auto-pass be disabled
-- @return the data (table) for managing a re-roll request
function LootAllocate:GetReRollData(session, isRoll, noAutopass)
    return LootAllocate.GetLootTableEntry(session):GetReRollData(session, isRoll, noAutopass)
end

-- @param the candidate name
-- @return the class for the candidate
function LootAllocate.GetCandidateClass(name)
    return LootAllocate:GetCandidateData(session, name, "class")
end

-- Please note, this is based upon what the candidate responded for an item or what the
-- master looter altered their response to become. It will not reflect a reason for
-- awarding an item which was not specified via one of those mechanisms (e.g. Award For - Free)
--
-- @param the candidates name
-- @return tuple of the the LooTable entry for current session and user's response
function LootAllocate.GetItemAndResponse(name)
    local entry = LootAllocate.GetLootTableEntry(session)
    local userResponse = LootAllocate.GetLootTableEntryResponse(session, name)
    local response = AddOn:GetResponse(entry.typeCode or entry.equipLoc, userResponse.response)
    return entry, response
end

-- @param the candidate name
-- @return the formatted/colored GP value(s) [baseGp, awardGp] based upon the candidate's response
function LootAllocate.GetGpColoredTextFromCandidateResponse(name)
    local entry, response = LootAllocate.GetItemAndResponse(name)
    return AddOn:GearPointsModule():GetGpTextColored(entry, response.award_scale)
end

function LootAllocate:GetFrame()
    if self.frame then return self.frame end

    local f =  UI:CreateFrame("R2D2_LootAllocate", "LootAllocate", L["r2d2_loot_allocate_frame"], 250, 420, false)
    function f.UpdateScrollingTable()
        -- if already created, hide and drop reference
        if f.st then
            f.st:Hide()
            f.st = nil
        end
        local st = ST:CreateST(self.scrollCols, NUM_ROWS, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
        st.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
        st:RegisterEvents({
            ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                -- show the menu
                if button == "RightButton" and row then
                    MenuFrame.name = data[realrow].name
                    MSA_ToggleDropDownMenu(1, nil, MenuFrame, cellFrame, 0, 0)
                -- update more info
                elseif button == "LeftButton" and row then
                    AddOn.UpdateMoreInfo(self:GetName(), f, realrow, data,
                                         LootAllocate.GetCandidateClass,
                                         LootAllocate.GetGpColoredTextFromCandidateResponse
                    )
                    if IsAltKeyDown() then
                        local name = data[realrow].name
                        Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward, self:GetAwardPopupData(session, name))
                    end
                end
                -- Return false to have the default OnClick handler take care of left clicks
                return false
            end,
        })
        -- show moreInfo on mouseover
        st:RegisterEvents({
            ["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                if row then
                    AddOn.UpdateMoreInfo(self:GetName(), f, realrow, data,
                                         LootAllocate.GetCandidateClass,
                                         LootAllocate.GetGpColoredTextFromCandidateResponse)
                end
                -- Return false to have the default OnEnter handler take care mouseover
                return false
            end
        })
        -- return to the actual selected player when we remove the mouse
        st:RegisterEvents({
            ["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                AddOn.UpdateMoreInfo(self:GetName(), f, nil, nil,
                                     LootAllocate.GetCandidateClass,
                                     function(name)
                                         return AddOn:GearPointsModule():GetGpTextColored(LootAllocate.GetLootTableEntry(session), nil)
                                     end
                )
                return false
            end
        })

        st:SetFilter(LootAllocate.FilterFunc)
        st:EnableSelection(true)
        f.st = st
        f:SetWidth(f.st.frame:GetWidth() + 20)
    end
    f.UpdateScrollingTable()

    local item = UI:New("IconBordered", f.content, "Interface/ICONS/INV_Misc_QuestionMark")
    item:SetMultipleScripts({
        OnEnter = function()
            if not lootTable then return end
            UI:CreateHypertip(lootTable[session].link)
            GameTooltip:AddLine("")
            GameTooltip:AddLine(L["always_show_tooltip_howto"], nil, nil, nil, true)
            GameTooltip:Show()
        end,
        OnLeave = function() UI:HideTooltip() end,
        OnClick = function()
            if not lootTable then return end
            if ( IsModifiedClick() ) then
                HandleModifiedItemClick(lootTable[session].link);
            end
            if item.lastClick and GetTime() - item.lastClick <= 0.5 then
                LootAllocate:Update()
            else
                item.lastClick = GetTime()
            end
        end
    })
    item:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -20)
    item:SetSize(50,50)
    f.itemIcon = item
    f.itemTooltip = UI:CreateGameTooltip("LootAllocate", f.content)

    local iTxt = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    iTxt:SetPoint("TOPLEFT", item, "TOPRIGHT", 10, 0)
    iTxt:SetText("Um, ...")
    f.itemText = iTxt

    local ilvl = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ilvl:SetPoint("TOPLEFT", iTxt, "BOTTOMLEFT", 0, -4)
    ilvl:SetTextColor(1, 1, 1)
    ilvl:SetText("")
    f.itemLvl = ilvl

    local iGp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iGp:SetPoint("LEFT", ilvl, "RIGHT", 5, 0)
    iGp:SetTextColor(0,1,0,1)
    iGp:SetText("")
    f.gp = iGp

    local iState = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iState:SetPoint("LEFT", iGp, "RIGHT", 5, 0)
    iState:SetTextColor(0,1,0,1)
    iState:SetText("")
    f.iState = iState

    local iType = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iType:SetPoint("TOPLEFT", ilvl, "BOTTOMLEFT", 0, -4)
    iType:SetTextColor(0.5, 1, 1)
    iType:SetText("")
    f.itemType = iType

    -- abort button
    local b1 = UI:CreateButton(_G.CLOSE, f.content)
    b1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -50)
    b1:SetScript("OnClick", function()
        -- This needs to be dynamic if the ML has changed since this was first created
        if AddOn.isMasterLooter and active then
            Dialog:Spawn(AddOn.Constants.Popups.ConfirmAbort)
        else
            self:Hide()
        end
    end)
    f.abort = b1
    
    -- more info widgets
    AddOn.EmbedMoreInfoWidgets(self:GetName(), f)
    
    -- filter
    local b2 = UI:CreateButton(_G.FILTER, f.content)
    b2:SetPoint("RIGHT", b1, "LEFT", -10, 0)
    b2:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    b2:SetScript("OnEnter", function() UI:CreateTooltip(L["deselect_responses"]) end)
    b2:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.filter = b2

    -- disenchant
    local b3 = UI:CreateButton(_G.ROLL_DISENCHANT, f.content)
    b3:SetPoint("RIGHT", b2, "LEFT", -10, 0)
    b3:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, Enchanters, self, 0, 0) end )
    f.disenchant = b3

    -- loot status
    --f.lootStatus = UI:New("Text", f.content, " ")
    --f.lootStatus:SetTextColor(1,1,1,1)
    --f.lootStatus:SetHeight(20)
    --f.lootStatus:SetWidth(150)
    --f.lootStatus:SetPoint("RIGHT", rf, "LEFT", -10, 0)
    --f.lootStatus:SetScript("OnLeave", function() UI:HideTooltip() end)
    --f.lootStatus.text:SetJustifyH("RIGHT")

    -- todo : owner

    -- award string
    local awdstr = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    awdstr:SetPoint("CENTER", f.content, "TOP", 0, -35)
    awdstr:SetText(L["item_awarded_to"])
    awdstr:SetTextColor(1, 1, 0, 1) -- Yellow
    awdstr:Hide()
    f.awardString = awdstr
    awdstr = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    awdstr:SetPoint("TOP", f.awardString, "BOTTOM", 7.5, -3)
    awdstr:SetText("PlayerName")
    awdstr:SetTextColor(1, 1, 1, 1)
    awdstr:Hide()
    f.awardStringPlayer = awdstr
    local awdtx = f.content:CreateTexture()
    awdtx:SetTexture("Interface/ICONS/INV_Sigil_Thorim.png")
    function awdtx:SetNormalTexture(tex) self:SetTexture(tex) end
    function awdtx:GetNormalTexture() return self end
    awdtx:SetPoint("RIGHT", awdstr, "LEFT")
    awdtx:SetSize(15,15)
    awdtx:Hide()
    f.awardStringPlayer.classIcon = awdtx

    -- Session toggle
    local stgl = CreateFrame("Frame", nil, f.content)
    stgl:SetWidth(40)
    stgl:SetHeight(f:GetHeight())
    stgl:SetPoint("TOPRIGHT", f, "TOPLEFT", -2, 0)
    f.sessionToggleFrame = stgl
    sessionButtons = {}

    f:SetWidth(f.st.frame:GetWidth() + 20)
    return f
end

-- Perform a response solicitation

--@param namePred   true or string or func. Determine what candidate should be re-announced. true to re-announce to all candidates.
--                  string for specific candidate.
--@param sesPred    true or number or func. Determine what session should be re-announced. true to re-announce to all candidates.
--		            number k to re-announce to session k and other sessions with the same item as session k.
--@param isRoll     true or false. Determine whether we are requesting rolls. true will request rolls and clear the current rolls.
--@param noAutoPass true or false or nil. Determine whether we force no auto-pass.
--@param announceInChat true or false or nil. Determine if the re-announce sessions should be announced in chat.
function LootAllocate:SolicitResponse(namePred, sesPred, isRoll, noAutoPass, announceInChat)
    --[[
    Logging:Trace("SolicitResponse(%s, %s) : isRoll=%s, noAutoPass=%s, announceInChat=%s",
            Util.Objects.ToString(namePred), Util.Objects.ToString(sesPred),
            tostring(isRoll), tostring(noAutoPass), tostring(announceInChat)
    )
    --]]

    local C = AddOn.Constants
    local reRollTable = {}
    -- session id and LootAllocate instance
    for session, entry in ipairs(lootTable) do
        local rolls = {}
        if sesPred == true or
            (Util.Objects.IsNumber(sesPred) and AddOn:ItemIsItem(lootTable[session].link, lootTable[sesPred].link)) or
            (Util.Objects.IsFunction(sesPred) and sesPred(session)) then
            Util.Tables.Push(reRollTable, LootAllocate:GetReRollData(session, isRoll, noAutoPass))

            for name, _ in pairs(entry.candidates) do
                if namePred == true or
                    (Util.Objects.IsString(namePred) and name == namePred) or
                    (Util.Objects.IsFunction(namePred) and namePred(name)) then
                    if not isRoll then
                        AddOn:SendCommand(C.group, C.Commands.ChangeResponse, session, name, "WAIT")
                    end
                    rolls[name] = ""
                end
            end

            if isRoll then
                AddOn:SendCommand(C.group, C.Commands.Rolls, session, rolls)
            end
        end
    end

    if #reRollTable > 0 then
        AddOn:MasterLooterModule():AnnounceItems(reRollTable)

        if namePred == true then
            AddOn:SendCommand(C.group, C.Commands.ReRoll, reRollTable)
        else
            for name, _ in pairs(LootAllocate.GetLootTableEntry(session).candidates) do
                if (Util.Objects.IsString(namePred) and name == namePred) or
                    (Util.Objects.IsFunction(namePred) and namePred(name)) then
                    AddOn:SendCommand(name, C.Commands.ReRoll, reRollTable)
                end
            end
        end
    end
end

do
    function LootAllocate.SolicitResponseCategoryButton(category)
        -- Logging:Trace("SolicitResponseCategoryButton(%s)", tostring(category))
        local b = {
            onValue = function() return MSA_DROPDOWNMENU_MENU_VALUE == "REANNOUNCE" or MSA_DROPDOWNMENU_MENU_VALUE == "REQUESTROLL" end,
            value = function() return MSA_DROPDOWNMENU_MENU_VALUE .. "_" .. category end,
            text = function(candidateName) return LootAllocate.SolicitResponseRollText(candidateName, category) end,
            notCheckable = true,
            hasArrow = true,
        }
        -- Logging:Debug("SolicitResponseCategoryButton(%s) : %s", tostring(category), Util.Objects.ToString(b))
        return b
    end
    
    function LootAllocate.SolicitResponseRollText(candidateName, category)
        -- Logging:Trace("SolicitResponseRollText(%s, %s)", tostring(candidateName), tostring(category))
        
        if not Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) then return end
        
        local text = ""
        if category == "CANDIDATE" or MSA_DROPDOWNMENU_MENU_VALUE:find("_CANDIDATE$") then
            text = AddOn:GetUnitClassColoredName(candidateName)
        elseif category == "GROUP" or MSA_DROPDOWNMENU_MENU_VALUE:find("_GROUP$") then
            text = FRIENDS_FRIENDS_CHOICE_EVERYONE
        elseif category == "ROLL" or MSA_DROPDOWNMENU_MENU_VALUE:find("_ROLL$") then
            text = ROLL .. ": ".. (LootAllocate.GetLootTableEntryResponse(session, candidateName).roll or "")
        elseif category == "RESPONSE" or MSA_DROPDOWNMENU_MENU_VALUE:find("_RESPONSE$") then
            local e = LootAllocate.GetLootTableEntry(session)
            local c = e:GetCandidateResponse(candidateName)
            local r = AddOn:GetResponse(e.typeCode or e.equipLoc, c.response)
            text = L["response"] .. ": " .. UI.ColoredDecorator(r.color or {1, 1, 1}):decorate(r.text or "")
        else
            Logging:Warn("Unexpected category or dropdown menu values - %s, %s", tostring(category), tostring(MSA_DROPDOWNMENU_MENU_VALUE))
        end
        
        -- Logging:Debug("SolicitResponseRollText(%s, %s) : %s", tostring(candidateName), tostring(category), text)
        
        return text
    end
    
    function LootAllocate.SolicitResponseRollButton(candidateName, isThisItem)
        -- Logging:Trace("SolicitResponseRollButton(%s, %s)", tostring(candidateName), tostring(isThisItem))
        
        if not Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) then return end
        
        local namePred, sesPred
        if isThisItem then
            sesPred = function(s)
                local e1 = LootAllocate.GetLootTableEntry(s)
                local e2 = LootAllocate.GetLootTableEntry(session)
                return s == session or (not e1.awarded and AddOn:ItemIsItem(e1.link, e2.link))
            end
        else
            sesPred = function(s) return not LootAllocate.GetLootTableEntry(s).awarded end
        end
        
        local isRoll = MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") and true or false
        local announce = false
        
        if MSA_DROPDOWNMENU_MENU_VALUE:find("_CANDIDATE$") then
            namePred = candidateName
        elseif MSA_DROPDOWNMENU_MENU_VALUE:find("_GROUP$") then
            announce = true
            namePred = true
        elseif MSA_DROPDOWNMENU_MENU_VALUE:find("_ROLL$") then
            namePred = function(name)
                local r1 = LootAllocate.GetLootTableEntryResponse(session, name)
                local r2 = LootAllocate.GetLootTableEntryResponse(session, candidateName)
                return r1.roll == r2.roll
            end
        elseif MSA_DROPDOWNMENU_MENU_VALUE:find("_RESPONSE$") then
            namePred = function(name)
                local r1 = LootAllocate.GetLootTableEntryResponse(session, name)
                local r2 = LootAllocate.GetLootTableEntryResponse(session, candidateName)
                return r1.response == r2.response
            end
        else
            Logging:Warn("Unexpected dropdown menu value - %s ", tostring(MSA_DROPDOWNMENU_MENU_VALUE))
        end
        
        Logging:Debug("%s", tostring(MSA_DROPDOWNMENU_MENU_VALUE))

        -- No auto-pass on isRoll, which may be wrong but could be useful in case where you just want to distribute
        -- item based upon random rolls
        local noAutopass = isThisItem and (MSA_DROPDOWNMENU_MENU_VALUE:find("_CANDIDATE$") or isRoll) and true or false
        if isThisItem then
            LootAllocate:SolicitResponse(namePred, sesPred, isRoll, noAutopass, announce)
            LootAllocate.SolicitResponseRollPrint(LootAllocate.SolicitResponseRollText(candidateName), isThisItem, isRoll)
        else
            local target = LootAllocate.SolicitResponseRollText(candidateName)
            Dialog:Spawn(AddOn.Constants.Popups.ConfirmReannounceItems, {
                target = target,
                isRoll = isRoll,
                func = function()
                    LootAllocate:SolicitResponse(namePred, sesPred, isRoll, noAutopass, announce)
                    LootAllocate.SolicitResponseRollPrint(target, isThisItem, isRoll)
                end
            })
        end
    end
    
    function LootAllocate.SolicitResponseRollPrint(target, isThisItem, isRoll)
        -- Logging:Debug("SolicitResponseRollPrint(%s, %s, %s)", tostring(target), tostring(isThisItem), tostring(isRoll))
        
        local itemText = isThisItem and L["this_item"] or L["all_unawarded_items"]
        if isRoll then
            AddOn:Print(format(L["requested_rolls_for_i_from_t"], itemText, target))
        else
            AddOn:Print(format(L["reannounced_i_to_t"], itemText, target))
        end
    end
    
    LootAllocate.RightClickEntries = {
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
            -- 3 Award
            {
                text = L["award"],
                notCheckable = true,
                func = function(name)
                    -- this calls back into MasterLooter Module
                    Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward, LootAllocate:GetAwardPopupData(session, name))
                end,
            },
            -- 4 Award for
            {
                text = L["award_for"],
                value = "AWARD_FOR",
                notCheckable = true,
                hasArrow = true,
            },
            -- 5 Spacer
            {
                text = "",
                notCheckable = true,
                disabled = true,
            },
            -- 6 Change response
            {
                text = L["change_response"],
                value = "CHANGE_RESPONSE",
                hasArrow = true,
                notCheckable = true,
            },
            -- 7 Reannounce
            {
                text = L["reannounce"],
                value = "REANNOUNCE",
                hasArrow = true,
                notCheckable = true,
            },
            -- 8 Add rolls
            {
                text = L["add_rolls"],
                notCheckable = true,
                func = function() LootAllocate:DoRandomRolls(session) end,
            },
            -- 9 Re-announce and request rolls
            {
                text = _G.REQUEST_ROLL,
                value = "REQUESTROLL",
                hasArrow = true,
                notCheckable = true,
            },
            -- 10 Remove from consideration
            {
                text = L["remove_from_consideration"],
                notCheckable = true,
                func = function(name)
                    AddOn:SendCommand(AddOn.Constants.group, AddOn.Constants.Commands.ChangeResponse, session, name, "REMOVED")
                end,
            },
        },
        -- level 2
        {
            -- 1 AWARD_FOR
            {
                special = "AWARD_FOR",
            },
            -- 2 AWARD_FOR
            {
                special = "CHANGE_RESPONSE",
            },
            -- 4,5,6,7 Reannounce/Reroll entries
            LootAllocate.SolicitResponseCategoryButton("CANDIDATE"),
            LootAllocate.SolicitResponseCategoryButton("GROUP"),
            LootAllocate.SolicitResponseCategoryButton("ROLL"),
            LootAllocate.SolicitResponseCategoryButton("RESPONSE"),
        },
        -- level 3
        {
            -- 1 header for response solicitation
            {
                onValue = function()
                    return Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) and
                            (MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") or MSA_DROPDOWNMENU_MENU_VALUE:find("^REANNOUNCE"))
                end,
                text = function(candidateName) return LootAllocate.SolicitResponseRollText(candidateName) end,
                notCheckable = true,
                isTitle = true,
                func = function(candidateName)
                    return LootAllocate.SolicitResponseRollButton(candidateName, true)
                end,
            },
            -- 2 this item
            {
                onValue = function()
                    return Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) and
                            (MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") or MSA_DROPDOWNMENU_MENU_VALUE:find("^REANNOUNCE"))
                end,
                text = function()
                    if Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) and MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") then
                        return L["this_item"] .. " (" .. REQUEST_ROLL .. ")"
                    else
                        return L["this_item"]
                    end
                end,
                notCheckable = true,
                func = function(candidateName)
                    return LootAllocate.SolicitResponseRollButton(candidateName, true)
                end,
            },
            -- 3 all un-awarded items
            {
                onValue = function()
                    return Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) and
                            (MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") or MSA_DROPDOWNMENU_MENU_VALUE:find("^REANNOUNCE")) and
                            (MSA_DROPDOWNMENU_MENU_VALUE:find("_CANDIDATE$") or MSA_DROPDOWNMENU_MENU_VALUE:find("_GROUP$"))
                end,
                text = function()
                    if Util.Objects.IsString(MSA_DROPDOWNMENU_MENU_VALUE) and MSA_DROPDOWNMENU_MENU_VALUE:find("^REQUESTROLL") then
                        return L["all_unawarded_items"] .. " (" .. REQUEST_ROLL .. ")"
                    else
                        return L["all_unawarded_items"]
                    end
                end,
                notCheckable = true,
                func = function(candidateName)
                    return LootAllocate.SolicitResponseRollButton(candidateName, false)
                end,
            },
        }
    }
    
    LootAllocate.RightClickMenu = UI.RightClickMenu(
        function() return AddOn.isMasterLooter end,
        LootAllocate.RightClickEntries,
        function(info, menu, level, entry, value)
            local candidateName = menu.name
            local C = AddOn.Constants
            
            if value == "AWARD_FOR" and entry.special == value then
                for k,v in ipairs(LootAllocate.db.profile.awardReasons) do
                    -- Logging:Debug("AWARD_FOR() : %s / %s", tostring(k), Util.Objects.ToString(v))
                    if k > LootAllocate.db.profile.awardReasons.numAwardReasons then break end
                    info.text = v.text
                    info.notCheckable = true
                    info.colorCode = UI.RGBToHexPrefix(unpack(v.color))
                    info.func = function()
                        Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward, LootAllocate:GetAwardPopupData(session, candidateName, v))
                    end
                    MSA_DropDownMenu_AddButton(info, level)
                end
            elseif value == "CHANGE_RESPONSE" and entry.special == value then
                local e, v = LootAllocate.GetLootTableEntry(session), nil
                for i = 1, AddOn:GetNumButtons(e.typeCode or e.equipLoc) do
                    v = AddOn:GetResponse(e.typeCode or e.equipLoc, i)
                    info.text = v.text
                    info.colorCode = UI.RGBToHexPrefix(unpack(v.color))
                    info.notCheckable = true
                    info.func = function()
                        AddOn:SendCommand(C.group, C.Commands.ChangeResponse, session, candidateName, i)
                    end
                    MSA_DropDownMenu_AddButton(info, level)
                end
        
                -- Add pass button as well
                local passResponse = AddOn:MasterLooterModule().db.profile.responses.default.PASS
                info.text = passResponse.text
                info.colorCode = UI.RGBToHexPrefix(unpack(passResponse.color))
                info.notCheckable = true
                info.func = function()
                    AddOn:SendCommand(C.group, C.Commands.ChangeResponse, session, candidateName, "PASS")
                end
                
                MSA_DropDownMenu_AddButton(info, level)
                MSA_DropDownMenu_CreateInfo()
            end
        end
    )

    function LootAllocate.EnchantersMenu(menu, level)
        Logging:Debug("EnchantersMenu()")
        if level == 1 then
            local added = false
            local info = MSA_DropDownMenu_CreateInfo()
            for _, name in Util.Objects.Each(Util.Tables.Sort(Util.Tables.Keys(AddOn.candidates))) do
                local candidate = AddOn.candidates[name]
                if candidate and candidate.enchanter then
                    Logging:Debug("EnchantersMenu() : Adding %s", Util.Objects.ToString(candidate))
                    info.text = "|cff".. AddOn.GetClassColorRGB(candidate.class) ..
                            AddOn.Ambiguate(name) .. "|r ("..
                            tostring(candidate.enchant_lvl) .. ")"
                    info.notCheckable = true
                    info.func = function()
                        for k,v in ipairs(LootAllocate.db.profile.awardReasons) do
                            -- todo : fix this text check
                            if not v.user_visible and Util.Strings.StartsWith(Util.Strings.Lower(v.text), 'disenchant') then
                                Logging:Debug("EnchantersMenu() : Disenchant award resason %s / %s", tostring(k), Util.Objects.ToString(v))
                                Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward, LootAllocate:GetAwardPopupData(session, name, v))
                                return
                            end
                        end
                    end
                    added = true
                    MSA_DropDownMenu_AddButton(info, level)
                end
            end

            if not added then
                info.text = L["no_enchanters_found"]
                info.notCheckable = true
                info.isTitle = true
                MSA_DropDownMenu_AddButton(info, level)
            end
        end
    end
    function LootAllocate.FilterMenu(menu, level)
        -- Logging:Trace("FilterMenu()")
        local Module = AddOn.db.profile.modules[LootAllocate:GetName()]
    
        if level == 1 then
            if not Module.filters then
                Module.filters = {}
            end
        
            local ModuleFilters = Module.filters
        
            local data = {
                ["STATUS"]      = true,
                ["PASS"]        = true,
                ["AUTOPASS"]    = true,
                default         = {}
            }
        
            for i = 1, AddOn:GetNumButtons() do
                data[i] = i
            end
        
            local info = MSA_DropDownMenu_CreateInfo()
            info.text = _G.GENERAL
            info.isTitle = true
            info.notCheckable = true
            info.disabled = true
            MSA_DropDownMenu_AddButton(info, level)
        
            --[[
            info = MSA_DropDownMenu_CreateInfo()
            info.text = L["Always show owner"]
            info.func = function()
                ModuleFilters.alwaysShowOwner = not ModuleFilters.alwaysShowOwner
                LootAllocate:Update(true)
            end
            info.checked = ModuleFilters.alwaysShowOwner
            MSA_DropDownMenu_AddButton(info, level)
            --]]
        
            info = MSA_DropDownMenu_CreateInfo()
            info.text = L["Candidates that can't use the item"]
            info.func = function()
                ModuleFilters.showPlayersCantUseTheItem = not ModuleFilters.showPlayersCantUseTheItem
                LootAllocate:Update(true)
            end
            info.checked = ModuleFilters.showPlayersCantUseTheItem
            MSA_DropDownMenu_AddButton(info, level)
        
            info = MSA_DropDownMenu_CreateInfo()
            info.text = L["Responses"]
            info.isTitle = true
            info.notCheckable = true
            info.disabled = true
            MSA_DropDownMenu_AddButton(info, level)
        
            info = MSA_DropDownMenu_CreateInfo()
            for k in ipairs(data) do
                info.text = AddOn:GetResponse("", k).text
                info.colorCode = UI.RGBToHexPrefix(AddOn:GetResponseColor(nil,k))
                info.func = function()
                    ModuleFilters[k] = not ModuleFilters[k]
                    LootAllocate:Update(true)
                end
                info.checked = ModuleFilters[k]
                MSA_DropDownMenu_AddButton(info, level)
            end
        
            for k in pairs(data) do
                if Util.Objects.IsString(k) then
                    if k == "STATUS" then
                        info.text = L["Status texts"]
                        info.colorCode = "|cffde34e2"
                    else
                        info.text = AddOn:GetResponse("",k).text
                        info.colorCode = UI.RGBToHexPrefix(AddOn:GetResponseColor(nil,k))
                    end
                    info.func = function()
                        ModuleFilters[k] = not ModuleFilters[k]
                        LootAllocate:Update(true)
                    end
                    info.checked = ModuleFilters[k]
                    MSA_DropDownMenu_AddButton(info, level)
                end
            end
    
            info = MSA_DropDownMenu_CreateInfo()
            info.text = L["ep_abbrev"]
            info.isTitle = true
            info.notCheckable = true
            info.disabled = true
            MSA_DropDownMenu_AddButton(info, level)
    
            info = MSA_DropDownMenu_CreateInfo()
            info.text = L["greater_than_min"]
            info.func = function()
                ModuleFilters.minimums['ep'] = not ModuleFilters.minimums['ep']
                LootAllocate:Update(true)
            end
            info.checked = ModuleFilters.minimums['ep']
            MSA_DropDownMenu_AddButton(info, level)
            
            --[[
            info = MSA_DropDownMenu_CreateInfo()
            info.text = RANK
            info.isTitle = true
            info.notCheckable = true
            info.disabled = true
            MSA_DropDownMenu_AddButton(info, level)
    
            info = MSA_DropDownMenu_CreateInfo()
            info.text = RANK .. "..."
            info.notCheckable = true
            info.hasArrow = true
            info.value = "FILTER_RANK"
            MSA_DropDownMenu_AddButton(info, level)
            --]]
        elseif level == 2 then
            --[[
            local ModuleFilters = Module.filters
            if MSA_DROPDOWNMENU_MENU_VALUE == "FILTER_RANK" then
                local info = MSA_DropDownMenu_CreateInfo()
                if IsInGuild() then
                    for k = 1, GuildControlGetNumRanks() do
                        info.text = GuildControlGetRankName(k)
                        info.func = function()
                            ModuleFilters.ranks[k] = not ModuleFilters.ranks[k]
                            LootAllocate:Update(true)
                        end
                        info.checked = ModuleFilters.ranks[k]
                        MSA_DropDownMenu_AddButton(info, level)
                    end
                end
        
                info.text = L["Not in your guild"]
                info.func = function()
                    ModuleFilters.ranks.notInYourGuild = not ModuleFilters.ranks.notInYourGuild
                    LootAllocate:Update(true)
                end
                info.checked = ModuleFilters.ranks.notInYourGuild
                MSA_DropDownMenu_AddButton(info, level)
            end
            --]]
        end
    end
end

-- todo : make sure filtering is working here
function LootAllocate.FilterFunc(table, row)
    --Logging:Debug("FilterFunc(%s, %s) : %s ", row.name, tostring(session), Util.Objects.ToString(LootAllocate.GetLootTableEntry(session)))
    local Module = AddOn.db.profile.modules[LootAllocate:GetName()]
    if not Module.filters then return true end

    local ModuleFilters = Module.filters
    local name = row.name
    local entry = LootAllocate.GetLootTableEntry(session)
    
    local include = true
    
    --[[
    
    local rank = entry:GetCandidateResponse(name).rank
    
    if ModuleFilters.alwaysShowOwner then
        include = not AddOn:UnitIsUnit(name, entry.owner)
        Logging:Debug("#1 = %s", tostring(include))
    end
    --]]
    
    --if include then
    --    if rank and guildRanks[rank] then
    --        include = ModuleFilters.ranks[guildRanks[rank]]
    --    elseif not ModuleFilters.ranks.notInYourGuild then
    --        include = false
    --    end
    --end
    
    
    if include then
        local response = entry:GetCandidateResponse(name).response
        if not ModuleFilters.showPlayersCantUseTheItem then
            include = not AddOn:AutoPassCheck(entry:GetCandidateResponse(name).class, entry.equipLoc, entry.typeId, entry.subTypeId, entry.classes)
        end
    
        if include then
            if response == "AUTOPASS" or response == "PASS" or Util.Objects.IsNumber(response) then
                include = ModuleFilters[response]
            else
                include = ModuleFilters["STATUS"]
            end
        end
    end
    
    if include then
        if Util.Tables.ContainsKey(ModuleFilters.minimums, 'ep') and ModuleFilters.minimums['ep'] then
            local ep = AddOn:PointsModule().Get(name)
            if Util.Objects.IsNumber(ep) then
                include = ep >= AddOn:EffortPointsModule().db.profile.ep_min
            end
        end
    end
    
    return include
end

-- Get rolls ranged from 1 to 100 for all candidates, and guarantee everyone's roll is different
function LootAllocate:GenerateNoRepeatRollTable(ses)
    local rolls = {}
    for i = 1, 100 do
        rolls[i] = i
    end

    local t = {}
    for name, _ in pairs(LootAllocate.GetLootTableEntry(ses).candidates) do
        if #rolls > 0 then
            local i = math.random(#rolls)
            t[name] = rolls[i]
            tremove(rolls, i)
        else -- We have more than 100 candidates !?!?
            t[name] = 0
        end
    end
    return t
end

function LootAllocate:DoRandomRolls(ses)
    local C = AddOn.Constants
    local table = self:GenerateNoRepeatRollTable(ses)
    for k, v in ipairs(lootTable) do
        if AddOn:ItemIsItem(LootAllocate.GetLootTableEntry(ses).link, v.link) then
            AddOn:SendCommand(C.group, C.Commands.Rolls, k, table)
        end
    end
end

function LootAllocate:Update(forceUpdate)
    -- Logging:Trace("Update(%s)", tostring(forceUpdate))
    updatePending = false
    if not forceUpdate and updateIntervalRemaining > 0 then
        updatePending = true
        return
    end

    if not self.frame then return end
    if not lootTable[session] then
        Logging:Warn("Update() : No Loot Table entry for session %d", session)
        return
    end

    updateIntervalRemaining = MIN_UPDATE_INTERVAL
    -- twice?
    self.frame.st:SortData()
    self.frame.st:SortData()
    local entry = LootAllocate.GetLootTableEntry(session)

    if entry and entry.awarded then
        local response = entry:GetCandidateResponse(entry.awarded)
        self.frame.awardString:SetText(L["item_awarded_to"])
        self.frame.awardString:Show()
        self.frame.awardStringPlayer:SetText(AddOn.Ambiguate(entry.awarded))
        local c = AddOn.GetClassColor(response.class)
        self.frame.awardStringPlayer:SetTextColor(c.r,c.g,c.b,c.a)
        self.frame.awardStringPlayer:Show()
        AddOn.SetCellClassIcon(nil,self.frame.awardStringPlayer.classIcon,nil,nil,nil,nil,nil,nil,nil,response.class)
        self.frame.awardStringPlayer.classIcon:Show()
    else
        self.frame.awardString:Hide()
        self.frame.awardStringPlayer:Hide()
        self.frame.awardStringPlayer.classIcon:Hide()
    end

    --only applies to the ML
    if AddOn.isMasterLooter then
        -- Update close button text
        if active then
            self.frame.abort:SetText(L["abort"])
        else
            self.frame.abort:SetText(_G.CLOSE)
        end
    else
        self.frame.abort:SetText(_G.CLOSE)
    end

    if #self.frame.st.filtered < #self.frame.st.data then
        self.frame.filter.Text:SetTextColor(0.86,0.5,0.22)
    else
        self.frame.filter.Text:SetTextColor(_G.NORMAL_FONT_COLOR:GetRGB())
    end

    local alwaysShowTooltip = false

    if alwaysShowTooltip then
        self.frame.itemTooltip:SetOwner(self.frame.content, "ANCHOR_NONE")
        self.frame.itemTooltip:SetHyperlink(entry.link)
        self.frame.itemTooltip:Show()
        self.frame.itemTooltip:SetPoint("TOP", self.frame, "TOP", 0, 0)
        self.frame.itemTooltip:SetPoint("RIGHT", sessionButtons[#lootTable], "LEFT", 0, 0)
    else
        self.frame.itemTooltip:Hide()
    end
end

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if updateIntervalRemaining > elapsed then
        updateIntervalRemaining = updateIntervalRemaining - elapsed
    else
        updateIntervalRemaining = 0
    end
    if updatePending and updateIntervalRemaining <= 0 then
        LootAllocate:Update()
    end
end)


function LootAllocate:UpdateSessionButtons()
    for session, entry in ipairs(lootTable) do
        sessionButtons[session] = self:UpdateSessionButton(session, entry.texture, entry.link, entry.awarded)
    end
end

-- if button not present for session, then creates one and associates with session
-- any newly created or existing button is then updates to reflect the status
function LootAllocate:UpdateSessionButton(session, texture, link, awarded)
    local btn = sessionButtons[session]
    if not btn then
        btn = UI:NewNamed("IconBordered", self.frame.sessionToggleFrame, "R2D2_AllocateButton".. session, texture)
        if session == 1 then
            btn:SetPoint("TOPRIGHT", self.frame.sessionToggleFrame)
        elseif mod(session,10) == 1 then
            btn:SetPoint("TOPRIGHT", sessionButtons[session - 10], "TOPLEFT", -2, 0)
        else
            btn:SetPoint("TOP", sessionButtons[session - 1], "BOTTOM", 0, -2)
        end
        btn:SetScript("Onclick", function() LootAllocate:SwitchSession(session) end)
    end
    -- then update it
    btn:SetNormalTexture(texture or "Interface\\InventoryItems\\WoWUnknownItem01")
    local lines = { format(L["click_to_switch_item"], link) }
    if session == session then
        btn:SetBorderColor("yellow")
    elseif awarded then
        btn:SetBorderColor("green")
        tinsert(lines, L["item_has_been_awarded"])
    else
        btn:SetBorderColor("white") -- white
    end
    btn:SetScript("OnEnter", function() UI:CreateTooltip(unpack(lines)) end)
    return btn
end


function LootAllocate:GetItemStatus(item)
    if not item then return "" end

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetHyperlink(item)
    local text = ""
    if GameTooltip:NumLines() > 1 then
        local line = getglobal('GameTooltipTextLeft2')
        local t = line:GetText()
        --Logging:Debug("GetItemStatus() : %s", t)
        if t then
            if strfind(t, "cFF 0FF 0") then
                text = t
            end
        end
    end
    GameTooltip:Hide()
    return text
end

function LootAllocate:GetDiffColor(num)
    if num == "" then num = 0 end
    local green, red, grey = {0,1,0,1}, {1,0,0,1}, {0.75,0.75,0.75,1}
    if num > 0 then return green end
    if num < 0 then return red end
    return grey
end

--
-- functions below starting with 'SetCell' are invoked for setting values of individual cells in a row
--
function LootAllocate.SetCellClass(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    AddOn.SetCellClassIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, LootAllocate.GetLootTableEntryResponse(session, name).class)
    data[realrow].cols[column].value = lootTable[session].candidates[name].class or ""
end

function LootAllocate.SetCellName(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    if AddOn:UnitIsUnit(name, lootTable[session].owner) then
        frame.text:SetText("|TInterface\\LOOTFRAME\\LootToast:0:0:0:0:1024:256:610:640:224:256|t" .. AddOn.Ambiguate(name))
    else
        frame.text:SetText(AddOn.Ambiguate(name))
    end
    
    local r = LootAllocate.GetLootTableEntryResponse(session, name)
    if not r.class then
        Logging:Warn("SetCellName(%s) : Class attribute unavailable", tostring(name))
    else
        local c = AddOn.GetClassColor(r.class)
        frame.text:SetTextColor(c.r, c.g, c.b, c.a)
    end
    data[realrow].cols[column].value = name or ""
end

function LootAllocate.SetCellRank(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local entry = LootAllocate.GetLootTableEntry(session)
    local response = entry:GetCandidateResponse(name)
    frame.text:SetText(lootTable[session].candidates[name].rank)
    frame.text:SetTextColor(AddOn:GetResponseColor(entry.typeCode or  entry.equipLoc, response.response))
    data[realrow].cols[column].value = response.rank or ""
end

function LootAllocate.SetCellEp(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local ep = AddOn:PointsModule().Get(name)
    frame.text:SetText(ep)
    data[realrow].cols[column].value = ep
end

function LootAllocate.SetCellGp(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local _, gp = AddOn:PointsModule().Get(name)
    frame.text:SetText(gp)
    data[realrow].cols[column].value = gp
end

function LootAllocate.SetCellPr(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local _, _, pr = AddOn:PointsModule().Get(name)
    frame.text:SetText(pr)
    data[realrow].cols[column].value = pr
end

function LootAllocate.SetCellResponse(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local entry = LootAllocate.GetLootTableEntry(session)
    local cresponse = entry:GetCandidateResponse(name)
    local response = AddOn:GetResponse(entry.typeCode or entry.equipLoc, cresponse.response)
    local text = response.text
    if (IsInInstance() and select(4, UnitPosition("player")) ~= select(4, UnitPosition(Ambiguate(name, "short")))) or
        ((not IsInInstance()) and UnitPosition(Ambiguate(name, "short")) ~= nil) then
        text = text.." ("..L["out_of_instance"]..")"
    end
    frame.text:SetText(text)
    frame.text:SetTextColor(unpack(response.color))
end

function LootAllocate.SetCellIlvl(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local iLvlDecimal = true
    local name = data[realrow].name
    local cresponse = LootAllocate.GetLootTableEntryResponse(session, name)
    frame.text:SetText(iLvlDecimal and Util.Numbers.Round2(cresponse.ilvl, 2) or Util.Numbers.Round2(cresponse.ilvl))
    data[realrow].cols[column].value = cresponse.ilvl or ""
end

function LootAllocate.SetCellDiff(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local cresponse = LootAllocate.GetLootTableEntryResponse(session, name)
    frame.text:SetText(lootTable[session].candidates[name].diff)
    frame.text:SetTextColor(unpack(LootAllocate:GetDiffColor(cresponse.diff)))
    data[realrow].cols[column].value = cresponse.diff or ""
end

function LootAllocate.SetCellGear(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local gear = data[realrow].cols[column].colName
    local name = data[realrow].name
    gear = LootAllocate.GetLootTableEntryResponse(session, name)[gear]
    if gear then
        local texture = select(5, GetItemInfoInstant(gear))
        frame:SetNormalTexture(texture)
        frame:SetScript("OnEnter", function() UI:CreateHypertip(gear) end)
        frame:SetScript("OnLeave", function() UI:HideTooltip() end)
        frame:SetScript("OnClick", function()
            if IsModifiedClick() then
                HandleModifiedItemClick(gear)
            end
        end)
        frame:Show()
    else
        frame:Hide()
    end
end

function LootAllocate.SetCellNote(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local note = LootAllocate.GetLootTableEntryResponse(session, name).note
    local f = frame.noteBtn or CreateFrame("Button", nil, frame)
    f:SetSize(ROW_HEIGHT, ROW_HEIGHT)
    f:SetPoint("CENTER", frame, "CENTER")
    if note then
        f:SetNormalTexture("Interface/BUTTONS/UI-GuildButton-PublicNote-Up.png")
        f:SetScript("OnEnter", function() UI:CreateTooltip(_G.LABEL_NOTE, note)	end)
        f:SetScript("OnLeave", function() UI:HideTooltip() end)
        data[realrow].cols[column].value = 1
    else
        f:SetScript("OnEnter", nil)
        f:SetNormalTexture("Interface/BUTTONS/UI-GuildButton-PublicNote-Disabled.png")
        data[realrow].cols[column].value = 0
    end
    frame.noteBtn = f
end

function LootAllocate.SetCellRoll(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local cresponse = LootAllocate.GetLootTableEntryResponse(session, name)
    frame.text:SetText(cresponse.roll or "")
    data[realrow].cols[column].value = cresponse.roll or ""
end
