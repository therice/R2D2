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
            -- dynamically constructed in the do/end loop below
            -- example data left behind for illustration
            default = {
                --[[
                numButtons = 4,
                { text = L["ms_need"],          whisperKey = L["whisperkey_ms_need"], },
                { text = L["os_greed"],         whisperKey = L["whisperkey_os_greed"], },
                { text = L["minor_upgrade"],    whisperKey = L["whisperkey_minor_upgrade"], },
                { text = L["pvp"],              whisperKey = L["whisperkey_pvp"], },
                --]]
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
                -- dynamically constructed in the do/end loop below
                -- example data left behind for illustration
                --[[
                                    { color = {0,1,0,1},        sort = 1,   text = L["ms_need"], },         [1]
                                    { color = {1,0.5,0,1},	    sort = 2,	text = L["os_greed"], },        [2]
                                    { color = {0,0.7,0.7,1},    sort = 3,	text = L["minor_upgrade"], },   [3]
                                    { color = {1,0.5,0,1},	    sort = 4,	text = L["pvp"], },             [4]
                --]]
            }
        }
    }
}

-- Copy defaults from GearPoints into our defaults for buttons/responses
-- This actually should be done via the AddOn's DB once it's initialized, but we currently
-- don't allow users to change these values (either here or from GearPoints) so we can
-- do it before initialization. If we allow for these to be configured by user, then will
-- need to copy from DB
do
    local DefaultButtons = ML.defaults.profile.buttons.default
    local DefaultResponses = ML.defaults.profile.responses.default
    local GP = AddOn:GetModule("GearPoints")
    local UserVisibleAwards =
        Util(GP.defaults.profile.award_scaling)
                :CopyFilter(function (v) return v.user_visible end, true, nil, true)()

    DefaultButtons.numButtons = Util.Tables.Count(UserVisibleAwards)
    local index = 1
    for award, value in pairs(UserVisibleAwards) do
        Util.Tables.Push(DefaultButtons, {text = L[award], whisperKey = L['whisperkey_' .. award]})
        Util.Tables.Push(DefaultResponses, { color = value.color, sort = index, text = L[award]})
        index = index + 1
    end
