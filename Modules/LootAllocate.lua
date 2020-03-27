local name, AddOn = ...
local LootAllocate  = AddOn:NewModule("LootAllocate", "AceComm-3.0", "AceTimer-3.0", "AceEvent-3.0", "AceBucket-3.0")
local Dialog        = AddOn.Libs.Dialog
local Logging       = AddOn.Libs.Logging
local L             = AddOn.components.Locale
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util
local GP            = AddOn.Libs.GearPoints
local Models        = AddOn.components.Models

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 15, 0.2
local DefaultScrollTableData = {}
local GuildRankSort, ResponseSort, EpSort, GpSort, PrSort
local MenuFrame, FilterMenu
-- session is a number mapping to item
-- sessionButtons is mapping of session to IconBordered instances
-- lootTable is a mapping of session to AllocateEntry instances
local session, sessionButtons, lootTable, active, moreInfo = 1, {}, {}, false, false
local updatePending, updateIntervalRemaining, updateFrame = false, 0, CreateFrame("FRAME")

LootAllocate.defaults = {

}

function LootAllocate:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    DefaultScrollTableData = {
        { name = "",                DoCellUpdate = LootAllocate.SetCellClass,       colName = "class",      sortnext = 2,       width = 20, }, -- 1 Class
        { name = _G.NAME,			DoCellUpdate = LootAllocate.SetCellName,		colName = "name",		defaultsort = 1,	width = 120,}, -- 2 Candidate Name
        { name = _G.RANK,			DoCellUpdate = LootAllocate.SetCellRank,		colName = "rank",		sortnext = 4,		width = 95, comparesort = GuildRankSort,}, -- 3 Guild rank
        { name = L["response"],	    DoCellUpdate = LootAllocate.SetCellResponse,	colName = "response",   sortnext = 7,		width = 240,comparesort = ResponseSort,}, -- 4 Response
        { name = L["ep_abbrev"],	DoCellUpdate = LootAllocate.SetCellEp,		    colName = "ep",		    sortnext = 7,		width = 45, comparesort = EpSort,}, -- 5 EP
        { name = L["gp_abbrev"],	DoCellUpdate = LootAllocate.SetCellGp,		    colName = "gp",		    sortnext = 7,		width = 45, comparesort = GpSort,}, -- 6 GP
        { name = L["pr_abbrev"],	DoCellUpdate = LootAllocate.SetCellPr,		    colName = "pr",		    sortnext = 13,		width = 45, comparesort = PrSort,}, -- 7 PR
        { name = _G.ITEM_LEVEL_ABBR,DoCellUpdate = LootAllocate.SetCellIlvl,	    colName = "ilvl",		sortnext = 9,		width = 45, }, -- 8 Total ilvl
        { name = L["diff"],		    DoCellUpdate = LootAllocate.SetCellDiff,		colName = "diff",							width = 40, }, -- 9 ilvl difference
        { name = L["g1"],			DoCellUpdate = LootAllocate.SetCellGear,		colName = "gear1",                          width = 20, align = "CENTER", }, -- 10 Current gear 1
        { name = L["g2"],			DoCellUpdate = LootAllocate.SetCellGear,		colName = "gear2",	                        width = 20, align = "CENTER", }, -- 11 Current gear 2
        { name = L["notes"],		DoCellUpdate = LootAllocate.SetCellNote,		colName = "note",							width = 50, align = "CENTER", }, -- 12 Note icon
        { name = _G.ROLL,			DoCellUpdate = LootAllocate.SetCellRoll, 		colName = "roll",		sortnext = 8,		width = 50, align = "CENTER", }, -- 13 Roll
    }
    self.scrollCols = { unpack(DefaultScrollTableData) }
    self.db = AddOn.db:RegisterNamespace(self:GetName(), LootAllocate.defaults)
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.AllocateRightClick, UIParent)
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.AllocateFilter, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
end

function LootAllocate:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self:RegisterComm(name, "OnCommReceived")
    -- Update "Out of instance" text when any raid members change zone
    self:RegisterBucketEvent({"UNIT_PHASE", "ZONE_CHANGED_NEW_AREA"}, 1, "Update")
    self.frame = self:GetFrame()
    self:ScheduleTimer("CandidateCheck", 20)
    updateFrame:Show()
    updatePending = false
    updateIntervalRemaining = 0
end

function LootAllocate:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:SetParent(nil)
    self.frame = nil
    Util.Tables.Wipe(lootTable)
    active = false
    session = 1
    self:UnregisterAllComm()
    updateFrame:Hide()
    updatePending = false
    updateIntervalRemaining = 0
