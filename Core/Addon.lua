local name, AddOn = ...
local R2D2 = AddOn

local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Strings   = Util.Strings
local Tables    = Util.Tables

R2D2.defaults = {
    profile = {
        logThreshold = Logging.Level.Debug,
    }
}


function R2D2:OnInitialize()
    Logging:SetRootThreshold(Logging.Level.Debug)
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.chatCmdHelp = {
        {
            cmd = "config",
            desc = L["chat_commands_config"]
        },
        {
            cmd = "version",
            desc = L["chat_commands_version"]
        },
    }
    self.db = self.Libs.AceDB:New('R2D2_DB', R2D2.defaults)
    Logging:SetRootThreshold(self.db.profile.logThreshold)
    self:RegisterChatCommand(name:lower(), "HandleChatCommand")
end

function R2D2:OnEnable()
    Logging:Debug("OnEnable(%s) : '%s', '%s'", self:GetName(), UnitName("player"), self.version)
    for name, module in self:IterateModules() do
        if not module.db or module.db.profile.enabled or not module.defaults then
            Logging:Debug("OnEnable(%s) - Enabling module (startup) '%s'", self:GetName(), name)
            module:Enable()
        end
    end

    -- Setup the options for configuration UI
    self.components.Config.SetupOptions()
end

function R2D2:Help()
    print(format(L["chat version"],self.version))
    for _, v in ipairs(self.chatCmdHelp) do
        print("|cff20a200", v.cmd, "|r:", v.desc)
    end
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

function R2D2:HandleChatCommand(msg)
    local args = Tables.New(self:GetArgs(msg,10))
    args[11] = nil
    local cmd = Strings.Lower(tremove(args, 1)):trim()
    Logging:Trace("ChatCommand(%s) -> %s", cmd, strjoin(' ', unpack(args)))

    if Strings.IsEmpty(cmd) or cmd == "help" then
        self:Help()
    elseif cmd == 'config' or cmd == "c" then
        self:Config()
    elseif cmd == 'version' or cmd == "v" or cmd == "ver" then
        self:Version()
    else
        self:Help()
    end
end