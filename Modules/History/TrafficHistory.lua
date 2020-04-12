local _, AddOn = ...
local TrafficHistory= AddOn:NewModule("TrafficHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging       = AddOn.Libs.Logging
local Util          = AddOn.Libs.Util
local UI            = AddOn.components.UI
local L             = AddOn.components.Locale
local Models        = AddOn.components.Models

TrafficHistory.options = {
    name = 'Traffic History',
    desc = 'Traffic History Description',
    args = {
    
    }
    
}

TrafficHistory.defaults = {
    profile = {
        enabled = true,
    }
}

function TrafficHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.Libs.AceDB:New('R2D2_TrafficDB', TrafficHistory.defaults)
end

function TrafficHistory:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end

function TrafficHistory:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
end

function TrafficHistory:EnableOnStartup()
    return false
end

function TrafficHistory:GetHistory()
    return self.db.factionrealm
end