end

function LootAllocate:Hide()
    Logging:Trace("Hide()")
    self.frame.moreInfo:Hide()
    self.frame:Hide()
end

function LootAllocate:Show()
    Logging:Trace("Show()")
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
    Logging:Trace("ReceiveLootTable(BEFORE) : %s", Util.Objects.ToString(lt, 4))
    lootTable = Util(lt):Copy():Map(function(entry) return entry:ToAllocateEntry() end)()
    Logging:Trace("ReceiveLootTable(AFTER) : %s", Util.Objects.ToString(lootTable, 4))
    self:Setup(lootTable)
    if not AddOn.enabled then return end
    self:Show()
end

function LootAllocate.GetLootTableEntry(session)
    return lootTable[session]
end

function LootAllocate.GetLootTableEntryResponse(session, candidate)
    return LootAllocate.GetLootTableEntry(session):GetCandidateResponse(candidate)
end

function LootAllocate:EndSession(hide)
    if active then
        Logging:Debug("EndSesion(%s)", tostring(hide))
        active = false
        self:Update(true)
        if hide then self:Hide() end
    end
end

-- entry must be of type Item.AllocateEntry
function LootAllocate:SetupSession(session, entry)
    entry.added = true
    Logging:Trace("SetupSession(%s) : %s", tostring(session), Util.Objects.ToString(entry))
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
    Logging:Trace("SwitchSession(%s)", tostring(sess))
    local C = AddOn.Constants

    session = sess
    local entry = LootAllocate.GetLootTableEntry(sess)
    self.frame.itemIcon:SetNormalTexture(entry.texture)
    self.frame.itemIcon:SetBorderColor("purple")
    self.frame.itemText:SetText(entry.link)
    self.frame.iState:SetText(self:GetItemStatus(entry.link))
    self.frame.itemLvl:SetText(_G.ITEM_LEVEL_ABBR..": " .. entry:GetLevelText())
    self.frame.gp:SetText("GP: " .. tostring(GP:GetValue(entry.link)))
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


function LootAllocate:SetCandidateData(session, candidate, data, val)
    local function Set(session, candidate, data, val)
        Logging:Trace("SetCandidateData(%s, %s) : data=%s val=%s", session, candidate, Util.Objects.ToString(data), Util.Objects.ToString(val))
        LootAllocate.GetLootTableEntryResponse(session, candidate):Set(data, val)
    end
    local ok, _ = pcall(Set, session, candidate, data, val)
    if not ok then
        Logging:Warn("SetCandidateData() : Error for candidate=%s", candidate)
    end
end

function LootAllocate:GetCandidateData(session, candidate, data)
    local function Get(session, candidate, data)
        Logging:Trace("GetCandidateData(%s, %s) : data=%s", session, candidate, Util.Objects.ToString(data))
        return LootAllocate.GetLootTableEntryResponse(session, candidate):Get(data)
    end
    local ok, arg = pcall(Get, session, candidate, data)
    if not ok then
        Logging:Warn("GetCandidateData() : Error for candidate=%s", candidate)
    else
        return arg
    end
end


function LootAllocate:CandidateCheck()
    Logging:Trace("CandidateCheck()")
    -- our name isn't present, assume not received
    if not AddOn.candidates[AddOn.playerName] and AddOn.masterLooter then
        local C = AddOn.Constants
        Logging:Warn("CandidateCheck() : Failed")
        AddOn:SendCommand(AddOn.masterLooter, C.Commands.CandidatesRequest)
        self:ScheduleTimer("CandidateCheck", 20)
    end
end

