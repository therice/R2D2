local _, AddOn = ...

local Minimap   = AddOn:NewModule("Minimap", "AceEvent-3.0")
local DbIcon    = AddOn.Libs.DbIcon
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging

function Minimap:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.mm = self:GetButton()
    self.mm:Initialize()
end

local MinimapButton = {}
MinimapButton.__index = MinimapButton

local TT_ENTRY = "|cFFCFCFCF%s:|r %s"

local function CreateDataBoker()
   return AddOn.Libs.DataBroker:NewDataObject(
           "R2D2",
           {
               type = "launcher",
               text = "R2D2",
               icon = "Interface\\AddOns\\R2D2\\Media\\Textures\\icon.blp",
               OnTooltipShow = function(tooltip)
                   tooltip:AddDoubleLine("|cfffe7b2cR2D2|r", format("|cffFFFFFF%s|r", tostring(AddOn.version)))
                   tooltip:AddLine(format(TT_ENTRY, L["left_click"], L["open_standings"]))
                   tooltip:AddLine(format(TT_ENTRY, L["shift_left_click"], L["open_config"]))
               end,
               OnClick = function(self, button)
                   if button == "RightButton" then
                   elseif button == "MiddleButton" then
                   else
                       if IsShiftKeyDown() then
                           AddOn:Config()
                       else
                           AddOn:PointsModule():Toggle()
                       end
                   end
               end,
           }
   )
end

function MinimapButton:New()
    local instance = {
        dataBroker = CreateDataBoker()
    }
    return setmetatable(instance, MinimapButton)
end

function MinimapButton:Initialize()
    DbIcon:Register("R2D2", self.dataBroker, AddOn.db.profile.minimap)
end

function Minimap:GetButton()
    if self.mm then return self.mm end
    self.mm = MinimapButton:New()
    return self.mm
end

