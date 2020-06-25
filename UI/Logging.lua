local _, AddOn = ...
local G = _G
local _TEST = G.R2D2_Testing
local preInitLogging

local LoggingUI = AddOn:NewModule("LoggingUI", "AceEvent-3.0")
local L         = AddOn.components.Locale
local UI        = AddOn.components.UI
local COpts     = UI.ConfigOptions
local Util      = AddOn.Libs.Util
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
              Tables.Push(preInitLogging, msg)
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
                    [Logging:GetThreshold(Logging.Level.Disabled)] = Logging.Level.Disabled,
                    [Logging:GetThreshold(Logging.Level.Fatal)]    = Logging.Level.Fatal,
                    [Logging:GetThreshold(Logging.Level.Error)]    = Logging.Level.Error,
                    [Logging:GetThreshold(Logging.Level.Warn)]     = Logging.Level.Warn,
                    [Logging:GetThreshold(Logging.Level.Info)]     = Logging.Level.Info,
                    [Logging:GetThreshold(Logging.Level.Debug)]    = Logging.Level.Debug,
                    [Logging:GetThreshold(Logging.Level.Trace)]    = Logging.Level.Trace,
                },
                function() return Logging:GetRootThreshold() end,
                function(_, logThreshold)
                    AddOn.db.profile.logThreshold = logThreshold
                    Logging:SetRootThreshold(logThreshold)
                end
        )
    }
}

local function ScrollingFunction(self, arg)
    if arg > 0 then
        if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
    elseif arg < 0 then
        if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
    end
end


function LoggingUI:GetFrame()
    if self.frame then return self.frame end
    
    local frame = UI:CreateFrame("R2D2_LoggingWindow", "LoggingUI", L['r2d2_logging_frame'], nil, nil, false)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    frame:SetWidth(750)
    frame:SetHeight(400)

    -- The scrolling message frame with all the debug info.
    frame.msg = CreateFrame("ScrollingMessageFrame", nil, frame.content)
    frame.msg:SetMaxLines(10000)
    frame.msg:SetFading(false)
    frame.msg:SetFontObject(GameFontHighlightLeft)
    frame.msg:EnableMouseWheel(true)
    frame.msg:SetTextCopyable(true)
    frame.msg:SetBackdrop(
            {
                bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile     = true, tileSize = 8, edgeSize = 4,
                insets   = { left = 2, right = 2, top = 2, bottom = 2 }
            }
    )
    frame.msg:SetWidth(frame:GetWidth() - 25)
    frame.msg:SetHeight(frame:GetHeight() - 60)
    frame.msg:SetPoint("CENTER", frame, "CENTER")
    
    local close = UI:CreateButton("Close", frame.content)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 5)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close
    
    local clear = UI:CreateButton("Clear", frame.content)
    clear:SetPoint("RIGHT", frame.close, "LEFT", -25)
    clear:SetScript("OnClick", function() frame.msg:Clear() end)
    frame.clear = clear
    
    ---- now set logging to emit to frame
    Logging:SetWriter(
            function(msg)
                if LoggingUI:IsEnabled() and #preInitLogging == 0 then
                    frame.msg:AddMessage(msg)
                else
                    Tables.Push(preInitLogging, msg)
                end
            end
    )

    frame.msg:SetScript("OnMouseWheel", ScrollingFunction)

    return frame
end



function LoggingUI:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.frame = self:GetFrame()
    --@debug@
    self.frame:Show()
    --@end-debug@
end

function LoggingUI:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- copy any pre-enabled logging to logging window
    Tables.Call(preInitLogging,
                function(line)
                    self.frame.msg:AddMessage(line, 1.0, 1.0, 1.0, nil, false)
                end
    )
    
    -- discard the captured pre-enabled logging
    preInitLogging = {}
end

function LoggingUI:EnableOnStartup()
    return true
end

function LoggingUI:Toggle()
    if self.frame:IsVisible() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end