local name, AddOn = ...
local ML        = AddOn:NewModule("MasterLooter", "AceEvent-3.0", "AceBucket-3.0", "AceComm-3.0", "AceTimer-3.0", "AceHook-3.0")
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local ItemUtil  = AddOn.Libs.ItemUtil
local Models    = AddOn.components.Models

local CANDIDATE_SEND_COOLDOWN = 10

ML.defaults = {
    profile = {
        buttons = {
            default = {
                numButtons = 4,
                { text = L["ms_need"],          whisperKey = L["whisperkey_ms"], },
                { text = L["os_greed"],         whisperKey = L["whisperkey_greed"], },
                { text = L["minor_upgrade"],    whisperKey = L["whisperkey_minor"], },
                { text = L["pvp"],              whisperKey = L["whisperkey_pvp"], },
            },
        },
        responses = {
            default = {
                AWARDED         =   { color = {1,1,1,1},		sort = 0.1,	text = L["awarded"], },
                NOTANNOUNCED    =   { color = {1,0,1,1},		sort = 501,	text = L["not_accounced"], },
                ANNOUNCED		=   { color = {1,0,1,1},		sort = 502,	text = L["announced_awaiting_answer"], },
                WAIT			=   { color = {1,1,0,1},		sort = 503,	text = L["candidate_selecting_response"], },
                TIMEOUT			=   { color = {1,0,0,1},		sort = 504,	text = L["candidate_no_response_in_time"], },
                NOTHING			=   { color = {0.5,0.5,0.5,1},	sort = 505,	text = L["offline_or_not_installed"], },
                PASS		    =   { color = {0.7, 0.7,0.7,1},	sort = 800,	text = _G.PASS, },
                AUTOPASS		=   { color = {0.7,0.7,0.7,1},	sort = 801,	text = L["auto_pass"], },
                DISABLED		=   { color = {0.3,0.35,0.5,1},	sort = 802,	text = L["disabled"], },
                NOTINRAID		=   { color = {0.7,0.6,0,1}, 	sort = 803, text = L["not_in_instance"]},
                DEFAULT	        =   { color = {1,0,0,1},		sort = 899,	text = L["response_unavailable"] },
                --[[1]]             { color = {0,1,0,1},        sort = 1,   text = L["ms_need"], },
                --[[2]]             { color = {1,0.5,0,1},	    sort = 2,	text = L["os_greed"], },
                --[[3]]             { color = {0,0.7,0.7,1},    sort = 3,	text = L["minor_upgrade"], },
                --[[4]]             { color = {1,0.5,0,1},	    sort = 4,	text = L["pvp"], },
            }
        }
    }
}

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), ML.defaults)
end

function ML:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- mapping of candidateName = { class, role, rank }
    self.candidates = {}
    -- the master looter's loot table
    self.lootTable = {}
    -- for keeping a backup for existing loot table on session end
    self.oldLootTable = {}
    -- items master looter has attempted to give out and waiting
    self.lootQueue = {}
    -- table of timer references, with key being timer name and value being timer id
    self.timers = {}
    -- is a session in flight
    self.running = false
    self:RegisterComm(name, "OnCommReceived")
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnEvent")
end

function ML:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:UnregisterAllEvents()
    self:UnregisterAllBuckets()
    self:UnregisterAllComm()
    self:UnregisterAllMessages()
    self:UnhookAll()
end

function ML:GetDbValue(...)
    local path = Util.Strings.Join('.', ...)
    return Util.Tables.Get(self.db.profile, path)
end

function ML:GetDefaultDbValue(...)
    local path = Util.Strings.Join('.', ...)
    return Util.Tables.Get(ML.defaults, path)
end