function LootAllocate:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)
    local C = AddOn.Constants
    if prefix == C.name then
        local success, command, data = AddOn:Deserialize(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, data=%s", tostring(success), command, Util.Objects.ToString(data, 3))
        if success then
            if command == C.Commands.LootAck then
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
            elseif command == C.Commands.Awarded and AddOn:UnitIsUnit(sender, AddOn.masterLooter) then

            elseif command == C.Commands.OfflineTimer and AddOn:UnitIsUnit(sender, AddOn.masterLooter) then
                for i = 1, #lootTable do
                    for candidate in pairs(lootTable[i].candidates) do
                        if self:GetCandidateData(i, candidate, "response") == "ANNOUNCED" then
                            Logging:Warn("No response from %s", candidate)
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
            elseif command == C.Commands.Rolls then

            elseif command == C.Commands.Roll then

            elseif command == C.Commands.ReconnectData and AddOn:UnitIsUnit(sender, AddOn.masterLooter) then

            elseif command == C.Commands.LootTableAdd and AddOn:UnitIsUnit(sender, AddOn.masterLooter) then
                local oldLen = #lootTable
                for index, entry in pairs(unpack(data)) do
                    Logging:Debug("LootTableAdd(%s, %s) : %s", tostring(oldLen), tostring(index), Util.Objects.ToString(entry, 4))
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
    self.frame.st:SetData(rows)
end


function LootAllocate:UpdateMoreInfo(row, data)
    Logging:Trace("UpdateMoreInfo(%s) : %s", tostring(row), Util.Objects.ToString(data, 2))
    local name
    if data and row then
        name = data[row].name
    else
        local selection = self.frame.st:GetSelection()
        name = selection and self.frame.st:GetRow(selection).name or nil
    end

    if not moreInfo or not name then
        return self.frame.moreInfo:Hide()
    end


end

function GuildRankSort(table, rowa, rowb, sortbycol)

end

function ResponseSort(table, rowa, rowb, sortbycol)

end

function EpSort(table, rowa, rowb, sortbycol)

end

function GpSort(table, rowa, rowb, sortbycol)

end

function PrSort(table, rowa, rowb, sortbycol)

end


-- @param session the session id
-- @param name the candidate name
-- param reason the reason for award
function LootAllocate:GetAwardPopupData(session, name, reason)
    return LootAllocate.GetLootTableEntry(session):GetAwardData(session, name, reason)
end

function LootAllocate:GetFrame()
    if self.frame then return self.frame end

    local f =  UI:CreateFrame("R2D2_LootAllocate", "LootAllocate", L["r2d2_loot_allocate_frame"], 250, 420)
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
                    MSA_ToggleDropDownMenu(1, nil, MenuFrame, cellFrame, 0, 0);
                -- update more info
                elseif button == "LeftButton" and row then
                    self:UpdateMoreInfo(realrow, data)
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
                if row then self:UpdateMoreInfo(realrow, data) end
                -- Return false to have the default OnEnter handler take care mouseover
                return false
            end
        })
        -- return to the actual selected player when we remove the mouse
        st:RegisterEvents({
            ["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                self:UpdateMoreInfo()
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
            if not lootTable then return; end
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
    f.abortBtn = b1

    -- more info button
    local b2 = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    b2:SetSize(25,25)
    b2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -20)
    if moreInfo then
        b2:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
        b2:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
    else
        b2:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        b2:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    end
    b2:SetScript("OnClick", function(button)
        moreInfo = not moreInfo
        if moreInfo then
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
        else -- hide it
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        end
        self:UpdateMoreInfo()
    end)
    b2:SetScript("OnEnter", function() UI:CreateTooltip(L["click_more_info"]) end)
    b2:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.moreInfoBtn = b2
    f.moreInfo = CreateFrame( "GameTooltip", "RCVotingFrameMoreInfo", nil, "GameTooltipTemplate" )
    f.content:SetScript("OnSizeChanged", function()
        f.moreInfo:SetScale(f:GetScale() * 0.6)
    end)

    -- filter
    local b3 = UI:CreateButton(_G.FILTER, f.content)
    b3:SetPoint("RIGHT", b1, "LEFT", -10, 0)
    b3:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    b3:SetScript("OnEnter", function() UI:CreateTooltip(L["deselect_responses"]) end)
    b3:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.filter = b3

    -- todo : number of botes/roll

    -- loot status
    f.lootStatus = UI:New("Text", f.content, " ")
    f.lootStatus:SetTextColor(1,1,1,1)
    f.lootStatus:SetHeight(20)
    f.lootStatus:SetWidth(150)
    f.lootStatus:SetPoint("RIGHT", rf, "LEFT", -10, 0)
    f.lootStatus:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.lootStatus.text:SetJustifyH("RIGHT")

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
    },
    -- level 2
    {
        -- 2 AWARD_FOR
        {
            special = "AWARD_FOR",
        }
    },
}

