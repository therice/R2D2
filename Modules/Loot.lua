local name, AddOn = ...
local Loot      = AddOn:NewModule("Loot","AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0")
local Logging   = AddOn.Libs.Logging
local Util      = AddOn.Libs.Util
local UI        = AddOn.components.UI
local L         = AddOn.components.Locale
local Models    = AddOn.components.Models

local ENTRY_HEIGHT = 80
local MAX_ENTRIES = 6
local MIN_BUTTON_WIDTH = 40

local awaitingRolls = {}
local ROLL_TIMEOUT = 1.5
local ROLL_SHOW_RESULT_TIME = 3

local RANDOM_ROLL_PATTERN =
    _G.RANDOM_ROLL_RESULT:gsub("%(", "%%(")
            :gsub("%)", "%%)")
            :gsub("%%%d%$", "%%")
            :gsub("%%s", "(.+)")
            :gsub("%%d", "(%%d+)")

function Loot:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- mapping from session to Item.LootEntry
    self.items = {}
    self.frame = self:GetFrame()
    self:RegisterEvent("CHAT_MSG_SYSTEM")

    -- only register comm hook if support is enabled by ML
    local showLootResponses = AddOn:GetMasterLooterDbValue('showLootResponses')
    if Util.Objects.IsBoolean(showLootResponses) and showLootResponses then
        self:RegisterComm(name, "OnCommReceived")
    end
end

function Loot:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:Hide()
    self.items = {}
    self:CancelAllTimers()
    self:UnregisterAllComm()
end

function Loot:EnableOnStartup()
    return false
end

function Loot:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)

    local C = AddOn.Constants
    if prefix == C.name and not AddOn:UnitIsUnit(sender, "player") then
        local success, command, data = AddOn:ProcessReceived(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, from=%s, dist=%s, data=%s,",
                tostring(success), command, tostring(sender), tostring(dist),
                Logging:IsEnabledFor(Logging.Level.Trace) and Util.Objects.ToString(data, 1) or '[omitted]'
        )

        if success then
            -- this won't include automatic pass responses, those come via LootAck
            -- however, we aren't concerned with those here unless we map to the
            -- Pass button (which currently is not done)
            if command == C.Commands.Response then
                local session, name, t = unpack(data)
                -- e.g. t = {response = 1}
                Logging:Debug(
                        "OnCommReceived() : %s response for session %d => %s",
                        name, session, Util.Objects.ToString(t)
                )
                if Util.Tables.ContainsKey(t, 'response') then
                    -- find the item associated with this session
                    local _, item = Util.Tables.FindFn(
                            self.items,
                            -- in case of duplicate entries, should we check for rolled?
                            function(e) return Util.Objects.In(session, e.sessions)end
                    )
                    -- This will be of type LootEntry
                    if item then
                        Logging:Debug("OnCommReceived() : %s(%s) / session %d => %s",
                                name,
                                tostring(AddOn:GetUnitClass(name)),
                                session,
                                Util.Objects.ToString(item)
                        )
                        item:TrackResponse(name, t.response)
                        Logging:Debug("OnCommReceived() : %s responses => %s",
                                tostring(item.link),
                                Util.Objects.ToString(item.responders)
                        )
                    end
                end
            end
        end
    end
end


-- @param item a Model.ItemEntry
function Loot:AddItem(offset, k, item)
    --[[
        AddItem(0, 1,
            {
                equipLoc = INVTYPE_WAIST,
                typeId = 4,
                isRoll = true,
                boe = false,
                texture = 132512,
                type = Armor,
                link = [Bloodfang Belt],
                typeCode = default,
                subType = Leather,
                classes = 8,
                quality = 4, i
                lvl = 76,
                noAutopass = true,
                subTypeId = 2,
                session = 1,
                id = 16910
            }
        )
    --]]
    -- Logging:Trace("AddItem(%s, %s, %s)", offset, k, Util.Objects.ToString(item))
    self.items[offset + k] = item:ToLootEntry(AddOn:GetMasterLooterDbValue('timeout'))
