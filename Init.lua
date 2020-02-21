-- name : The name of your addon as set in the TOC and folder name
-- name : The shared addon table between the Lua files of an addon
local name, namespace = ...

R2D2 = LibStub('AceAddon-3.0'):NewAddon(namespace, name, 'AceConsole-3.0', 'AceEvent-3.0')
R2D2:SetDefaultModuleState(false)

-- Shim for determining locale for localization
do
    local locale = GetLocale()
    local convert = {enGB = 'enUS'}
    local gameLocale = convert[locale] or locale or 'enUS'

    function R2D2:GetLocale()
        return gameLocale
    end
end

namespace.components            = {}
namespace.components.Locale     = LibStub('AceLocale-3.0'):GetLocale("R2D2")
namespace.components.Logging    = LibStub("LibLogging-1.0")
