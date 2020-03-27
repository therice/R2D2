local _, AddOn = ...
local GpTooltip     = AddOn:NewModule("GearPointsTooltip", "AceHook-3.0", "AceEvent-3.0")
local GearPoints    = AddOn.Libs.GearPoints
local ItemUtil      = AddOn.Libs.ItemUtil
local Util          = AddOn.Libs.Util
local Objects       = Util.Objects
local COpts         = AddOn.components.UI.ConfigOptions
local L             = AddOn.components.Locale
local Logging       = AddOn.components.Logging

-- These are the defaults that go into the DB
GpTooltip.defaults = {
    profile = {
        enabled = true,
        threshold = 4, -- epic
    }
}

-- These are arguments for configuring options via UI
-- See UI/Config.lua
GpTooltip.options = {
    name = L['gp_tooltips'],
    desc = L['gp_tooltips_desc'],
    args = {
        help = COpts.Description(L["gp_tooltips_help"]),
        -- COpts.Select(name, order, descr, values, get, set, extra)
        threshold = COpts.Select(L['quality_threshold'], 10,  L['quality_threshold_desc'],
            {
                [0] = ITEM_QUALITY0_DESC, -- Poor
                [1] = ITEM_QUALITY1_DESC, -- Common
                [2] = ITEM_QUALITY2_DESC, -- Uncommon
                [3] = ITEM_QUALITY3_DESC, -- Rare
                [4] = ITEM_QUALITY4_DESC, -- Epic
                [5] = ITEM_QUALITY5_DESC, -- Legendary
                [6] = ITEM_QUALITY6_DESC, -- Artifact
            },
            function() return GearPoints:GetQualityThreshold() end,
            function(info, itemQuality)
                info.handler.db.profile.threshold = itemQuality
                GearPoints:SetQualityThreshold(itemQuality)
            end
        )
    }
}

function GpTooltip:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), GpTooltip.defaults)
end

function GpTooltip:OnEnable()
    Logging:Debug("OnEnable() : enabled '%s', threshold '%s'", Objects.ToString(self.db.profile.enabled), Objects.ToString(self.db.profile.threshold))
    GearPoints:SetQualityThreshold(self.db.profile.threshold)
    local obj = EnumerateFrames()
    while obj do
        -- if a game tool tip and not the one from ItemUtils
        if obj:IsObjectType("GameTooltip") and obj ~= ItemUtil.tooltip then
            local obj_name = obj:GetName() or nil
            assert(obj:HasScript("OnTooltipSetItem"))
            Logging:Trace("GearPointsTooltip:OnEnable() : Hooking script into GameTooltip '%s'",  Objects.ToString(obj_name))
            self:HookScript(obj, "OnTooltipSetItem", OnTooltipSetItemAddGp)
        end
        obj = EnumerateFrames(obj)
    end
end


function OnTooltipSetItemAddGp(tooltip, ...)
    -- logging:Trace("GearPointsTooltip:OnTooltipSetItem(%s)",  Objects.ToString(tooltip:GetName()))
    local _, itemlink = tooltip:GetItem()
    local gp, comment, ilvl = GearPoints:GetValue(itemlink)
    -- todo : may want to go back to this instead of returning from value
    --local ilvl = GearPoints:GetItemLevel(itemlink)
    --[[
    logging:Trace("GearPointsTooltip:OnTooltipSetItem(%s) : GP = %s, Comment = %s, ItemLevel = %s",
            itemlink,  Objects.ToString(gp),  Objects.ToString(comment),  Objects.ToString(ilvl)
    )
    --]]
    if ilvl then tooltip:AddLine(L["gp_tooltip_ilvl"]:format(ilvl)) end
    if not gp then return end
    tooltip:AddLine(L["gp_tooltip_gp"]:format(gp, comment), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end




