local _, AddOn = ...
local TrafficHistory= AddOn:NewModule("TrafficHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging       = AddOn.Libs.Logging
local Util          = AddOn.Libs.Util
local UI            = AddOn.components.UI
local L             = AddOn.components.Locale
local Models        = AddOn.components.Models


function TrafficHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    -- traffic history
    self.db = AddOn.Libs.AceDB:New('R2D2_TrafficDB')
end

function TrafficHistory:GetHistory()
    return self.db.factionrealm
end