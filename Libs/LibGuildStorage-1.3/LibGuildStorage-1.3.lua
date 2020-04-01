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
    StateChanged        =   "StateChanged",
    GuildInfoChanged    =   "GuildInfoChanged",
    GuildNoteChanged    =   "GuildNoteChanged",
    GuildNoteConflict   =   "GuildNoteConflict",
    GuildMemberDeleted  =   "GuildMemberDeleted",
}

local state, initialized, index, cache, guildInfo, guildFrameVisible, realmName =
    States.StaleAwaitingUpdate, false, nil, {}, nil, false, select(2, UnitFullName("player"))


local GuildMember = Class('GuildMember')

function GuildMember:initialize(name, rank, rankIndex, class, note)
    self.name           = name
    self.rank           = rank
    self.rankIndex      = rankIndex
    self.class          = class
    self.note           = note
    self.pendingNote    = nil
    self.seen           = nil
end

function GuildMember:HasPendingNote()
    return self.pendingNote ~= nil
end

function SetState(value)
    if state == value then return end
    
    if not StateTransitions[state][value] then
        Logging:Debug("Ignoring state change from '%s' to '%s'", StateNames[state], StateNames[value])
        return
    else
        Logging:Debug("State change from '%s' to '%s'", StateNames[state], StateNames[value])
        state = value
        if value == States.PendingChanges then
            SendAddonMessage(MAJOR_VERSION, Messages.ChangesPending, "GUILD")
        end
        lib.callbacks:Fire(lib.Events.StateChanged, state)
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

function lib:GetNote(name)
    return self:GetMemberAttribute(name, 'note')
end

function lib:SetNote(name, note)
    local entry = self:GetMember(name)
    if entry then
        if entry:HasPendingNote() then
            DEFAULT_CHAT_FRAME:AddMessage(
                    format(MAJOR_VERSION .. " : ignoring attempt to set note before persisting pending note for %s", name)
            )
        else
            entry.pendingNote = note
            SetState(States.PendingChanges)
        end
        
        return entry.note
    end
end

function lib:GetClass(name)
    return self:GetMemberAttribute(name, 'class')
end

function lib:GetRank(name)
    local entry = self:GetMember(name)
    if entry then return entry.rank, entry.rankIndex end
end

lib.frame:RegisterEvent("CHAT_MSG_ADDON")
lib.frame:RegisterEvent("PLAYER_GUILD_UPDATE")
lib.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
lib.frame:RegisterEvent("GUILD_ROSTER_UPDATE")

function lib:CHAT_MSG_ADDON(prefix, msg, type, sender)
    -- only look at messages from this library and ignore ones from yourself
    if prefix ~= MAJOR_VERSION or sender == UnitName("player") then return end
    Logging:Debug("CHAT_MSG_ADDON: %s, %s, %s, %s", prefix, msg, type, sender)
    
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
            lib.callbacks:Fire(lib.Events.GuildInfoChanged)
        end
    end
    
    local lastIndex = math.min(index + 100, guildMemberCount)
    if not initialized then lastIndex = guildMemberCount end
    Logging:Trace("Processing guild members from %d to %s", index, lastIndex)
    
    for i = index, lastIndex do
        local name, rank, rankIndex, _, _, _, _, note, _, _, class = GetGuildRosterInfo(i)
        -- The Rank Index starts at 0, add 1 to correspond with the index
        -- for usage in GuildControlGetRankName(index)
        rankIndex = rankIndex + 1
    
        if name then
            local entry = lib:GetMember(name)
            if not entry then
                --(name, rank, rankIndex, class, note)
                entry = GuildMember:new(name, rank, rankIndex, class, note)
                cache[name] = entry
            else
                entry.rank = rank
                entry.rankIndex = rankIndex
                entry.class = class
            end
            entry.seen = true
    
            if entry.note ~= note then
                entry.note = note
                if initialized then
                    lib.callbacks:Fire(lib.Events.GuildNoteChanged, name, note)
                end
                if entry:HasPendingNote() then
                    lib.callbacks:Fire(lib.Events.GuildNoteConflict, name, note, entry.note, entry.pendingNote)
                end
            end
    
            if entry:HasPendingNote() then
                -- todo : uncomment when ready
                -- GuildRosterSetOfficerNote(i, entry.pendingNote)
                entry.pendingNote = nil
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
                lib.callbacks:Fire(lib.Events.GuildMemberDeleted, name)
            end
        end
    
        if not initialized then
            for name, entry in pairs(cache) do
                lib.callbacks:Fire(lib.Events.GuildNoteChanged, name, entry.note)
            end
            initialized = true
            lib.callbacks:Fire(lib.Events.StateChanged)
        end
    
        if state == States.Stale then
            SetState(States.Current)
        elseif state == States.ChangesPending then
            local pendingCount = Util.Tables.CountFn(cache,
                function(entry)
                   if entry.pendingNote then return 1 else return 0 end
                end
            )
    
            if pendingCount == 0 then
                SetState(States.StaleAwaitingUpdate)
                SendAddonMessage(MAJOR_VERSION, Messages.ChangesWritten, "GUILD")
            end
        end
    end
    
    Logging:Debug("OnUpdate() : %d guild members, %d ms elapsed", Util.Tables.Count(cache), debugprofilestop() - start)
end

lib.frame:SetScript("OnUpdate", OnUpdate)
GuildRoster()