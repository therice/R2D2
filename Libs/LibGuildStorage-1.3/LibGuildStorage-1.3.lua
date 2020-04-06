local MAJOR_VERSION = "LibGuildStorage-1.3"
local MINOR_VERSION = 11303

local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

C_ChatInfo.RegisterAddonMessagePrefix(MAJOR_VERSION)

local Logging       = LibStub("LibLogging-1.0")
local Class         = LibStub("LibClass-1.0")
local Util          = LibStub("LibUtil-1.1")
local Cbh           = LibStub("CallbackHandler-1.0")
local AceHook       = LibStub("AceHook-3.0")

if not lib.callbacks then
    lib.callbacks = Cbh:New(lib)
end

local callbacks = lib.callbacks

AceHook:Embed(lib)
lib:UnhookAll()

if lib.frame then
    lib.frame:UnregisterAllEvents()
    lib.frame:SetScript("OnEvent", nil)
    lib.frame:SetScript("OnUpdate", nil)
else
    lib.frame = CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
end

lib.frame:Show()
lib.frame:SetScript(
        "OnEvent",
        function(self, event, ...)
            lib[event](lib, ...)
        end
)

local SendAddonMessage = _G.SendAddonMessage
if ChatThrottleLib then
    SendAddonMessage = function(...)
        ChatThrottleLib:SendAddonMessage("ALERT", MessagePrefix, ...)
    end
end

local States = {
    Stale                   =   1,
    StaleAwaitingUpdate     =   2,
    Current                 =   3,
    PendingChanges          =   4,
    PersistingChanges       =   5,
}
lib.States = States

local StateNames = tInvert(States)

local StateTransitions = {
    [States.Stale]                  = { States.Current, States.PersistingChanges, States.StaleAwaitingUpdate },
    [States.StaleAwaitingUpdate]    = { States.Stale, States.PendingChanges },
    [States.Current]                = { States.PendingChanges, States.PersistingChanges, States.Stale },
    [States.PendingChanges]         = { States.StaleAwaitingUpdate },
    [States.PersistingChanges]      = { States.StaleAwaitingUpdate },
}

local Messages = {
    ChangesPending  = "ChangesPending",
    ChangesWritten  = "ChangesWritten",
}

lib.Events = {
    Initialized              =   "Initialized",
    StateChanged             =   "StateChanged",
    GuildInfoChanged         =   "GuildInfoChanged",
    GuildOfficerNoteChanged  =   "GuildNoteChanged",
    GuildOfficerNoteConflict =   "GuildNoteConflict",
    GuildMemberDeleted       =   "GuildMemberDeleted",
}

local state, initialized, index, cache, guildInfo =
    States.StaleAwaitingUpdate, false, nil, {}, nil


local GuildStorageEntry = Class('GuildStorageEntry')

--  name, rank, rankIndex, _, class, _, _, officerNote, _, _, classTag
-- class : String - The class (Mage, Warrior, etc) of the player.
-- classTag : String - Upper-case English classname - localisation independant.
-- rank : String - The member's rank in the guild ( Guild Master, Member ...)
-- rankIndex : Number - The number corresponding to the guild's rank (already with 1 added to API return value)
function GuildStorageEntry:initialize(name, class, classTag, rank, rankIndex, officerNote)
    self.name = name
    self.class = class
    self.classTag = classTag
    self.rank = rank
    self.rankIndex = rankIndex
    self.officerNote = officerNote
    self.pendingOfficerNote = nil
    self.seen = nil
end

function GuildStorageEntry:HasPendingOfficerNote()
    return self.pendingOfficerNote ~= nil
end


function SetState(value)
    if state == value then return end
    
    if not StateTransitions[state][value] then
        Logging:Trace("Ignoring state change from '%s' to '%s'", StateNames[state], StateNames[value])
        return
    else
        Logging:Trace("State change from '%s' to '%s'", StateNames[state], StateNames[value])
        state = value
        if value == States.PendingChanges then
            SendAddonMessage(MAJOR_VERSION, Messages.ChangesPending, "GUILD")
        end
        callbacks:Fire(lib.Events.StateChanged, state)
    end
end

function lib:IsStateCurrent()
    return state == States.Current
end

function lib:GetMember(name)
    return cache[name]
end

function lib:GetMemberAttribute(name, attr)
    local entry = self:GetMember(name)
    if entry and entry[attr] then return entry[attr] end
end

function lib:GetOfficerNote(name)
    return self:GetMemberAttribute(name, 'officerNote')
end

function lib:SetOfficeNote(name, note)
    local entry = self:GetMember(name)
    if entry then
        if entry:HasPendingOfficerNote() then
            DEFAULT_CHAT_FRAME:AddMessage(
                    format(MAJOR_VERSION .. " : ignoring attempt to set officer note before persisting pending officer note for %s", name)
            )
        else
            entry.pendingOfficerNote = note
            SetState(States.PendingChanges)
        end
        
        return entry.pendingOfficerNote
    end
end

function lib:GetClass(name)
    return self:GetMemberAttribute(name, 'class')
end

function lib:GetClassTag(name)
    return self:GetMemberAttribute(name, 'classTag')
end

-- @return member's rank and rankIndex
function lib:GetRank(name)
    local entry = self:GetMember(name)
    if entry then return entry.rank, entry.rankIndex end
end