local info = MSA_DropDownMenu_CreateInfo()
function LootAllocate.RightClickMenu(menu, level)
    Logging:Trace("RightClickMenu()")
    if not AddOn.isMasterLooter then return end

    local candidateName = menu.name
    local value = _G.MSA_DROPDOWNMENU_MENU_VALUE
    for _, entry in ipairs(LootAllocate.RightClickEntries[level]) do
        info = MSA_DropDownMenu_CreateInfo()
        if not entry.special then
            if not entry.onValue or entry.onValue == value or (type(entry.onValue)=="function" and entry.onValue(candidateName)) then
                if (entry.hidden and type(entry.hidden) == "function" and not entry.hidden(candidateName)) or not entry.hidden then
                    for name, val in pairs(entry) do
                        if name == "func" then
                            info[name] = function() return val(candidateName) end
                        elseif type(val) == "function" then
                            info[name] = val(candidateName)
                        else
                            info[name] = val
                        end
                    end
                    MSA_DropDownMenu_AddButton(info, level)
                end
            end
        elseif value == "AWARD_FOR" and entry.special == value then
            for k,v in ipairs(db.awardReasons) do
                if k > db.numAwardReasons then break end
                info.text = v.text
                info.notCheckable = true
                info.func = function()
                    Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward, LootAllocate:GetAwardPopupData(session, candidateName, v))
                end
                MSA_DropDownMenu_AddButton(info, level)
            end
        elseif value == "CHANGE_RESPONSE" and entry.special == value then
        end
    end
end


function LootAllocate.FilterMenu(menu, level)
    Logging:Trace("FilterMenu()")
end

function LootAllocate.FilterFunc(table, row)
    Logging:Trace("FilterFunc(%s) : %s", tostring(row), table and type(table) or 'nil')
    return true
end

function LootAllocate:Update(forceUpdate)
    Logging:Trace("Update(%s)", tostring(forceUpdate))
    updatePending = false
    if not forceUpdate and updateIntervalRemaining > 0 then
        updatePending = true
        return
    end

    if not self.frame then return end
    if not lootTable[session] then
        Logging:Warn("Update() : No Loot Table entry for session=%s", tostring(session))
        return
    end

    updateIntervalRemaining = MIN_UPDATE_INTERVAL
    -- twice?
    self.frame.st:SortData()
    self.frame.st:SortData()
    local entry = LootAllocate.GetLootTableEntry(session)

    if entry and entry.awarded then
        local response = entry:GetCandidateResponse(name)
        self.frame.awardString:SetText(L["item_awarded_to"])
        self.frame.awardString:Show()
        local name = entry.awarded
        self.frame.awardStringPlayer:SetText(AddOn.Ambiguate(name))
        local c = AddOn:GetClassColor(response.class)
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
            self.frame.abortBtn:SetText(L["abort"])
        else
            self.frame.abortBtn:SetText(_G.CLOSE)
        end
    else
        self.frame.abortBtn:SetText(_G.CLOSE)
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
-- any newly created or existing button is then updates to reflect the sstatus
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
-- functions below starting with 'SetCell' are invoked for settinv values of individual cells in a row
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
    local c = AddOn:GetClassColor(LootAllocate.GetLootTableEntryResponse(session, name).class)
    frame.text:SetTextColor(c.r, c.g, c.b, c.a)
    data[realrow].cols[column].value = name or ""
end

function LootAllocate.SetCellRank(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local entry = LootAllocate.GetLootTableEntry(session)
    local response = entry:GetCandidateResponse(name)

    Logging:Trace("SetCellRank(%s) : %s", name, response.rank)
    frame.text:SetText(lootTable[session].candidates[name].rank)
    frame.text:SetTextColor(AddOn:GetResponseColor(entry.typeCode or  entry.equipLoc, response.response))
    data[realrow].cols[column].value = response.rank or ""
end

function LootAllocate.SetCellEp(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local ep = 0

    frame.text:SetText(ep)
    data[realrow].cols[column].value = ep
end

function LootAllocate.SetCellGp(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local gp = 0

    frame.text:SetText(gp)
    data[realrow].cols[column].value = gp
end

function LootAllocate.SetCellPr(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local pr = 0.0

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
    Logging:Trace("SetCellIlvl(%s) : %s (%s)", name,cresponse.ilvl, type(cresponse.ilvl))
    frame.text:SetText(iLvlDecimal and Util.Numbers.Round2(cresponse.ilvl, 2) or Util.Numbers.Round2(cresponse.ilvl))
    data[realrow].cols[column].value = cresponse.ilvl or ""
end

function LootAllocate.SetCellDiff(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local cresponse = LootAllocate.GetLootTableEntryResponse(session, name)

    Logging:Trace("SetCellDiff(%s) : %s", name, cresponse.diff)
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
