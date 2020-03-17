local _, AddOn = ...
local Logging   = AddOn.components.Logging

function AddOn:CallModule(module)
    self:EnableModule(module)
end

function AddOn:MasterLooterModule()
    return self:GetModule("MasterLooter")
end

function AddOn:OnMasterLooterDbReceived(mlDb)
    Logging:Debug("OnMasterLooterDbReceived()")
    local ML = self:MasterLooterModule()

    self.mlDb = mlDb
    for type, _ in pairs(mlDb.responses) do
        if not ML.defaults.profile.responses[type] then
            setmetatable(self.mlDb.responses[type], {__index = ML.defaults.profile.responses.default})
        end
    end

    if not self.mlDb.responses.default then self.mlDb.responses.default = {} end
    setmetatable(self.mlDb.responses.default, {__index = ML.defaults.profile.responses.default})

    if not self.mlDb.buttons.default then self.mlDb.buttons.default = {} end
    setmetatable(self.mlDb.buttons.default, { __index = ML.defaults.profile.buttons.default})
end

function AddOn:Timer(type)
    Logging:Debug("Timer(%s)", type)
end