-- name : The name of your addon as set in the TOC and folder name
-- name : The shared addon table between the Lua files of an addon
local AceAddon, AceAddonMinor = LibStub('AceAddon-3.0')

local AddOnName, AddOn = ...
R2D2 = AceAddon:NewAddon(AddOn, AddOnName, 'AceConsole-3.0', 'AceEvent-3.0',  "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0", "AceTimer-3.0")
R2D2:SetDefaultModuleState(false)
-- Basic options container for augmentation by other modules
R2D2.Options = {
    name = AddOnName,
    type = 'group',
    childGroups = 'tab',
    handler = AddOn,
    get = "GetDbValue",
    set = "SetDbValue",
    args = {

    }
}
-- just capture version here, it will be turned into semantic version later
-- as we don't have access to that model yet here
R2D2.version = GetAddOnMetadata(AddOnName, "Version")
--@debug@
-- if local development and not substituted, then use a dummy version
if R2D2.version == '@project-version@' then
    R2D2.version = '1-dev'
end
--@end-debug@

-- Shim for determining locale for localization
do
    local locale = GetLocale()
    local convert = {enGB = 'enUS'}
    local gameLocale = convert[locale] or locale or 'enUS'

    function R2D2:GetLocale()
        return gameLocale
    end
end

do
    R2D2.Libs = {}
    R2D2.LibsMinor = {}

    function R2D2:AddLib(name, major, minor)
        if not name then return end

        -- in this case: `major` is the lib table and `minor` is the minor version
        if type(major) == 'table' and type(minor) == 'number' then
            self.Libs[name], self.LibsMinor[name] = major, minor
        else -- in this case: `major` is the lib name and `minor` is the silent switch
            self.Libs[name], self.LibsMinor[name] = LibStub(major, minor)
        end
    end

    R2D2:AddLib('Util', 'LibUtil-1.1')
    R2D2:AddLib('Class', 'LibClass-1.0')
    R2D2:AddLib('Compress', 'LibCompress')
    R2D2:AddLib('Base64', 'LibBase64-1.0')
    R2D2:AddLib('AceAddon', AceAddon, AceAddonMinor)
    R2D2:AddLib('AceLocale', 'AceLocale-3.0')
    R2D2:AddLib('AceDB', 'AceDB-3.0')
    R2D2:AddLib('AceBucket', 'AceBucket-3.0')
    R2D2:AddLib('AceEvent', 'AceEvent-3.0')
    R2D2:AddLib('AceHook', 'AceHook-3.0')
    R2D2:AddLib('AceSerializer', 'AceSerializer-3.0')
    R2D2:AddLib('AceGUI', 'AceGUI-3.0')
    R2D2:AddLib('AceConfig', 'AceConfig-3.0')
    R2D2:AddLib('AceConfigDialog', 'AceConfigDialog-3.0')
    R2D2:AddLib('AceConfigRegistry', 'AceConfigRegistry-3.0')
    R2D2:AddLib('Window', 'LibWindow-1.1')
    R2D2:AddLib('ScrollingTable', 'ScrollingTable')
    R2D2:AddLib('Logging', 'LibLogging-1.0')
    R2D2:AddLib('GearPoints', 'LibGearPoints-1.2')
    R2D2:AddLib('ItemUtil', 'LibItemUtil-1.0')
    R2D2:AddLib('Encounter', 'LibEncounter-1.0')
    R2D2:AddLib('Dialog', 'LibDialog-1.0')
    R2D2:AddLib('DataBroker', 'LibDataBroker-1.1')
    R2D2:AddLib('DbIcon', 'LibDBIcon-1.0')
    R2D2:AddLib('GuildStorage', 'LibGuildStorage-1.3')
end

AddOn.components            = {}
AddOn.components.Locale     = R2D2.Libs.AceLocale:GetLocale("R2D2")
AddOn.components.Logging    = R2D2.Libs.Logging

local Logging = AddOn.components.Logging
local Tables = AddOn.Libs.Util.Tables

local function GetDbValue(self, i)
    -- Logging:Debug("GetDbValue(%s, %s)", self:GetName(), tostring(i[#i]))
    return Tables.Get(self.db.profile, tostring(i[#i]))
end

local function SetDbValue(self, i, v)
    -- Logging:Debug("SetDbValue(%s, %s, %s)", self:GetName(), tostring(i[#i]), tostring(v or 'nil'))
    Tables.Set(self.db.profile, tostring(i[#i]), v)
    AddOn:ConfigTableChanged(self:GetName(), i[#i])
end

AddOn.GetDbValue = GetDbValue
AddOn.SetDbValue = SetDbValue

-- Establish a prototype for mixing into any add-on modules
-- These are used for the configuration UI
local ModulePrototype = {
    IsDisabled = function (self, i)
        Logging:Trace("Module:IsDisabled(%s) : %s", self:GetName(), tostring(not self:IsEnabled()))
        return not self:IsEnabled()
    end,
    SetEnabled = function (self, i, v)
        if v then
            Logging:Trace("Module:SetEnabled(%s) : Enabling module", self:GetName())
            self:Enable()
        else
            Logging:Trace("Module:SetEnabled(%s) : Disabling module ", self:GetName())
            self:Disable()
        end
        self.db.profile.enabled = v
        Logging:Trace("Module:SetEnabled(%s) : %s", self:GetName(), tostring(self.db.profile.enabled))
    end,
    GetDbValue = GetDbValue,
    SetDbValue = SetDbValue,
    ImportData = function(self, data)
        local L = AddOn.components.Locale
        
        Logging:Debug("ImportData(%s)", self:GetName())
        if not self.db then return end
        
        for k, v in pairs(data) do
            self.db.profile[k]  = v
        end
    
        AddOn:ConfigTableChanged(self:GetName())
        AddOn:Print(format(L['import_successful'], AddOn.GetDateTime(), self:GetName()))
    end
}

-- by default, try to use any associated db instance to determine if enabled
-- can be override on a by module basis
function ModulePrototype:EnableOnStartup()
    local enable = (self.db and ((self.db.profile and self.db.profile.enabled) or self.db.enabled)) or false
    Logging:Debug("EnableOnStartup(%s) : %s", self:GetName(), tostring(enable))
    return enable
end

R2D2:SetDefaultModulePrototype(ModulePrototype)