function ML:BuildDb()
    local db = self.db.profile

    -- iterate through the responses and capture any changes
    local changedResponses = {}
    for type, responses in pairs(db.responses) do
        for i in ipairs(responses) do
            -- don't capture more than number of buttons
            if i > self:GetDbValue('buttons', type, 'numButtons') then break end

            local defaultResponses = self:GetDefaultDbValue('profile.responses', type)
            local defaultResponse = defaultResponses and defaultResponses[i] or nil

            local dbResponse = self:GetDbValue('responses', type)[i]

            -- look at type, text and color
            if not defaultResponse
                or (dbResponse.text ~= defaultResponse.text)
                or (unpack(dbResponse.color) ~= unpack(defaultResponse.color)) then
                if not changedResponses[type] then changedResponses[type] = {} end
                changedResponses[type][i] = dbResponse
            end
        end
    end

    -- iterate through the buttons and capture any changes
    local changedButtons = {default = {}}
    for type, buttons in pairs(db.buttons) do
        for i in ipairs(buttons) do
            -- don't capture more than number of buttons
            if i > self:GetDbValue('buttons', type, 'numButtons') then break end

            local defaultResponses = self:GetDefaultDbValue('profile.buttons', type)
            local defaultResponse = defaultResponses and defaultResponses[i] or nil

            local dbResponse = self:GetDbValue('buttons', type)[i]

            -- look a type and text
            if not defaultResponse
                or (dbResponse.text ~= defaultResponse.text) then
                if not changedButtons[type] then changedButtons[type] = {} end
                changedButtons[type][i] = {text = dbResponse.text}
            end
        end
    end

    changedButtons.default.numButtons = db.buttons.default.numButtons

    local Db = {
        numButtons  =   db.buttons.default.numButtons,
        buttons     =   changedButtons,
        responses   =   changedResponses,
    }

    AddOn:SendMessage(AddOn.Constants.Messages.MasterLooterBuildDb, Db)

    return Db
end

function ML:UpdateDb()
    Logging:Trace("UpdateDb()")
    local C = AddOn.Constants
    AddOn:OnMasterLooterDbReceived(self:BuildDb())
    AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
end

function ML:AddCandidate(name, class, rank, enchant, lvl, ilvl)
    Logging:Trace("AddCandidate(%s, %s, %s, %s, %s, %s)",
            name, class, rank or 'nil', tostring(enchant),
            tostring(lvl or 'nil'), tostring(ilvl or 'nil')
    )
    Util.Tables.Insert(self.candidates, name, Models.Candidate:New(name, class, rank, enchant, lvl, ilvl))
end

function ML:RemoveCandidate(name)
    Logging:Trace("RemoveCandidate(%s)", name)
    Util.Tables.Remove(self.candidates, name)
end

function ML:UpdateCandidates(ask)
    Logging:Trace("UpdateCandidates(%s)", tostring(ask))
    if type(ask) ~= "boolean" then ask = false end

    local C = AddOn.Constants
    local candidates_copy = Util.Tables.Copy(self.candidates, function() return true end)
    local updates = false

    for i = 1, GetNumGroupMembers() do
        --
        -- in classic, combat role will always be NONE (so no need to check against it)
        --
        -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole
        --      = GetRaidRosterInfo(raidIndex)
        local name, _, _, _, _, class, _, _, _, _, _, role  = GetRaidRosterInfo(i)
        if name then
            name = AddOn:UnitName(name)
            if candidates_copy[name] then
                -- No need to check for a role change, classic doesn't have it
                Util.Tables.Remove(candidates_copy, name)
            else
                -- ask for their player information
                if ask then
                    AddOn:SendCommand(name, C.Commands.PlayerInfoRequest)
                end
                self:AddCandidate(name, class, role)
                updates = true
            end
        else
            Logging:Warn("GetRaidRosterInfo() returned nil for index = %s, retrying after a pause", i)
            return self:ScheduleTimer("UpdateCandidates", 1, ask)
        end
    end

    -- these folks no longer around (in raid)
    for n, _ in pairs(candidates_copy) do
        self:RemoveCandidate(n)
        updates = true
    end

    -- send updates to candidate list and db
    if updates then
        AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
        self:SendCandidates()
    end
end

local function SendCandidates()
    local C = AddOn.Constants
    AddOn:SendCommand(C.group, C.Commands.Candidates, ML.candidates)
    ML.timers.send_candidates = nil
