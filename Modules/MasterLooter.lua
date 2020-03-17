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
                { color = {0,1,0,1},        sort = 1,   text = L["ms_need"], },
                { color = {1,0.5,0,1},	    sort = 2,	text = L["os_greed"], },
                { color = {0,0.7,0.7,1},    sort = 3,	text = L["minor_upgrade"], },
                { color = {1,0.5,0,1},	    sort = 4,	text = L["pvp"], },
            }
        }
    }
}

-- local addOnDb = AddOn.db

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), ML.defaults)
end

function ML:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- candidateName = { class, role, rank }
    self.candidates = {}
    -- the master looter's loot table
    self.lootTable = {}
    -- items master looter has attempted to give out waiting for LOOT_SLOT_CLEARED
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

function ML:BuildDb()
    local db = self.db.profile

    -- iterate through the responses and capture any changes
    local changedResponses = {}
    for type, responses in pairs(db.responses) do
        for i in ipairs(responses) do
            -- don't capture more than number of buttons
            if i > db.buttons[type].numButtons then break end
            -- look at type, text and color
            if not ML.defaults.profile.responses[type]
                or db.responses[type][i].text ~= ML.defaults.profile.responses[type][i].text
                or unpack(db.responses[type][i].color) ~= unpack(ML.defaults.profile.responses[type][i].color) then
                if not changedResponses[type] then changedResponses[type] = {} end
                changedResponses[type][i] = db.responses[type][i]
            end
        end
    end
    -- iterate through the buttons and capture any changes
    local changedButtons = {default = {}}
    for type, buttons in pairs(db.buttons) do
        for i in ipairs(buttons) do
            -- don't capture more than number of buttons
            if i > db.buttons[type].numButtons then break end
            -- look a type and text
            if not ML.defaults.profile.buttons[type]
                or db.buttons[type][i].text ~= ML.defaults.profile.buttons[type][i].text then
                if not changedButtons[type] then changedButtons[type] = {} end
                changedButtons[type][i] = {text = db.buttons[type][i].text}
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
    Logging:Debug("UpdateDb()")
    local C = AddOn.Constants
    AddOn:OnMasterLooterDbReceived(self:BuildDb())
    AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
end

function ML:AddCandidate(name, class, role, rank, enchant, lvl, ilvl)
    Logging:Debug("AddCandidate(%s, %s, %s, %s, %s, %s, %s)", name, class, role, rank, tostring(enchant), tostring(lvl or 'nil'), tostring(ilvl or 'nil'))
    Util.Tables.Insert(self.candidates, name, {
            ["class"] = class,
            ["role"] = role,
            ["rank"] = rank or "",
            ["enchanter"] = enchant,
            ["enchant_lvl"] = lvl,
            ["item_lvl"] = ilvl,
        }
    )
end

function ML:RemoveCandidate(name)
    Logging:Debug("RemoveCandidate(%s)", name)
    Util.Tables.Remove(self.candidates, name)
end

function ML:UpdateCandidates(ask)
    Logging:Debug("UpdateCandidates(%s)", tostring(ask))
    if type(ask) ~= "boolean" then ask = false end

    local C = AddOn.Constants
    local candidates_copy = Util.Tables.Copy(self.candidates, function() return true end)
    local updates = false

    for i = 1, GetNumGroupMembers() do
        --
        -- in classic, combat role will always be NONE (so no need to check against it
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
    for name, _ in pairs(candidates_copy) do
        self:RemoveCandidate(name)
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

function ML:GetItemInfo(item)
    -- https://wow.gamepedia.com/API_GetItemInfo
    local name, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(item)
    local itemId = link and ItemUtil:ItemLinkToId(link)
    if name then
        local customItem = ItemUtil:GetCustomItem(itemId)
        return Models.Item:New(
                itemId,
                link,
                (customItem and customItem[1]) or rarity,
                (customItem and customItem[2]) or ilvl,
                type,
                (customItem and customItem[3]) or equipLoc,
                subType,
                texture,
                typeId,
                subTypeId,
                bindType,
                ItemUtil:GetItemClassesAllowedFlag(link)
        )
    else
        return nil
    end
end

--- adds an item to ht loo table
-- @param Any: ItemID|itemString|itemLink
-- @param slotIndex index of the loot slot
-- @param owner the owner of the item (if any). Defaults to 'BossName'
-- @param  entry used to set data in a specific lootTable entry
function ML:AddItem(item, slotIndex, owner, entry)
    Logging:Debug("AddItem(%s)", item)

    if not entry then
        entry = {}
        Util.Tables.Push(self.lootTable, entry)
    else
        Util.Tables.Wipe(entry)
    end

    local itemInfo = self:GetItemInfo(item)
    -- or bossName (for owner)
    Models.ItemEntry:Populate(entry, itemInfo, slotIndex, owner, false, false)

    if not itemInfo then
        self:ScheduleTimer("AddItem", 0, item, slotIndex, owner, entry)
        Logging:Debug("AddItem() : Started timer %s for %s", "AddItem", item)
    else
        AddOn:SendMessage(AddOn.Constants.Messages.MasterLooterAddItem, item, entry)
    end
end

function ML:RemoveItem(session)
    Util.Tables.Remove(self.lootTable, session)
end

function ML:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)
end

function ML:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Debug("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)
    local C = AddOn.Constants
    if prefix == C.name then
        local test, command, data = AddOn:Deserialize(serializedMsg)
        -- only ML receives these commands
        if test and AddOn.isMasterLooter then
            if command == C.Commands.PlayerInfo then
                self:AddCandidate(unpack(data))
                self:SendCandidates()
            --elseif command == C.Commands.
            end
        end
    end
end

function ML:Test(items)
    Logging:Debug("Test(%s)", Util.Tables.Count(items))
    local C = AddOn.Constants

    if not tContains(self.candidates, AddOn.playerName) then
        self:AddCandidate(AddOn.playerName, AddOn.playerClass, "NONE", AddOn.guildRank)
    end
    AddOn:SendCommand(C.group, C.Commands.Candidates, self.candidates)
    for _, name in ipairs(items) do
        self:AddItem(name)
    end
    AddOn:CallModule("LootSession")
    AddOn:GetModule("LootSession"):Show(self.lootTable)
end