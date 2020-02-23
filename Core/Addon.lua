local name, namespace = ...
local R2D2 = namespace
local G = _G

local L         = namespace.components.Locale
local logging   = namespace.components.Logging
local Util      = namespace.components.Util
local Strings   = Util.Strings
local Tables    = Util.Tables

function R2D2:OnInitialize()
    logging:SetRootThreshold(logging.Level.Trace)
    logging:Debug("OnInitialize(%s)", self:GetName())
    self.version = GetAddOnMetadata(name, "Version")
    self.chatCmdHelp = {
        {cmd = "config", desc = L["chat_commands_config"]},
        {cmd = "version", desc = L["chat_commands_version"]},
    }
    self.db = LibStub('AceDB-3.0'):New('R2D2_DB')
    -- setup chat hooks
    self:RegisterChatCommand(name:lower(), "HandleChatCommand")
end

function R2D2:OnEnable()
    logging:Debug("OnEnable(%s) : '%s', '%s'", self:GetName(), UnitName("player"), self.version)
    for name, module in self:IterateModules() do
        if not module.db or module.db.profile.enabled or not module.defaults then
            logging:Debug("OnEnable(%s) - Enabling module (startup) '%s'", self:GetName(), name)
            module:Enable()
        end
    end
end

function R2D2:Help()
    print(format(L["chat version"],self.version))
    for _, v in ipairs(self.chatCmdHelp) do
        print("|cff20a200", v.cmd, "|r:", v.desc)
    end
end

function R2D2:Config()

end

function R2D2:Version()

end

function R2D2:HandleChatCommand(msg)
    local args = Tables.New(self:GetArgs(msg,10))
    args[11] = nil
    local cmd = Strings.Lower(tremove(args, 1)):trim()
    logging:Trace("ChatCommand(%s) -> %s", cmd, strjoin(' ', unpack(args)))

    if Strings.IsEmpty(cmd) or cmd == "help" then
        self:Help()
    elseif input == 'config' or input == "c" then
        self:Config()
    elseif input == 'version' or input == "v" or input == "ver" then
        self:Version()
    else
        self:Help()
    end
end