end

function Loot:CheckDuplicates(size, offset)
    -- Logging:Trace("CheckDuplicates(%s, %s)", size, offset)
    for k = offset + 1, offset + size do
        if not self.items[k].rolled then
            for j = offset + 1, offset + size do
                if j ~= k and AddOn:ItemIsItem(self.items[k].link, self.items[j].link) and not self.items[j].rolled then
                    Logging:Warn("CheckDuplicates() : %s is a duplicate of %s",
                            Util.Objects.ToString(self.items[k].link),
                            Util.Objects.ToString(self.items[j].link)
                    )

                    Util.Tables.Push(self.items[k].sessions, self.items[j].sessions[1])
                    -- Pretend we have rolled it
                    self.items[j].rolled = true
                end
            end
        end
    end
end

-- table will be entries of Model.ItemEntry
function Loot:Start(table, reRoll)
    reRoll = reRoll or false
    local offset = 0
    -- if re-roll, insert the items at end
    if reRoll then
        offset = #self.items
    -- not a re-roll, we need to restart
    elseif #self.items > 0 then
        -- avoid problems with loot table being received when the loot frame is shown
        self:OnDisable()
    end

    for k =1, #table do
        -- if auto-pass, pretend it was rolled
        if table[k].autoPass then
            self.items[offset + k] = Models.LootEntry.Rolled()
        else
            self:AddItem(offset, k, table[k])
        end
    end

    self:CheckDuplicates(#table, offset)
    self:Show()
end

function Loot:AddSingleItem(item)
    if not self:IsEnabled() then self:Enable() end
    -- Logging:Trace("AddSingleItem(%s, %s)", item.link, #self.items)
    if item.autoPass then
        self.items[#self.items + 1] = Models.LootEntry.Rolled()
    else
        self:AddItem(0, #self.items + 1, item)
        self:Show()
    end
end

function Loot:ReRoll(table)
    --[[
        {
            {
                equipLoc = INVTYPE_WAIST,
                ilvl = 76,
                link = [Dragonstalker's Belt],
                isRoll = true,
                classes = 4,
                noAutopass = true,
                typeCode = default,
                session = 1,
                texture = 132517
            }
        }
    --]]
    -- Logging:Trace("ReRoll(%s)", #table)
    self:Start(table, true)
end

function Loot:GetFrame()
    if self.frame then return self.frame end
    -- Logging:Trace("GetFrame() : creating loot frame")
    self.frame = UI:CreateFrame("R2D2_LootFrame", "Loot", L["r2d2_loot_frame"], 250, 375, false)
    -- override default behavior for ESC to not close the loot window
    -- too easy to make mistakes and not get an opportunity to specify a response
    self.frame:SetScript(
            "OnKeyDown",
            function(self, key)
                if key == "ESCAPE" then
                    self:SetPropagateKeyboardInput(false)
                else
                    self:SetPropagateKeyboardInput(true)
                end
            end
    )
    self.frame.itemTooltip = UI:CreateGameTooltip("Loot", self.frame.content)
    return self.frame
end

function Loot:Show()
    self.frame:Show()
    self:Update()
end

function Loot:Update()
    local numEntries = 0
    for _, item in ipairs(self.items) do
        if numEntries >= MAX_ENTRIES then break end
        if not item.rolled then
            numEntries = numEntries + 1
            self.EntryManager:GetEntry(item)
        end
    end

    if numEntries == 0 then return self:Disable() end
    self.EntryManager:Update()
    self.frame.content:SetHeight(numEntries * ENTRY_HEIGHT + 7)

    local first = self.EntryManager.entries[1]
    local alwaysShowTooltip = false

    if first and alwaysShowTooltip then
        self.frame.itemTooltip:SetOwner(self.frame.content, "ANCHOR_NONE")
        self.frame.itemTooltip:SetHyperlink(first.item.link)
        self.frame.itemTooltip:Show()
        self.frame.itemTooltip:SetPoint("TOPRIGHT", first.frame, "TOPLEFT", 0, 0)
    else
        self.frame.itemTooltip:Hide()
    end
end

-- this function updates the GP portion of Item Text with values based upon button (and associated award scaling)
function Loot.UpdateItemText(entry, award_scale)
    local item = entry.item
    entry.itemLvl:SetText(
            "Level " .. item:GetLevelText() ..
            " " .. AddOn:GearPointsModule():GetGpTextColored(item, award_scale) ..
            " |cff7fffff".. item:GetTypeText() .. "|r"
    )
end

function Loot.UpdateItemResponders(entry, response)
    if entry and entry.item and response then
        local responders = entry.item.responders and entry.item.responders[response] or nil
        if responders and Util.Tables.Count(responders) > 0 then
            local text = {}
            for _, responder in
                pairs(
                    Util.Tables.Sort(
                            Util.Tables.Copy(responders),
                            function (a, b) return a < b end
                    )
                ) do
                Util.Tables.Push(text, AddOn:GetUnitClassColoredName(responder))
            end
            UI:CreateTooltip(unpack(text))
        end
    end
end

function Loot:OnRoll(entry, button)
    local C = AddOn.Constants
    local item = entry.item
    -- Logging:Trace("OnRoll(%s)", tostring(button), Util.Objects.ToString(item))

    if not item.isRoll then
        -- Only send minimum necessary data, because the information of currently equipped gear has been sent
        -- when we receive the loot table
        
        -- Logging:Trace("OnRoll(%s) : %s", tostring(button), response and Util.Objects.ToString(response) or 'nil')
        for _, session in ipairs(item.sessions) do
            AddOn:SendResponse(C.group, session, button, item.note)
        end
        
        
        local response = AddOn:GetResponse(item.typeCode or item.equipLoc, button)
        local me = AddOn:PointsModule().GetEntry(AddOn.playerName)
        AddOn:Print(format(L["response_to_item"], AddOn:GetItemTextWithCount(item.link, #item.sessions))
                .. " : " .. (response and response.text or "???")
                .. format(" (PR %.2f)", (me and me:GetPR() or 0.0))
        )
        
        item.rolled = true
        self.EntryManager:Trash(entry)
        self:Update()
    else
        -- request for a roll
        if button == "ROLL" then
            local el = { sessions = item.sessions, entry = entry}
            Util.Tables.Push(awaitingRolls, el)
            -- In case roll result is not received within time limit, discard the result.
            el.timer = self:ScheduleTimer("OnRollTimeout", ROLL_TIMEOUT, el)
            RandomRoll(1, 100)
            -- disable roll button
            entry.buttons[1]:Disable()
            -- disable pass button
            entry.buttons[2]:Hide()
        else
            item.rolled = true
            self.EntryManager:Trash(entry)
            self:Update()
            AddOn:SendCommand(C.group, C.Commands.Roll, AddOn.playerName, "-", item.sessions)
        end
    end
end

function Loot:OnRollTimeout(el)
    tDeleteItem(awaitingRolls, el)
    local entry = el.entry
    entry.item.rolled = true
    self.EntryManager:Trash(entry)
    self:Update()
end

function Loot:CHAT_MSG_SYSTEM(event, msg)
    Logging:Trace("CHAT_MSG_SYSTEM(%s) : %s", tostring(event), tostring(msg))

    local C = AddOn.Constants
    local name, roll, low, high = msg:match(RANDOM_ROLL_PATTERN)
    roll, low, high = tonumber(roll), tonumber(low), tonumber(high)

    if name and low == 1 and high == 100 and AddOn:UnitIsUnit(Ambiguate(name, "short"), "player") and awaitingRolls[1] then
        local el = awaitingRolls[1]
        tremove(awaitingRolls, 1)
        self:CancelTimer(el.timer)
        local entry = el.entry
        AddOn:SendCommand(C.group, C.Commands.Roll, AddOn.playerName, roll, entry.item.sessions)
        AddOn:SendAnnouncement(format(L["roll_result"], AddOn.Ambiguate(AddOn.playerName), roll, entry.item.link), C.group)
        entry.rollResult:SetText(roll)
        entry.rollResult:Show()
        self:ScheduleTimer("OnRollTimeout", ROLL_SHOW_RESULT_TIME, el)
    end
end

do
    local EntryProto = {
        type = "normal",
        Update = function(entry, item)
            if not item then
                Logging:Warn("EntryProto.Update() : No item provided")
                return
            end
    
            if item ~= entry.item then
                entry.noteEditbox:Hide()
                entry.noteEditbox:SetText("")
            end
    
            if item.isRoll then
                entry.noteButton:Hide()
            else
                entry.noteButton:Show()
            end
            
            entry.item = item
            entry.itemText:SetText(
                    item.isRoll and (_G.ROLL .. ": ") or "" ..
                    AddOn:GetItemTextWithCount(entry.item.link or "error", #entry.item.sessions)
            )
            entry.icon:SetNormalTexture(entry.item.texture or "Interface\\InventoryItems\\WoWUnknownItem01")
            entry.itemCount:SetText(#entry.item.sessions > 1 and #entry.item.sessions or "")
            Loot.UpdateItemText(entry)
            if entry.item.note then
                entry.noteButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            else
                entry.noteButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
            end
            
            if AddOn:GetMasterLooterDbValue('timeout') then
                entry.timeoutBar:SetMinMaxValues(0, AddOn:GetMasterLooterDbValue('timeout') or AddOn:MasterLooterModule():DbValue('timeout'))
                entry.timeoutBar:Show()
            else
                entry.timeoutBar:Hide()
            end

            if AddOn:UnitIsUnit(item.owner, "player") then
                entry.frame:SetBackdrop({
                    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                    edgeSize = 20,
                    insets = { left = 2, right = 2, top = -2, bottom = -14 }
                })
                entry.frame:SetBackdropBorderColor(0,1,1,1)
            else
                entry.frame:SetBackdrop(nil)
            end
            entry:UpdateButtons()
            entry:Show()
        end,
        Show = function(entry) entry.frame:Show() end,
        Hide = function(entry) entry.frame:Hide() end,
        Create = function(entry, parent)
            entry.width = parent:GetWidth()
            entry.frame = CreateFrame("Frame", "R2D2_LootFrame_Entry(" .. Loot.EntryManager.numEntries .. ")", parent)
            entry.frame:SetWidth(entry.width)
            entry.frame:SetHeight(ENTRY_HEIGHT)
            entry.frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
            -- item icon
            entry.icon = UI:New("IconBordered", entry.frame)
            entry.icon:SetBorderColor()
            entry.icon:SetSize(ENTRY_HEIGHT * 0.78, ENTRY_HEIGHT * 0.78)
            entry.icon:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 9, -5)
            entry.icon:SetMultipleScripts({
                OnEnter = function()
                    if not entry.item.link then return end
                    UI:CreateHypertip(entry.item.link)
                    GameTooltip:AddLine("")
                    GameTooltip:AddLine(L["always_show_tooltip_howto"], nil, nil, nil, true)
                    GameTooltip:Show()
                end,
                OnClick = function()
                    if not entry.item.link then return end
                    if IsModifiedClick() then
                        HandleModifiedItemClick(entry.item.link)
                    end
                    if entry.icon.lastClick and GetTime() - entry.icon.lastClick <= 0.5 then
                        Loot:Update()
                    else
                        entry.icon.lastClick = GetTime()
                    end
                end,
            })
            entry.itemCount = entry.icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
            local fileName, _, flags = entry.itemCount:GetFont()
            entry.itemCount:SetFont(fileName, 20, flags)
            entry.itemCount:SetJustifyH("RIGHT")
            entry.itemCount:SetPoint("BOTTOMRIGHT", entry.icon, "BOTTOMRIGHT", -2, 2)
            entry.itemCount:SetText("error")
            -- buttons
            entry.buttons = {}
            entry.UpdateButtons = function(entry)
                local b = entry.buttons
                local numButtons = AddOn:GetNumButtons(entry.type)
                local buttons = AddOn:GetButtons(entry.type)
                local width = 113 + numButtons * 5
                for i = 1, numButtons + 1 do
                    if i > numButtons then
                        b[i] = b[i] or UI:CreateButton(_G.PASS, entry.frame)
                        b[i]:SetText(_G.PASS)
                        b[i]:SetMultipleScripts({
                            OnEnter = function() Loot.UpdateItemResponders(entry, "PASS") end,
                            OnLeave = function() UI:HideTooltip() end,
                            OnClick = function() Loot:OnRoll(entry, "PASS") end,
                        })
                    else
                        b[i] = b[i] or UI:CreateButton(buttons[i].text, entry.frame)
                        b[i]:SetText(buttons[i].text)
                        b[i]:SetMultipleScripts({
                            OnEnter = function()
                                Loot.UpdateItemResponders(entry, i)
                                Loot.UpdateItemText(entry, buttons[i].award_scale)
                            end,
                            OnLeave = function()
                                UI:HideTooltip()
                                Loot.UpdateItemText(entry)
                            end,
                            OnClick = function() Loot:OnRoll(entry, i) end,
                        })
                    end
                    b[i]:SetWidth(b[i]:GetTextWidth() + 10)
                    if b[i]:GetWidth() < MIN_BUTTON_WIDTH then b[i]:SetWidth(MIN_BUTTON_WIDTH) end
                    width = width + b[i]:GetWidth()
                    if i == 1 then
                        b[i]:SetPoint("BOTTOMLEFT", entry.icon, "BOTTOMRIGHT", 5, 0)
                    else
                        b[i]:SetPoint("LEFT", b[i-1], "RIGHT", 5, 0)
                    end
                    b[i]:Show()
                end
                -- Check if we've more buttons than we should
                if #b > numButtons + 1 then
                    for i = numButtons + 2, #b do b[i]:Hide() end
                end
                entry.width = width
                entry.width = math.max(entry.width, 90 + entry.itemText:GetStringWidth())
                entry.width = math.max(entry.width, 89 + entry.itemLvl:GetStringWidth())
            end

            -- note
            entry.noteButton = CreateFrame("Button", nil, entry.frame)
            entry.noteButton:SetSize(24,24)
            entry.noteButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
            entry.noteButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
            entry.noteButton:SetPoint("BOTTOMRIGHT", entry.frame, "TOPRIGHT", -9, -entry.icon:GetHeight()-5)
            entry.noteButton:SetScript("OnEnter", function()
                if entry.item.note then
                    UI:CreateTooltip(L["your_note"], entry.item.note .. "\n", L["change_note"])
                else
                    UI:CreateTooltip(L["add_note"], L["add_note_desc"])
                end
            end)
            entry.noteButton:SetScript("OnLeave", function() UI:HideTooltip() end)
            entry.noteButton:SetScript("OnClick", function()
                if not entry.noteEditbox:IsShown() then
                    entry.noteEditbox:Show()
                else
                    entry.noteEditbox:Hide()
                    entry.item.note = entry.noteEditbox:GetText() ~= "" and entry.noteEditbox:GetText()
                    entry:Update(entry.item)
                end
            end)

            entry.noteEditbox = CreateFrame("EditBox", nil, entry.frame, "AutoCompleteEditBoxTemplate")
            entry.noteEditbox:SetMaxLetters(64)
            entry.noteEditbox:SetBackdrop(Loot.frame.title:GetBackdrop())
            entry.noteEditbox:SetBackdropColor(Loot.frame.title:GetBackdropColor())
            entry.noteEditbox:SetBackdropBorderColor(Loot.frame.title:GetBackdropBorderColor())
            entry.noteEditbox:SetFontObject(_G.ChatFontNormal)
            entry.noteEditbox:SetJustifyV("BOTTOM")
            entry.noteEditbox:SetWidth(100)
            entry.noteEditbox:SetHeight(24)
            entry.noteEditbox:SetPoint("BOTTOMLEFT", entry.frame, "TOPRIGHT", 0, -entry.icon:GetHeight()-5)
            entry.noteEditbox:SetTextInsets(5, 5, 0, 0)
            entry.noteEditbox:SetScript("OnEnterPressed", function(self)
                self:Hide()
                entry:Update(entry.item)
            end)
            entry.noteEditbox:SetScript("OnTextChanged", function(self)
                entry.item.note = self:GetText() ~= "" and self:GetText()
                -- Change the note button instead of calling entry:Update on every single input
                if entry.item.note then
                    entry.noteButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
                else
                    entry.noteButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
                end
            end)
            entry.noteEditbox:Hide()

            -- item level/text
            entry.itemText = entry.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            entry.itemText:SetPoint("TOPLEFT", entry.icon, "TOPRIGHT", 6, -1)
            entry.itemText:SetText("Um, ...")

            entry.itemLvl = entry.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            entry.itemLvl:SetPoint("TOPLEFT", entry.itemText, "BOTTOMLEFT", 1, -4)
            entry.itemLvl:SetTextColor(1, 1, 1)
            entry.itemLvl:SetText("error")
            -- timeoutBar
            entry.timeoutBar = CreateFrame("StatusBar", nil, entry.frame, "TextStatusBar")
            entry.timeoutBar:SetSize(entry.frame:GetWidth(), 6)
            entry.timeoutBar:SetPoint("BOTTOMLEFT", 9,3)
            entry.timeoutBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            --entry.timeoutBar:SetStatusBarColor(0.1, 0, 0.6, 0.8)
            --entry.timeoutBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
            --entry.timeoutBar:SetStatusBarColor(1, 0.96, 0.41, 1)
            entry.timeoutBar:SetStatusBarColor(0.00, 1.00, 0.59, 1)
            entry.timeoutBar:SetMinMaxValues(0, 60)
            entry.timeoutBar:SetScript("OnUpdate", function(this, elapsed)
                --Timeout!
                if entry.item.timeLeft <= 0 then
                    this.text:SetText(L["timeout"])
                    this:SetValue(0)
                    return Loot:OnRoll(entry, "TIMEOUT")
                end
                entry.item.timeLeft = entry.item.timeLeft - elapsed
                this.text:SetText(_G.CLOSES_IN .. ": " .. ceil(entry.item.timeLeft))
                this:SetValue(entry.item.timeLeft)
            end)

            local main_width = entry.frame.SetWidth
            function entry:SetWidth(width)
                self.timeoutBar:SetWidth(width - 18)
                main_width(self.frame, width)
                self.width = width
            end

            entry.timeoutBar.text = entry.timeoutBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            entry.timeoutBar.text:SetPoint("CENTER", entry.timeoutBar)
            entry.timeoutBar.text:SetTextColor(1,1,1)
            entry.timeoutBar.text:SetText("Timeout")
        end,
    }

    local mt = { __index = EntryProto}

    Loot.EntryManager = {
        numEntries = 0,
        entries = {},
        trashPool = {},
    }

    function Loot.EntryManager:Trash(entry)
        -- Logging:Trace("Trash(%s, %s)", entry.position or 0, entry.item.link)
        entry:Hide()
        if not Util.Tables.ContainsKey(self.trashPool, entry.type) then Util.Tables.Set(self.trashPool, entry.type, {}) end
        Util.Tables.Set(self.trashPool, entry.type, entry, true)
        tDeleteItem(self.entries, entry)
        Util.Tables.Remove(self.entries, entry.item)
        self.numEntries = self.numEntries - 1
    end

    function Loot.EntryManager:Get(type)
        if not self.trashPool[type] then return nil end
        local t = next(self.trashPool[type])
        if t then
            Util.Tables.Set(self.trashPool, type, t, nil)
            return t
        end
    end

    function Loot.EntryManager:Update()
        local max = 0
        for i, entry in ipairs(self.entries) do
            if entry.width > max then max = entry.width end
            if i == 1 then
                entry.frame:SetPoint("TOPLEFT", Loot.frame.content, "TOPLEFT",0,-5)
            else
                entry.frame:SetPoint("TOPLEFT", self.entries[i-1].frame, "BOTTOMLEFT")
            end
            entry.position = i
        end
        Loot.frame:SetWidth(max)
        for _, entry in ipairs(self.entries) do
            entry:SetWidth(max)
        end
    end

    function Loot.EntryManager:GetEntry(item)
        --[[
            GetEntry() : {
                equipLoc = INVTYPE_FINGER, ilvl = 73, isRoll = false, rolled = false, subTypeId = 0, timeLeft = 60, quality = 4, type = Armor, link = [Ring of Binding], id = 18813, subType = Miscellaneous, classes = 4294967295, sessions = {1}, typeId = 4, typeCode = default, boe = false, texture = 133355}
        --]]
        -- Logging:Trace("GetEntry() : %s", Util.Objects.ToString(item))
        if not item then return Logging:Warn("GetEntry(%s) : No such item", Util.Objects.ToString(item)) end
        if self.entries[item] then return self.entries[item] end

        local entry
        if item.isRoll then
            entry = self:Get("roll")
        else
            entry = self:Get(item.typeCode or item.equipLoc)
        end

        if entry then
            entry:Update(item)
        else
            if item.isRoll then
                entry = self:GetRollEntry(item)
            else
                entry = self:GetNewEntry(item)
            end
        end
        entry:SetWidth(entry.width)
        entry:Show()
        self.numEntries = self.numEntries + 1
        entry.position = self.numEntries
        self.entries[self.numEntries] = entry
        self.entries[item] = entry
        return entry
    end

    function Loot.EntryManager:GetNewEntry(item)
        local Entry = setmetatable({}, mt)
        Entry.type = item.typeCode or item.equipLoc
        Entry:Create(Loot.frame.content)
        Entry:Update(item)
        return Entry
    end

    function Loot.EntryManager:GetRollEntry(item)
        local Entry = setmetatable({}, mt)
        Entry.type = "roll"
        Entry:Create(Loot.frame.content)

        function Entry.UpdateButtons(entry)
            local b = entry.buttons
            b[1] = b[1] or CreateFrame("Button", nil, entry.frame)
            b[2] = b[2] or CreateFrame("Button", nil, entry.frame)
            local roll, pass = b[1], b[2]

            roll:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
            roll:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")
            roll:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
            roll:SetScript("OnClick", function() Loot:OnRoll(entry, "ROLL") end)
            roll:SetSize(32, 32)
            roll:SetPoint("BOTTOMLEFT", entry.icon, "BOTTOMRIGHT", 5, -7)
            roll:Enable()
            roll:Show()

            pass:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            pass:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
            pass:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
            pass:SetScript("OnClick", function() Loot:OnRoll(entry, "PASS") end)
            pass:SetSize(32, 32)
            pass:SetPoint("LEFT", roll, "RIGHT", 5, 3)
            pass:Show()

            entry.rollResult = entry.rollResult or entry.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            entry.rollResult:SetPoint("LEFT", roll, "RIGHT", 5, 3)
            entry.rollResult:SetText("")
            entry.rollResult:Hide()

            local width = 113 + 1 * 5 + 32 + 32
            entry.width = width
            entry.width = math.max(entry.width, 90 + entry.itemText:GetStringWidth())
            entry.width = math.max(entry.width, 89 + entry.itemLvl:GetStringWidth())
        end
        Entry:Update(item)
        return Entry
    end
end

