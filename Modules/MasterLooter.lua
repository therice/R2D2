local _, AddOn = ...
local ML        = AddOn:NewModule("MasterLooter", "AceEvent-3.0", "AceBucket-3.0", "AceComm-3.0", "AceTimer-3.0", "AceHook-3.0")
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
end

function GpCustom:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end

function GpCustom:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:UnregisterAllEvents()
    self:UnregisterAllBuckets()
    self:UnregisterAllComm()
    self:UnregisterAllMessages()
    self:UnhookAll()
end