end

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), ML.defaults)
    -- Logging:Debug("OnInitialize(%s)", Util.Objects.ToString(ML.defaults, 6))
    --[[
        {profile =
            {responses =
                {default =
                    {
                        NOTINRAID = {color = {0.7, 0.6, 0, 1}, text = Candidate is not in the instance, sort = 803},
                        TIMEOUT = {color = {1, 0, 0, 1}, text = Candidate didn't respond in time, sort = 504},
                        1 = {color = {0, 1, 0.59, 1}, text = Main-Spec (Need), sort = 1},
                        NOTHING = {color = {0.5, 0.5, 0.5, 1}, text = Offline or R2D2 not installed, sort = 505},
                        WAIT = {color = {1, 1, 0, 1}, text = Candidate is selecting response, please wait, sort = 503},
                        ANNOUNCED = {color = {1, 0, 1, 1}, text = Loot announced, waiting for answer, sort = 502},
                        4 = {color = {0.77, 0.12, 0.23, 1}, text = PVP, sort = 4},
                        DISABLED = {color = {0.3, 0.35, 0.5, 1}, text = Candidate has disabled R2D2, sort = 802},
                        PASS = {color = {0.7, 0.7, 0.7, 1}, text = Pass, sort = 800},
                        2 = {color = {1, 0.96, 0.41, 1}, text = Off-Spec (Greed), sort = 2},
                        DEFAULT = {color = {1, 0, 0, 1}, text = Response isn't available. Please upgrade R2D2., sort = 899},
                        3 = {color = {0.96, 0.55, 0.73, 1}, text = Minor Upgrade, sort = 3},
                        NOTANNOUNCED = {color = {1, 0, 1, 1}, text = Not announced, sort = 501},
                        AUTOPASS = {color = {0.7, 0.7, 0.7, 1}, text = Autopass, sort = 801},
                        AWARDED = {color = {1, 1, 1, 1}, text = Awarded, sort = 0.1
                    }
                },
                buttons =
                    {default =
                        {
                            {whisperKey = mainspec, ms, need, 1, text = Main-Spec (Need)},
                            {whisperKey = offspec, os, greed, 2, text = Off-Spec (Greed)},
                            {whisperKey = minorupgrade, minor, 3, text = Minor Upgrade},
                            {whisperKey = pvp, 4, text = PVP}, numButtons = 4}
                        }
                    }
                }
                
    --]]
end

function ML:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- mapping of candidateName = { class, role, rank }
    -- entrie will be of type Candidate.Candidate
    self.candidates = {}
    -- the master looter's loot table (entries will be of type Item.ItemEntry)
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

-- @return the 'db' value at specified path
function ML:GetDbValue(...)
    local path = Util.Strings.Join('.', ...)
    return Util.Tables.Get(self.db.profile, path)
end

-- @return the 'default' value at specified path
function ML:GetDefaultDbValue(...)
    local path = Util.Strings.Join('.', ...)
    return Util.Tables.Get(ML.defaults, path)
end


function ML:BuildDb()
    local db = self.db.profile

    -- iterate through the responses and capture any changes
    local changedResponses = {}
    for type, responses in pairs(db.responses) do
        for i,_ in ipairs(responses) do
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
        buttons     =   changedButtons,
        responses   =   changedResponses,
    }

    --[[
        mlDb = {
            responses = {
                default = {
                }
            },
            buttons = {
                default = {
                    numButtons = 4
                }
            }
        }
    --]]
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
    Util.Tables.Insert(self.candidates, name, Models.Candidate:new(name, class, rank, enchant, lvl, ilvl))
end

function ML:RemoveCandidate(name)
    Logging:Trace("RemoveCandidate(%s)", name)
    Util.Tables.Remove(self.candidates, name)
end

function ML:UpdateCandidates(ask)
    Logging:Trace("UpdateCandidates(%s)", tostring(ask))
    if type(ask) ~= "boolean" then ask = false end

    local C = AddOn.Constants
    -- Util.Tables.Copy(self.candidates, function() return true end)
    local candidates_copy = Util(self.candidates):Copy()()
    local updates = false

    for i = 1, GetNumGroupMembers() do
        --
        -- in classic, combat role will always be NONE (so no need to check against it)
        --
        -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole
        --      = GetRaidRosterInfo(raidIndex)
        local name, _, _, _, _, class, _, _, _, _, _, _  = GetRaidRosterInfo(i)
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
                self:AddCandidate(name, class)
                updates = true
            end
        else
            Logging:Warn("GetRaidRosterInfo() returned nil for index = %s, retrying after a pause", i)
            return self:ScheduleTimer("UpdateCandidates", 1, ask)
        end
    end

    -- these folks no longer around (in raid)
    for n, v in pairs(candidates_copy) do
        if v then
            self:RemoveCandidate(n)
            updates = true
        end
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
    local entry = Models.ItemEntry:new(item, slotIndex, false, owner, false, "default")

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

-- @return ItemEntry for passed session
function ML:GetItem(session)
    return self.lootTable[session]
end

function ML:GetLootTableForTransmit()
    Logging:Trace("GetLootTableForTransmit(PRE) : %s", Util.Objects.ToString(self.lootTable))
    local ltTransmit = Util(self.lootTable)
        :Copy()
        :Map(
            -- update the items as needed
            function(entry)
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

local function AwardFailed(session, winner, status, callback, ...)
    Logging:Debug("AwardFailed : %d,  %s, %s)", session, winner, status)
    AddOn:SendMessage(AddOn.Constants.Messages.AwardFailed, session, winner, status)
    if callback then
        callback(false, session, winner, status, ...)
    end
    return false
end

local function AwardSuccess(session, winner, status, callback, ...)
    Logging:Debug("AwardSuccess : %d,  %s, %s)", session, winner, status)
    AddOn:SendMessage(AddOn.Constants.Messages.AwardSuccess, session, winner, status)
    if callback then
        callback(true, session, winner, status, ...)
    end
    return true
end

local function RegisterAndAnnounceAward(session, winner, response, reason)
    local C, self = Addon.Constants, ML
    local itemEntry = self:GetItem(session)
    local previousWinner = itemEntry.awarded
    itemEntry.awarded = winner
    
    AddOn:SendCommand(C.group, C.Commands.Awarded, session, winner, itemEntry.owner)
    
    self:AnnounceAward(winner, itemEntry.link, reason and reason.text or response,
                       AddOn:LootAllocateModule():GetCandidateData(session, winner, "roll"),
                       session, previousWinner)
    
    if self:HasAllItemsBeenAwarded() then
        AddOn:Print(L["all_items_have_been_awarded"])
        self:ScheduleTimer("EndSession", 1)
    end
    
    return true
end

--@param session the session to award.
--@param winner	Nil/false if items should be stored in inventory and awarded later.
--@param response the candidates response, used for announcement.
--@param reason	entry in awardReasons
--@param callback This function will be called as callback(awarded, session, winner, status, ...)
--@returns true if award is success. false if award is failed. nil if we don't know the result yet.
function ML:Award(session, winner, response, reason, callback, ...)
    Logging:Debug("Award(%s) : %s, %s, %s", tostring(session), tostring(winner), tostring(response), Util.Objects.ToString(reason))
    local args = {...}
    
    if not self.lootTable or #self.lootTable == 0 then
        if self.oldLootTable and #self.oldLootTable > 0 then
            self.lootTable = self.oldLootTable
        else
            Logging:Error("Award() : Neither Loot Table or Old Loot Table populated")
            return false
        end
    end
    
    local itemEntry = self:GetItem(session)
    
    -- if the item has been previously awarded but call specified as not winner, log that and return
    if itemEntry.awarded and not winner then
        AwardFailed(session, nil, "BaggingAwardedItem", callback, ...)
        return false
    end
    
    -- already awarded, change to whom it was awarded
    if itemEntry.awarded then
        RegisterAndAnnounceAward(session, winner, response, reason)
        AwardSuccess(session, winner, "normal", callback, ...)
        return true
    end
    
    
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

ML.AnnounceItemStringsDesc = {
    L["announce_&s_desc"],
    L["announce_&i_desc"],
    L["announce_&l_desc"],
    L["announce_&t_desc"],
    L["announce_&o_desc"],
}

local AnnounceItemString =  "&s: &i (&t)"

function ML:AnnounceItems(table)
    -- todo : should we suppress announcements via configuration?
    Logging:Trace("AnnounceItems()")
    AddOn:SendAnnouncement(L["announce_item_text"], AddOn.Constants.group)
    Util.Tables.Iter(table,
            function(v, i)
                local msg = AnnounceItemString
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

ML.AwardStrings = {
    ["&s"] = function(_, _, _, _, session) return session or "" end,
    ["&p"] = function(name) return AddOn.Ambiguate(name) end,
    ["&i"] = function(...) return select(2, ...) end,
    ["&r"] = function(...) return select(3, ...) or "" end,
    ["&n"] = function(...) return select(4, ...) or "" end,
    ["&l"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetLevelText() or "" end,
    ["&t"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetTypeText() or "" end,
    ["&o"] = function(...)
        local session = select(5, ...)
        local owner = select(6, ...) or ML.lootTable[session] and  ML.lootTable[session].owner
        return owner and AddOn.Ambiguate(owner) or _G.UNKNOWN end,
    ["&m"] = function(...)
        return AddOn:LootAllocateModule():GetCandidateData(select(5,...), select(1,...), "note") or "<none>"
    end,
}

ML.AwardStringsDesc = {
    L["announce_&s_desc"],
    L["announce_&p_desc"],
    L["announce_&i_desc"],
    L["announce_&r_desc"],
    L["announce_&n_desc"],
    L["announce_&l_desc"],
    L["announce_&t_desc"],
    L["announce_&o_desc"],
    L["announce_&m_desc"],
}

local AwardTexts = {
    { channel = "group", text = "&p was awarded with &i for &r"}
}

function ML:AnnounceAward(name, link, response, roll, session, changeAward, owner)
    -- todo : should we suppress announcements via configuration?
    for _, awardText in pairs(AwardTexts) do
        local message = awardText.text
        for text, func in pairs(self.AwardStrings) do
            message = gsub(message, text, escapePatternSymbols(tostring(func(name, link, response, roll, session, owner))))
        end
        if changeAward then
            message = "(" .. L["change_award"] .. ") " .. message
        end
        AddOn:SendAnnouncement(message, awardText.channel)
    end
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

    -- update the loot table to mark entries as having been transmitted
    Util.Tables.Call(self.lootTable, function(entry) entry.isSent = true end)

    self.running = true
    self:AnnounceItems(self.lootTable)
    -- todo : do we need to emit help messages here?
end

function ML:HasAllItemsBeenAwarded()
    local moreItems = true
    for i = 1, #self.lootTable do
        if not self.lootTable[i].awarded then
            moreItems = false
        end
    end
    return moreItems
end

function ML:EndSession()
    Logging:Debug("EndSession()")
    local C = AddOn.Constants
    self.oldLootTable = self.lootTable
    self.lootTable = {}
    AddOn:SendCommand(C.group, C.Commands.LootSessionEnd)
    self.running = false
    self:CancelAllTimers()
    if AddOn:TestModeEnabled()  then
        AddOn:ScheduleTimer("NewMasterLooterCheck", 1)
    end
    AddOn.mode:Disable(AddOn.Constants.Modes.Test)
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
        Logging:Debug("OnCommReceived() : success=%s, command=%s, data=%s", tostring(success), command, Util.Objects.ToString(data, 3))
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
                -- resend the master looter DB
                AddOn:SendCommand(sender, C.Commands.MasterLooterDb, AddOn.mlDb)
                -- resend the candidates
                AddOn:ScheduleTimer("SendCommand", 2, sender, C.Commands.Candidates, self.candidates)
                if self.running then
                    -- resend the loot table
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

-- Award popup control functions
-- data contains: session, winner, responseId, reason, gear1, gear2, isTierRoll, isRelicRoll, link, isToken
function ML.AwardPopupOnShow(frame, data)
    local awardTo =  AddOn.Ambiguate(data.winner)
    local c = AddOn:GetClassColor(data.class)
    frame:SetFrameStrata("FULLSCREEN")
    frame.text:SetText(format(L["confirm_award_item_to_player"], data.link, c:WrapTextInColorCode(awardTo)))
    frame.icon:SetTexture(data.texture)
end

function ML.AwardPopupOnClickYesCallback(awarded, session, winner, status, data, callback, ...)
    Loggin:Debug("AwardPopupOnClickYesCallback(%s, %d, %s)", awarded, session, winner)
    if callback and Util.Objects.IsFunction(callback) then
        callback(awarded, session, winner, status, data, ...)
    end
    if awarded then
        -- todo : remove loot history record if present
        AddOn:LootHistoryModule():AddEntry(
                data.winner,
                data.link,
                data.responseId,
                nil,
                data.reason,
                session,
                data
        )
    end
end

function ML.AwardPopupOnClickYes(frame, data, callback, ...)
    Logging:Debug("AwardPopupOnClickYes() : %s / %s", Util.Objects.ToString(callback), Util.Objects.ToString(data, 3))
    ML:Award(
        data.session,
        data.winner,
        data.responseId and AddOn:GetResponse(data.typeCode or data.equipLoc, data.responseId).text,
        data.reason,
        ML.AwardPopupOnClickYesCallback,
        data,
        callback,
        ...
    )
    -- we need to delay the test mode disabling so comms have a chance to be sent first
    if AddOn:TestModeEnabled() and ML:HasAllItemsBeenAwarded() then ML:EndSession() end
end

function ML.AwardPopupOnClickNo(frame, data)
    -- Intentionally left empty
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
