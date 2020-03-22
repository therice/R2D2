local name, AddOn = ...
local R2D2 = AddOn

local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Strings   = Util.Strings
local Tables    = Util.Tables

function R2D2:OnInitialize()
    Logging:SetRootThreshold(Logging.Level.Debug)
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.chatCmdHelp = {
        {cmd = "config", desc = L["chat_commands_config"]},
        {cmd = "test", desc = L["chat_commands_test"]},
        {cmd = "version", desc = L["chat_commands_version"]},
    }
    -- the player class
    self.playerClass = select(2, UnitClass("player"))
    -- our guild
    self.guildRank = L["unguilded"]
    -- are we running in test mode
    self.testMode = false
    -- sent by master looter
    self.mlDb = {}
    -- are we the master looter?
    self.isMasterLooter = false
    -- name of the master looter
    self.masterLooter = ""
    -- should this be a local
    self.lootTable = {}
    self.enabled = true
    -- does R2D2 handle loot?
    self.handleLoot = false
    self.db = self.Libs.AceDB:New('R2D2_DB', R2D2.defaults)
    Logging:SetRootThreshold(self.db.profile.logThreshold)
    self:RegisterChatCommand(name:lower(), "ChatCommand")
    self:RegisterComm(name)
end

function R2D2:OnEnable()
    Logging:Debug("OnEnable(%s) : '%s', '%s'", self:GetName(), UnitName("player"), self.version)
    for name, module in self:IterateModules() do
        if not module.db or module.db.profile.enabled or not module.defaults then
            Logging:Debug("OnEnable(%s) - Enabling module (startup) '%s'", self:GetName(), name)
            module:Enable()
        end
    end

    self.realmName = select(2, UnitFullName(self.Constants.player))
    self.playerName = self:UnitName(self.Constants.player)

    if IsInGuild() then
        self.guildRank = select(2, GetGuildInfo("player"))
    end

    -- Setup the options for configuration UI
    self.components.Config.SetupOptions()
end

function R2D2:CallModule(module)
    self:EnableModule(module)
end

function R2D2:Help()
    print(format(L["chat version"],self.version))
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

    self.testMode = true
    self.isMasterLooter, self.masterLooter = self:GetMasterLooter()

    if not self.isMasterLooter then
        self:Print(L["error_test_as_non_leader"])
        self.testMode = false
        return
    end

    self:CallModule("MasterLooter")
    local ML = self:MasterLooterModule()
    ML:NewMasterLooter(self.masterLooter)
    ML:Test(items)
end

function R2D2:Config()
    if AddOn.Libs.AceConfigDialog.OpenFrames[name] then
        AddOn.Libs.AceConfigDialog:Close(name)
    else
        AddOn.Libs.AceConfigDialog:Open(name)
    end
end

function R2D2:Version()

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
    elseif cmd == 'test' or cmd == "t" then
        self:Test(tonumber(args[1]) or 1)
    elseif cmd == 'version' or cmd == "v" or cmd == "ver" then
        self:Version()
    else
        self:Help()
    end
end
