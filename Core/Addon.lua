local name, namespace = ...
local R2D2 = namespace
local G = _G
local _TEST = G.R2D2_Testing

local L         = namespace.components.Locale
local logging   = namespace.components.Logging

function R2D2:SetupLogging()
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
    -- otherwise, create a frame where we write the output
    else
        local loggingUI = self:GetModule("LoggingUI")
        logging:SetRootThreshold(logging.Level.Trace)


        --local f = UI("Frame")
        --        .SetTitle("R2D2 Logging")
        --        .SetStatusText("Mouse wheel to scroll. Title bar drags. Bottom-right corner re-sizes.")
        --        .SetLayout("Fill")
        --        .SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", 0, 0)()
        --
        --local detailsContainer = UI("InlineGroup")
        --        .SetFullWidth(true)
        --        .SetFullHeight(true)
        --        .SetLayout("Fill")
        --        .AddTo(f)()
        --
        --local details = UI("MultiLineEditBox")
        --        .SetFullWidth(true)
        --        .SetFullHeight(true)
        --        .DisableButton(true)
        --        .SetLabel(nil)
        --        .AddTo(detailsContainer)()
        --
        --logging:SetRootThreshold(logging.Level.Trace)
        --logging:SetWriter(
        --        function(msg)
        --            local txt = '\n' .. msg .. details:GetText()
        --            details:SetText(txt)
        --        end
        --)
    end
end

function R2D2:OnInitialize()
    self:SetupLogging()
    logging:Trace("OnInitialize(%s)", self:GetName())
    self.version = GetAddOnMetadata(name, "Version")
    self.db = LibStub('AceDB-3.0'):New('R2D2_DB')
    self.chatCmdHelp = {
        {cmd = "config", desc = L["chat_commands_config"]},
        {cmd = "version", desc = L["chat_commands_version"]},
    }
    -- setup chat hooks
    self:RegisterChatCommand("r2d2", "ChatCommand")
end

function R2D2:OnEnable()
    logging:Trace("OnEnable(%s) : '%s', '%s'", self:GetName(), UnitName("player"), self.version)
    for name, module in self:IterateModules() do
        if not module.db or module.db.profile.enabled or not module.defaults then
            logging:Trace("OnEnable(%s) - Enabling module (startup) '%s'", self:GetName(), name)
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