end

local function OnCandidatesCooldown()
    ML.timers.cooldown_candidates = nil
end

-- sends candidates to the group no more than every CANDIDATE_SEND_INTERVAL seconds
function ML:SendCandidates()
    local C = AddOn.Constants
    -- recently sent one
    if self.timers.cooldown_candidates then
        -- we've queued a new one
        if self.timers.send_candidates then
            -- do nothing, once current timer expires it will be sent
            return
        -- send the candidates once interval has expired
        else
            local timeRemaining = self:TimeLeft(self.timers.cooldown_candidates)
            self.timers.send_candidates = self:ScheduleTimer(SendCandidates, timeRemaining)
            return
        end
    -- no cooldown, send immediately and start the cooldown
    else
        self.timers.cooldown_candidates = self:ScheduleTimer(OnCandidatesCooldown, CANDIDATE_SEND_COOLDOWN)
        AddOn:SendCommand(C.group, C.Commands.Candidates, self.candidates)
    end
end

function ML:NewMasterLooter(ml)
    Logging:Debug("NewMasterLooter(%s)", ml)
    local C = AddOn.Constants
    -- Are we are the the ML?
    if AddOn:UnitIsUnit(ml,C.player) then
        AddOn:SendCommand(C.group, C.Commands.PlayerInfoRequest)
        self:UpdateDb()
        self:UpdateCandidates(true)
    else
        -- don't use this module if we're not the ML
        self:Disable()
    end
end

function ML:Timer(type, ...)
    Logging:Trace("Timer(%s)", type)
    local C = AddOn.Constants
    if type == "AddItem" then
        self:AddItem(...)
    elseif type == "LootSend" then
        AddOn:SendCommand(C.group, C.Commands.OfflineTimer)
    end
end

function ML:GetItemInfo(item)
    return Models.Item:FromGetItemInfo(item)
end

-- adds an item to the loot table
-- @param Any: ItemID|itemString|itemLink
-- @param slotIndex index of the loot slot
-- @param owner the owner of the item (if any). Defaults to 'BossName'
-- @param index the index at which to add the entry, only needed on callbacks where item info was not available prev.
function ML:AddItem(item, slotIndex, owner, index)
    Logging:Trace("AddItem(%s)", item)
    -- todo : determine type code (as needed)
    index = index or nil
    local entry = Models.ItemEntry:New(item, slotIndex, false, owner, false, "default")

    -- Need to insert entry regardless of fully populated (IsValid) as the
    -- session frame needs each of them to start and will update as entries are
    -- populated
    if not index then
        Util.Tables.Push(self.lootTable, entry)
        -- capture the index in case we need for callback
        index = #self.lootTable
    -- callback, update the previous index to populated entry
    else
        self.lootTable[index] = entry
    end

    if not entry:IsValid() then
        self:ScheduleTimer("Timer", 0, "AddItem", item, slotIndex, owner, index)
        Logging:Trace("AddItem() : Started timer %s for %s (%s)", "AddItem", item, tostring(index))
    else
        AddOn:SendMessage(AddOn.Constants.Messages.MasterLooterAddItem, item, entry)
    end
end

function ML:RemoveItem(session)
    Util.Tables.Remove(self.lootTable, session)
end

function ML:GetLootTableForTransmit()
    Logging:Trace("GetLootTableForTransmit(PRE) : %s", Util.Objects.ToString(self.lootTable))
    local ltTransmit = Util(self.lootTable)
        :Copy()
        :Map(
            -- update the items as needed
            function(entry)
                Logging:Trace("getmetatable => %s", Util.Objects.ToString(getmetatable(entry)))
                if entry.isSent then
                    return nil
                else
                    return entry:UpdateForTransmit()
                end
            end
    )()
    Logging:Trace("GetLootTableForTransmit(POST) : %s", Util.Objects.ToString(ltTransmit))
    return ltTransmit
end

