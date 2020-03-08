local _, AddOn = ...
local SB        = AddOn:NewModule("Standby", "AceHook-3.0", "AceEvent-3.0")
local EP        = AddOn:GetModule("EffortPoints")
local Logging   = AddOn.components.Logging

function SB:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = EP.db.standby
end

function SB:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end