lib.frame:RegisterEvent("CHAT_MSG_ADDON")
-- https://wow.gamepedia.com/PLAYER_GUILD_UPDATE
lib.frame:RegisterEvent("PLAYER_GUILD_UPDATE")
lib.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- https://wow.gamepedia.com/GUILD_ROSTER_UPDATE
lib.frame:RegisterEvent("GUILD_ROSTER_UPDATE")

function lib:CHAT_MSG_ADDON(prefix, msg, type, sender)
    -- only look at messages from this library and ignore ones from yourself
    if prefix ~= MAJOR_VERSION or sender == UnitName("player") then return end
    Logging:Trace("CHAT_MSG_ADDON: %s, %s, %s, %s", prefix, msg, type, sender)
    
    if msg == Messages.ChangesPending then
        SetState(States.PersistingChanges)
    elseif msg == Messages.ChangesWritten then
        SetState(States.StaleAwaitingUpdate)
    end
end

function lib:PLAYER_GUILD_UPDATE()
    if IsInGuild() then
        lib.frame:Show()
    else
        lib.frame:Hide()
    end
    SetState(States.StaleAwaitingUpdate)
end

function lib:PLAYER_ENTERING_WORLD()
    lib:PLAYER_GUILD_UPDATE()
end

function lib:GUILD_ROSTER_UPDATE(canRequestRosterUpdate)
    Logging:Trace("GUILD_ROSTER_UPDATE(%s)", tostring(canRequestRosterUpdate))
    if canRequestRosterUpdate then
        SetState(States.PendingChanges)
    else
        SetState(States.Stale)
        index = nil
    end
end

local function OnUpdate()
    local start = debugprofilestop()
    
    if state == States.Current then return end
    
    if state == States.StaleAwaitingUpdate then
        GuildRoster()
        return
    end
    
    local guildMemberCount = GetNumGuildMembers()
    if guildMemberCount == 0 then return end
    if not index or index >= guildMemberCount then index = 1 end
    
    if index == 1 then
        local newGuildInfo = GetGuildInfoText() or ""
        if newGuildInfo ~= guildInfo then
            guildInfo = newGuildInfo
            callbacks:Fire(lib.Events.GuildInfoChanged)
        end
    end
    
    Logging:Trace("Current index = %d, Guild Member Count = %d", index and index or -1, guildMemberCount)
    local lastIndex = math.min(index + 100, guildMemberCount)
    if not initialized then lastIndex = guildMemberCount end
    Logging:Trace("Processing guild members from %d to %s", index, lastIndex)
    
    for i = index, lastIndex do
        local name, rank, rankIndex, _, class, _, _, officerNote, _, _, classTag = GetGuildRosterInfo(i)
        -- The Rank Index starts at 0, add 1 to correspond with the index
        -- for usage in GuildControlGetRankName(index)
        rankIndex = rankIndex + 1
    
        if name then
            local entry = lib:GetMember(name)
            -- Logging:Debug("BEFORE(%s) = %s", name, Util.Objects.ToString(entry))
            
            if not entry then
                entry = GuildStorageEntry(name, class, classTag, rank, rankIndex, officerNote)
                cache[name] = entry
            else
                entry.rank = rank
                entry.rankIndex = rankIndex
                entry.class = class
                entry.classTag = classTag
            end
            entry.seen = true
    
            -- Logging:Debug("AFTER(%s) = %s", name, Util.Objects.ToString(entry))
            
            if entry.officerNote ~= officerNote then
                entry.officerNote = officerNote
                if initialized then
                    callbacks:Fire(lib.Events.GuildOfficerNoteChanged, name, officerNote)
                end
                if entry:HasPendingOfficerNote() then
                    callbacks:Fire(lib.Events.GuildOfficerNoteConflict, name, officerNote, entry.officerNote, entry.pendingOfficerNote)
                end
            end
    
            if entry:HasPendingOfficerNote() then
                -- todo : uncomment when ready
                -- GuildRosterSetOfficerNote(i, entry.pendingOfficerNote)
                entry.pendingOfficerNote = nil
            end
        end
    end
    
    index = lastIndex
    if index >= guildMemberCount then
        for name, entry in pairs(cache) do
            if entry.seen then
                entry.seen = nil
            else
                cache[name] = nil
                callbacks:Fire(lib.Events.GuildMemberDeleted, name)
            end
        end
    
        if not initialized then
            for name, entry in pairs(cache) do
                callbacks:Fire(lib.Events.GuildOfficerNoteChanged, name, entry.officerNote)
            end
            initialized = true
            callbacks:Fire(lib.Events.Initialized)
        end
    
        if state == States.Stale then
            SetState(States.Current)
        elseif state == States.ChangesPending then
            local pendingCount = Util.Tables.CountFn(cache,
                function(entry)
                   if entry.pendingOfficerNote then return 1 else return 0 end
                end
            )
    
            if pendingCount == 0 then
                SetState(States.StaleAwaitingUpdate)
                SendAddonMessage(MAJOR_VERSION, Messages.ChangesWritten, "GUILD")
            end
        end
    end
    
    Logging:Trace("OnUpdate() : %d guild members, %d ms elapsed, current index %d", Util.Tables.Count(cache), debugprofilestop() - start, index and index or -1)
end

lib.frame:SetScript("OnUpdate", OnUpdate)
GuildRoster()