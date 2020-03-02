local _, AddOn = ...
local G = _G
local _TEST = G.R2D2_Testing
local loggingFrame, loggingDetail, preInitLogging

local LoggingUI = AddOn:NewModule("LoggingUI", "AceEvent-3.0")
local L         = AddOn.components.Locale
local UI        = AddOn.components.UI
local COpts     = UI.ConfigOptions
local Util      = AddOn.Libs.Util
local Strings   = Util.Strings
local Tables    = Util.Tables
local Logging   = AddOn.components.Logging

if _TEST then
    Logging:SetWriter(
            function(msg)
                G.R2D2_Testing_GetLogFile():write(msg, '\n')
            end
    )

    _G.print = function(...)
        G.R2D2_Testing_GetLogFile():write(...)
        G.R2D2_Testing_GetLogFile():write('\n')
    end
else
    -- track all emitted logging before we setup the frame for display
    preInitLogging = { }
    Logging:SetWriter(
            function(msg)
                table.insert(preInitLogging, 1, msg)
            end
    )
end

-- function COpts.Execute(name, order, descr, fn, extra)

LoggingUI.options = {
    name = L['logging'],
    desc = L['logging_desc'],
    ignore_enable_disable = true,
    args = {
        help = COpts.Description(L['logging_help']),
        toggleWindow = COpts.Execute(L["logging_window_toggle"], 1, L["logging_window_toggle_desc"], function() LoggingUI:Toggle() end),
        spacer = COpts.Description("", nil, 2),
        -- function COpts.Select(name, order, descr, values, get, set, extra)
        logThreshold = COpts.Select(L['logging_threshold'], 3, L['logging_threshold_desc'],
                {
                    [1] = Logging.Level.Disabled,
                    [2] = Logging.Level.Trace,
                    [3] = Logging.Level.Debug,
                    [4] = Logging.Level.Info,
                    [5] = Logging.Level.Warn,
                    [6] = Logging.Level.Error,
                    [7] = Logging.Level.Fatal,
                },
                function() return Logging:GetRootThreshold() end,
                function(info, logThreshold)
                    AddOn.db.profile.logThreshold = logThreshold
                    Logging:SetRootThreshold(logThreshold)
                end
        )
    }
}

function LoggingUI:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())

    if not loggingFrame or not loggingDetail then
        loggingFrame =
            UI("Frame", "R2D2_LoggingWindow")
                .SetTitle("R2D2 Logging")
                .SetStatusText("Mouse wheel to scroll. Title bar drags. Bottom-right corner re-sizes.")
                .SetLayout("Flow")
                .SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", 0, 0)()

        UI("Button")
            .SetText("Clear")
            .SetHeight(20)
            .SetWidth(100)
            .SetCallback("OnClick", function() loggingDetail:SetText("") end)
            .AddTo(loggingFrame)()

        local detailsContainer =
            UI("InlineGroup")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .SetLayout("Fill")
                .AddTo(loggingFrame)()

        loggingDetail =
            UI("MultiLineEditBox")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .DisableButton(true)
                .SetLabel(nil)
                .AddTo(detailsContainer)()


        -- now set logging to emit to frame
        Logging:SetWriter(
                function(msg)
                    local txt = msg .. '\n' .. loggingDetail:GetText()
                    loggingDetail:SetText(txt)
                end
        )
    end
end

function LoggingUI:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- copy any pre-enabled logging to logging window
    loggingDetail:SetText(
            loggingDetail:GetText() ..
            Strings.Join('\n',  unpack(Tables.Values(preInitLogging)))
    )
    -- discard the captured pre-enabled logging
    preInitLogging = {}
end

function LoggingUI:Toggle()
    if loggingFrame:IsVisible() then
        loggingFrame:Hide()
    else
        loggingFrame:Show()
    end
end