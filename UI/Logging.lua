local name, namespace = ...
local G = _G

local LoggingUI = namespace:NewModule("LoggingUI", "AceEvent-3.0")
local UI        = namespace.components.UI
local logging   = namespace.components.Logging


function LoggingUI:OnInitialize()
    logging:Trace("OnInitialize(%s)", self:GetName())
end

function LoggingUI:OnEnable()
    logging:Trace("OnEnable(%s)", self:GetName())
    if not self.loggingFrame then
        self.loggingFrame =
            UI("Frame")
                .SetTitle("R2D2 Logging")
                .SetStatusText("Mouse wheel to scroll. Title bar drags. Bottom-right corner re-sizes.")
                .SetLayout("Fill")
                .SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", 0, 0)()

        local detailsContainer = UI("InlineGroup")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .SetLayout("Fill")
                .AddTo(self.loggingFrame)()

        UI("MultiLineEditBox")
                .SetFullWidth(true)
                .SetFullHeight(true)
                .DisableButton(true)
                .SetLabel(nil)
                .AddTo(detailsContainer)()

        self.loggingFrame:Hide()
    end
end

