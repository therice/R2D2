local _, namespace = ...
local G = _G
local _TEST = G.R2D2_Testing

local LoggingUI = namespace:NewModule("LoggingUI", "AceEvent-3.0")
local UI        = namespace.components.UI
local Strings   = namespace.components.Util.Strings
local Tables    = namespace.components.Util.Tables
local logging   = namespace.components.Logging


if _TEST then
    logging:SetWriter(
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
    LoggingUI.preInitLogging = { }
    logging:SetWriter(
            function(msg)
                table.insert(LoggingUI.preInitLogging, 1, msg)
            end
    )
end


function LoggingUI:OnInitialize()
    logging:Trace("OnInitialize(%s)", self:GetName())

    if not self.loggingFrame or not self.loggingDetail then
        self.loggingFrame =
            UI("Frame")
                .SetTitle("R2D2 Logging")
                .SetStatusText("Mouse wheel to scroll. Title bar drags. Bottom-right corner re-sizes.")
                .SetLayout("Fill")
                .SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", 0, 0)()
        -- self.loggingFrame:Hide()

        local detailsContainer =
            UI("InlineGroup")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .SetLayout("Fill")
                .AddTo(self.loggingFrame)()

        self.loggingDetail =
            UI("MultiLineEditBox")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .DisableButton(true)
                .SetLabel(nil)
                .AddTo(detailsContainer)()

        -- now set logging to emit to frame
        logging:SetWriter(
                function(msg)
                    local txt = msg .. '\n' .. self.loggingDetail:GetText()
                    self.loggingDetail:SetText(txt)
                end
        )
    end
end

function LoggingUI:OnEnable()
    logging:Trace("OnEnable(%s)", self:GetName())
    -- copy any pre-enabled logging to logging window
    self.loggingDetail:SetText(
            self.loggingDetail:GetText() ..
            Strings.Join('\n',  unpack(Tables.Values(LoggingUI.preInitLogging)))
    )
    -- discard the catpured pre-enabled logging
    self.preInitLogging = {}
end