ML.AnnounceItemStrings = {
    ["&s"] = function(ses) return ses end,
    ["&i"] = function(...) return select(2,...) end,
    ["&l"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetLevelText() or "" end,
    ["&t"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetTypeText() or "" end,
    ["&o"] = function(_,_,v) return v.owner and AddOn.Ambiguate(v.owner) or "" end,
}

function ML:AnnounceItems(table)
    -- todo : should we suppress announcements via configuration?
    Logging:Trace("AnnounceItems()")
    AddOn:SendAnnouncement(L["announce_item_text"], AddOn.Constants.group)
    Util.Tables.Iter(table,
            function(v, i)
                local msg = "&s: &i (&t)"
                for text, fn in pairs(self.AnnounceItemStrings) do
                    msg = gsub(msg, text, escapePatternSymbols(tostring(fn(v.session or i, v.link, v))))
                end
                if v.isRoll then
                    msg = _G.ROLL .. ": " .. msg
                end
                AddOn:SendAnnouncement(msg, AddOn.Constants.group)
            end
    )
end

function ML:StartSession()
    Logging:Debug("StartSession()")
    local C = AddOn.Constants

    if not AddOn.candidates[AddOn.playerName] then
        AddOn:Print(L["session_data_sync"])
        Logging:Debug("Session data not yet available")
        return
    end

    -- only sort if we not currently in-flight
    --if not self.running then
    --    self:SortLootTable(self.lootTable)
    --end

    -- if a session is already running, need to add any new items
    if self.running then
        AddOn:SendCommand(C.group, C.Commands.LootTableAdd, self:GetLootTableForTransmit())
    else
        AddOn:SendCommand(C.group, C.Commands.LootTable, self:GetLootTableForTransmit())
    end

    Util.Tables.Call(self.lootTable, function(entry) entry.isSent = true end)

    self.running = true
    self:AnnounceItems(self.lootTable)
    -- todo : do we need to emit help messages here?
end

function ML:EndSession()
    Logging:Debug("EndSession()")
    local C = AddOn.Constants
    self.oldLootTable = self.lootTable
    self.lootTable = {}
    AddOn:SendCommand(C.group, C.Commands.LootSessionEnd)
    self.running = false
    self:CancelAllTimers()
    if AddOn.testMode then
        AddOn:ScheduleTimer("NewMasterLooterCheck", 1)
    end
    AddOn.testMode = false
end

function ML:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)

end

function ML:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)
    local C = AddOn.Constants
    if prefix == C.name then
        local success, command, data = AddOn:Deserialize(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, data=%s", tostring(success), command, Util.Objects.ToString(data))
        -- only ML receives these commands
        if success and AddOn.isMasterLooter then
            if command == C.Commands.PlayerInfo then
                self:AddCandidate(unpack(data))
                self:SendCandidates()
            elseif command == C.Commands.MasterLooterDbRequest then
                AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
            elseif command == C.Commands.CandidatesRequest then
                self:SendCandidates()
            elseif command == C.Commands.Reconnect and AddOn:UnitIsUnit(sender, AddOn.playerName) then
                AddOn:SendCommand(sender, C.Commands.MasterLooterDb, AddOn.mlDb)
                AddOn:ScheduleTimer("SendCommand", 2, sender, C.Commands.Candidates, self.candidates)
                if self.running then
                    AddOn:ScheduleTimer("SendCommand", 4, sender,  C.Commands.LootTable, self:GetLootTableForTransmit())
                end
            elseif command == C.Commands.LootTable and AddOn:UnitIsUnit(sender, AddOn.playerName) then
                self:ScheduleTimer("Timer", 11 + 0.5 * #self.lootTable, "LootSend")
            end
        end
    end
end

function ML:Test(items)
    Logging:Debug("Test(%s)", Util.Tables.Count(items))
    local C = AddOn.Constants

    if not tContains(self.candidates, AddOn.playerName) then
        self:AddCandidate(AddOn.playerName, AddOn.playerClass, AddOn.guildRank)
    end
    AddOn:SendCommand(C.group, C.Commands.Candidates, self.candidates)
    for _, name in ipairs(items) do
        self:AddItem(name)
    end
    AddOn:CallModule("LootSession")
    AddOn:GetModule("LootSession"):Show(self.lootTable)
end

ML.EquipmentLocationSortOrder = {
    "INVTYPE_HEAD",
    "INVTYPE_NECK",
    "INVTYPE_SHOULDER",
    "INVTYPE_CLOAK",
    "INVTYPE_ROBE",
    "INVTYPE_CHEST",
    "INVTYPE_WRIST",
    "INVTYPE_HAND",
    "INVTYPE_WAIST",
    "INVTYPE_LEGS",
    "INVTYPE_FEET",
    "INVTYPE_FINGER",
    "INVTYPE_TRINKET",
    "", -- miscellaneous (tokens, relics, etc.)
    "INVTYPE_RELIC",
    "INVTYPE_QUIVER",
    "INVTYPE_RANGED",
    "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN",
    "INVTYPE_2HWEAPON",
    "INVTYPE_WEAPON",
    "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPONMAINHAND_PET",
    "INVTYPE_WEAPONOFFHAND",
    "INVTYPE_HOLDABLE",
    "INVTYPE_SHIELD",
}
-- invert it with equipment location as index and prev. index as value
ML.EquipmentLocationSortOrder = tInvert(ML.EquipmentLocationSortOrder)
-- add robes at same index as chest
ML.EquipmentLocationSortOrder["INVTYPE_ROBE"] = ML.EquipmentLocationSortOrder["INVTYPE_CHEST"]

function ML:SortLootTable(lootTable)
    table.sort(lootTable, self.LootTableCompare)
end

local function GetItemStatsSum(link)
    local stats = GetItemStats(link)
    local sum = 0
    for _, value in pairs(stats or {}) do
        sum = sum + value
    end
    return sum
end

-- The loot table sort compare function
-- Sorted by:
-- 1. equipment slot: head, neck, ...
-- 2. trinket category name
-- 3. subType: junk(armor token), plate, mail, ...
-- 4. relicType: Arcane, Life, ..
-- 5. Item level from high to low
-- 6. The sum of item stats, to make sure items with bonuses(socket, leech, etc) are sorted first.
-- 7. Item name
--
-- @param a: an entry in the lootTable
-- @param b: The other entry in the looTable
-- @return true if a is sorted before b
function ML.LootTableCompare(a, b)
    if not a.link then return false end
    if not b.link then return true end

    -- todo : add support for item tokens
    local elA = ML.EquipmentLocationSortOrder[a.equipLoc] or math.huge
    local elB = ML.EquipmentLocationSortOrder[b.equipLoc] or math.huge
    if elA ~= elB then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.equipLoc, b.equipLoc, tostring(elA < elB))
        return elA < elB
    end

    -- todo : add support for trinkets
    --if a.equipLoc == "INVTYPE_TRINKET" and b.equipLoc == "INVTYPE_TRINKET" then
    --
    --end

    if a.typeId ~= b.typeId then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.typeId, b.typeId, tostring(a.typeId > b.typeId))
        return a.typeId > b.typeId
    end

    if a.subTypeId ~= b.subTypeId then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.subTypeId, b.subTypeId, tostring(a.subTypeId > b.subTypeId))
        return a.subTypeId > b.subTypeId
    end

    -- todo: add support for relics

    if a.ilvl ~= b.ilvl then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.ilvl, b.ilvl, tostring( a.ilvl > b.ilvl))
        return a.ilvl > b.ilvl
    end

    local statsA = GetItemStatsSum(a.link)
    local statsB = GetItemStatsSum(b.link)
    if statsA ~= statsB then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.link, b.link, tostring(  statsA > statsB))
        return statsA > statsB
    end

    local nameA = ItemUtil:ItemLinkToItemName(a.link)
    local nameB = ItemUtil:ItemLinkToItemName(b.link)
    Logging:Trace("LootTableCompare(%s, %s) : %s", a.link, b.link, tostring(  nameA < nameB))

    return nameA < nameB
end
