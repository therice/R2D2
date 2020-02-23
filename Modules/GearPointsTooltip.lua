local _,namespace = ...
local G = _G

local GpTooltip     = namespace:NewModule("GearPointsTooltip", "AceHook-3.0", "AceEvent-3.0")
local GearPoints    = LibStub("LibGearPoints-1.2")
local ItemUtil      = LibStub("LibItemUtil-1.0")
local Objects       = namespace.components.Util.Objects
local L             = namespace.components.Locale
local logging       = namespace.components.Logging

-- These defaults are registered at a module specific namespace in the DB
-- No need to qualify them further
GpTooltip.defaults = {
    profile = {
        enabled = true,
        threshold = 4,  -- epic
    }
}

function GpTooltip:OnInitialize()
    logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = namespace.db:RegisterNamespace(self:GetName(), GpTooltip.defaults)
end

function GpTooltip:OnEnable()
    logging:Debug("OnEnable() : enabled '%s', threshold '%s'", Objects.ToString(self.db.profile.enabled), self.db.profile.threshold)
    GearPoints:SetQualityThreshold(self.db.profile.threshold)
    local obj = EnumerateFrames()
    while obj do
        -- if a game tool tip and not the one from ItemUtils
        if obj:IsObjectType("GameTooltip") and obj ~= ItemUtil.tooltip then
            local obj_name = obj:GetName() or nil
            assert(obj:HasScript("OnTooltipSetItem"))
            logging:Debug("GearPointsTooltip:OnEnable() : Hooking script into GameTooltip '%s'",  Objects.ToString(obj_name))
            self:HookScript(obj, "OnTooltipSetItem", OnTooltipSetItemAddGp)
        end
        obj = EnumerateFrames(obj)
    end
end

function OnTooltipSetItemAddGp(tooltip, ...)
    -- logging:Trace("GearPointsTooltip:OnTooltipSetItem(%s)",  Objects.ToString(tooltip:GetName()))
    local _, itemlink = tooltip:GetItem()
    local gp, comment = GearPoints:GetValue(itemlink)
    local ilvl = select(4, GetItemInfo(itemlink))
    logging:Trace("GearPointsTooltip:OnTooltipSetItem(%s) : GP = %s, Comment = %s, ItemLevel = %s", itemlink,  Objects.ToString(gp),  Objects.ToString(comment),  Objects.ToString(ilvl))
    if ilvl then tooltip:AddLine(("ItemLevel [%s] : %s"):format("Alpaca", ilvl)) end
    if not gp then return end
    tooltip:AddLine(("GP [%s] : %d (%s)"):format("Alpaca",gp, comment), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end




