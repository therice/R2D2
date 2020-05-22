local name, AddOn = ...
local R2D2 = AddOn

local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local Strings = Util.Strings
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local GuildStorage = AddOn.Libs.GuildStorage
local Models = AddOn.components.Models

local Mode = Class('Mode')
AddOn.Mode = Mode

local function bbit(p) return 2 ^ (p - 1) end
local function hasbit(x, p) return x % (p + p) >= p end
local function setbit(x, p) return hasbit(x, p) and x or x + p end
local function clearbit(x, p) return hasbit(x, p) and x - p or x end

    
function Mode:initialize()
    self.bitfield = bbit(AddOn.Constants.Modes.Standard)
end

function Mode:Enable(...)
    for _, p in Util.Objects.Each(...) do
        self.bitfield = setbit(self.bitfield, p)
    end
end

function Mode:Disable(...)
    for _, p in Util.Objects.Each(...) do
        self.bitfield = clearbit(self.bitfield, p)
    end
end

function Mode:Enabled(flag)
    return bit.band(self.bitfield, flag) == flag
end

function Mode:Disabled(flag)
    return bit.band(self.bitfield, flag) == 0
end

function Mode:__tostring()
    return Util.Numbers.BinaryRepr(self.bitfield)
end

function R2D2:OnInitialize()
    --@debug@
    Logging:SetRootThreshold(Logging.Level.Debug)
    --@end-debug@
    Logging:Debug("OnInitialize(%s)", self:GetName())
    -- convert to a semantic version
    self.version = Models.SemanticVersion:new(self.version)
    self.chatCmdHelp = {
        {cmd = "config", desc = L["chat_commands_config"]},
        {cmd = "test", desc = L["chat_commands_test"]},
        {cmd = "version", desc = L["chat_commands_version"]},
        {cmd = "looth", desc = L["chat_commands_looth"]},
        {cmd = "traffich", desc = L["chat_commands_traffich"]},
        {cmd = "standby", desc = L["chat_commands_standby"]},
        -- development intentionally not documented
    }
    -- the player class
    self.playerClass = select(2, UnitClass("player"))
    -- tracks information about player at time of login and when encounters begin
    self.playersData = {
        -- slot number -> item link
        gear = {

        }
    }
    -- our guild (start off as unguilded, will get callback when ready to populate)
    self.guildRank = L["unguilded"]
    -- bitfield which keeps track of our operating mode
    self.mode = Mode:new()
    -- sent by master looter
    self.mlDb = {}
    -- are we the master looter?
    self.isMasterLooter = false
    -- name of the master looter
    self.masterLooter = ""
    -- entries are type Candidate
    self.candidates = {}
    -- should this be a local
    -- entries are type ItemEntry
    self.lootTable = {}
    self.lootStatus = {}
    -- is the Master Looter's loot window open or closed
    self.lootOpen = false
    -- data for items currently in the loot slot(s)
    self.lootSlotInfo = {}
    self.enabled = true
    -- does R2D2 handle loot?
    self.handleLoot = false
    self.reconnectPending = false
    self.instanceName = ""
    self.inCombat = false
    self.encounter = Models.Encounter.None
    -- have we completed our initial version check (for being out of date)
    self.versionCheckComplete = false
    -- core add-on settings
    self.db = self.Libs.AceDB:New('R2D2_DB', R2D2.defaults)
    Logging:SetRootThreshold(self.db.profile.logThreshold)
    self:RegisterChatCommand(name:lower(), "ChatCommand")
    self:RegisterComm(name)
end

function R2D2:OnEnable()
    Logging:Debug("OnEnable(%s) : '%s', '%s'", self:GetName(), UnitName("player"), tostring(self.version))
    
    --@debug@
    -- this enables certain code paths that wouldn't otherwise be available in normal usage
    self.mode:Enable(R2D2.Constants.Modes.Develop)
    -- this enables flag for persistence of points to officer's notes (safety net)
    self.mode:Enable(R2D2.Constants.Modes.Persistence)
    --@end-debug@
    
    self.realmName = select(2, UnitFullName(self.Constants.player))
    self.playerName = self:UnitName(self.Constants.player)
    self.playerFaction = UnitFactionGroup(self.Constants.player)
    
    Logging:Debug("OnEnable(%s) : Faction '%s'", self:GetName(), self.playerFaction)
    
    for name, module in self:IterateModules() do
        Logging:Debug("OnEnable(%s) - Examining module (startup) '%s'", self:GetName(), name)
        
        if module:EnableOnStartup() then
            Logging:Debug("OnEnable(%s) - Enabling module (startup) '%s'", self:GetName(), name)
            module:Enable()
        end
    end
    
    -- register events
    for event, method in pairs(self.Events) do
        self:RegisterEvent(event, method)
    end
    
    if IsInGuild() then
        -- Register with guild storage for state change callback
        GuildStorage.RegisterCallback(
                self,
                GuildStorage.Events.StateChanged,
                function(event, state)
                    Logging:Trace("GuildStorage.Callback(%s, %s)", tostring(event), tostring(state))
                    if state == GuildStorage.States.Current then
                        local me = GuildStorage:GetMember(AddOn.playerName)
                        if me then
                            AddOn.guildRank = me.rank
                            GuildStorage.UnregisterCallback(self, GuildStorage.Events.StateChanged)
                        else
                            AddOn.guildRank = L["not_found"]
                        end
                    end
                end
        )
        
        self:ScheduleTimer("SendGuildVersionCheck", 2)
    end
    
    -- Setup the options for configuration UI
    self.components.Config.SetupOptions()
    self:Print(format(L["chat version"], tostring(self.version)) .. " is now loaded. Thank you for trusting us to handle all your EP/GP needs!")
    
    -- this filters out any responses to whispers related to addon
    local ChatMsgWhisperInformFilter = function(_, event, msg, player, ...)
        return strfind(msg, "[[R2D2]]:")
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMsgWhisperInformFilter)
    
    -- this filters (and captures) relevant messages related to attempting to contact individual players
    local ChatMsgFilter = function(f, event, msg, player, ...)
        if msg:match(string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, "(.+)")) then
            local regex = gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.+)")
            local _, _, character = strfind(msg, regex)
            Logging:Trace("%s - %s", msg, character)
            -- if a player is not found, dispatch the message and let subscribers handle as they see fit
            self:SendMessage(AddOn.Constants.Messages.PlayerNotFound, character)
        end
        
        -- don't muck with workflow here, just return what was passed and let it flow onward
        return false, msg, player, ...
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatMsgFilter)
end

