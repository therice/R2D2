-- name : The name of your addon as set in the TOC and folder name
-- name : The shared addon table between the Lua files of an addon
local name, namespace = ...
local G = _G
-- are we in test mode
local _TEST = G.R2D2_Testing

local AceAddon = LibStub('AceAddon-3.0')
R2D2 = AceAddon:NewAddon(namespace, name, 'AceConsole-3.0')
R2D2:SetDefaultModuleState(false)

-- Shim for determining locale for localization
do
    local locale = GetLocale()
    local convert = {enGB = 'enUS'}
    local gameLocale = convert[locale] or locale or 'enUS'

    function R2D2:GetLocale()
        return gameLocale
    end
end

namespace.components = {}
namespace.components.Logging    = LibStub("LibLogging-1.0")
namespace.components.Locale     = LibStub('AceLocale-3.0'):GetLocale("R2D2")

local L = namespace.components.Locale
local logging = namespace.components.Logging

-- If in test mode, configure logging appropriately for output
if _TEST then
    logging:SetRootThreshold(logging.Level.Trace)
    logging:SetWriter(
        function(msg)
            G.R2D2_Testing_GetLogFile():write(msg, '\n')
        end
    )

    _G.print = function(...)
        G.R2D2_Testing_GetLogFile():write(...)
        G.R2D2_Testing_GetLogFile():write('\n')
    end
end

function R2D2:OnInitialize()
    logging:Trace("OnInitialize() - initializing...")
    self.version = GetAddOnMetadata(name, "Version")
    self.db = LibStub('AceDB-3.0'):New('R2D2_DB')
    self.chatCmdHelp = {
        {cmd = "config", desc = L["chat_commands_config"]},
        {cmd = "version", desc = L["chat_commands_version"]},
    }

    -- setup chat hooks
    self:RegisterChatCommand("r2d2", "ChatCommand")
    logging:Trace("OnInitialize() - complete")
end

function R2D2:OnEnable()
    logging:Trace("OnEnable('%s', '%s')", UnitName("player"), self.version)
    for name, module in self:IterateModules() do
        if not module.db or module.db.profile.enabled or not module.defaults then
            logging:Trace("OnEnable() - Enabling module (startup) '%s'", name)
            module:Enable()
        end
    end
end

-- move to utility
local function isempty(s)
    return s == nil or s == ''
end

function R2D2:ChatCommand(msg)
    local input = self:GetArgs(msg,1)
    local args = {}
    local arg, startpos = nil, input and #input + 1 or 0

    repeat
        arg, startpos = self:GetArgs(msg, 1, startpos)
        if arg then
            table.insert(args, arg)
        end
    until arg == nil
    input = strlower(input or ""):trim()
    logging:Trace("ChatCommand(%s) -> %s", input, strjoin(' ', unpack(args)))

    if isempty(input) or input == "help" then
        print(format(L["chat version"],self.version))
        for _, v in ipairs(self.chatCmdHelp) do
            print("|cff20a200", v.cmd, "|r:", v.desc)
        end
    elseif input == 'config' or input == "c" then
        -- todo : open configuration
    elseif input == 'version' or input == "v" or input == "ver" then
        -- todo : open version checker
    else
        self:ChatCommand("help")
    end
end