function R2D2:OnDisable()
    self:UnregisterAllEvents()
end

function R2D2:TestModeEnabled()
    return self.mode:Enabled(AddOn.Constants.Modes.Test)
end

function R2D2:DevModeEnabled()
    return self.mode:Enabled(AddOn.Constants.Modes.Develop)
end

function R2D2:PersistenceModeEnabled()
    return self.mode:Enabled(AddOn.Constants.Modes.Persistence)
end

function R2D2:SessionError(...)
    self:Print(L["session_error"])
    Logging:Error(...)
end

-- this is hooked primarily through the Module Prototype (SetDbValue) in Init.lua
-- but can be invoked directly as needed (for instance if you don't use the standard set definition
-- for an option)
function R2D2:ConfigTableChanged(moduleName, val)
    Logging:Debug("ConfigTableChanged('%s') : %s", moduleName, Util.Objects.ToString(val))
    -- need to serialize the values, as AceBucket (if used on other end) only groups by a single value
    self:SendMessage(AddOn.Constants.Messages.ConfigTableChanged, self:Serialize(moduleName, val))
end

function R2D2:Help()
    print(format(L["chat version"], tostring(self.version)))
    for _, v in ipairs(self.chatCmdHelp) do
        print("|cff20a200", v.cmd, "|r:", v.desc)
    end
end

function R2D2:Test(count)
    Logging:Debug("Test(%s)", count)
    local testItems = self:GetTestItems()
    local items = {}
    for _ = 1, count do
        Tables.Push(items, testItems[math.random(1, #testItems)])
    end

    self.mode:Enable(AddOn.Constants.Modes.Test)
    self.isMasterLooter, self.masterLooter = self:GetMasterLooter()

    if not self.isMasterLooter then
        self:Print(L["error_test_as_non_leader"])
        self.mode:Disable(AddOn.Constants.Modes.Test)
        return
    end

    self:CallModule("MasterLooter")
    local ML = self:MasterLooterModule()
    ML:NewMasterLooter(self.masterLooter)
    ML:Test(items)
end

function R2D2:Config()
    if AddOn.Libs.AceConfigDialog.OpenFrames[name] then
        -- todo : hook this into the close button on config frame as well
        local gpm = AddOn:GearPointsCustomModule()
        if gpm.addItemFrame then gpm.addItemFrame:Hide() end
        AddOn.Libs.AceConfigDialog:Close(name)
    else
        AddOn.Libs.AceConfigDialog:Open(name)
    end
end

function R2D2:Version(showOutOfDateClients)
    if showOutOfDateClients then
        self:VersionCheckModule():PrintOutOfDateClients()
    else
        self:CallModule('VersionCheck')
    end
end

function R2D2:ChatCommand(msg)
    local args = Tables.New(self:GetArgs(msg,10))
    args[11] = nil
    local cmd = Strings.Lower(tremove(args, 1)):trim()
    Logging:Trace("ChatCommand(%s) -> %s", cmd, strjoin(' ', unpack(args)))

    if Strings.IsEmpty(cmd) or cmd == "help" then
        self:Help()
    elseif cmd == 'config' or cmd == "c" then
        self:Config()
    elseif cmd == 'looth' or cmd == 'lh' then
        self:CallModule("LootHistory")
    elseif cmd == 'traffich' or cmd == 'th' then
        self:CallModule("TrafficHistory")
    elseif cmd == 'test' or cmd == "t" then
        self:Test(tonumber(args[1]) or 1)
    elseif cmd == 'version' or cmd == "v" or cmd == "ver" then
        self:Version(args[1])
    elseif cmd == 'standby' or cmd == "bench"then
        self:CallModule("Standby")
    elseif cmd == 'dev' then
        local flag = R2D2.Constants.Modes.Develop
        if self.mode:Enabled(flag) then
            self.mode:Disable(flag)
        else
            self.mode:Enable(flag)
        end
        self:Print("Development Mode = " .. tostring(self:DevModeEnabled()))
    -- 'pm' == persitence mode (which coresponds to persisting changes to officer's notes for EPGP)
    elseif cmd == 'pm' then
        local flag = R2D2.Constants.Modes.Persistence
        if self.mode:Enabled(flag) then
            self.mode:Disable(flag)
        else
            self.mode:Enable(flag)
        end
        self:Print("Persistence Mode = " .. tostring(self:PersistenceModeEnabled()))
    else
        self:Help()
    end
end
