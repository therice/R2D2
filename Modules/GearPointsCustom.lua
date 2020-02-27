local _, AddOn = ...
local GpCustom      = AddOn:NewModule("GearPointsCustom", "AceHook-3.0", "AceEvent-3.0")
local GearPoints    = AddOn.Libs.GearPoints
local L             = AddOn.components.Locale
local Logging       = AddOn.components.Logging
local Tables        = AddOn.components.Util.Tables
local Objects       = AddOn.components.Util.Objects
local COpts         = AddOn.components.UI.ConfigOptions

GpCustom.defaults = {
    profile = {
        enabled = false,
        custom_items = {

        }
    }
}
-- These are arguments for configuring options via UI
-- See UI/Config.lua
GpCustom.options = {
    name = L['gp_custom'],
    desc = L['gp_custom_desc'],
    args = {
        help = COpts.Description(L["gp_custom_help"]),
    }
}

function GpCustom:AddDefaultCustomItems()
    local config = self.db.profile
    if not config.custom_items then
        config.custom_items = Tables.New()
    end
    local custom_items =  config.custom_items
    local faction = UnitFactionGroup("player")
    local defaultCustomItems = AddOn:GetDefaultCustomItems()

    if Tables.Count(defaultCustomItems) > 0 then
        for id, value in Objects.Each(defaultCustomItems) do
            -- make sure the item applies to player's faction
            if not Objects.IsSet(value[4]) or Objects.Equals(value[4], faction) then
                if not custom_items[id] then
                    Logging:Trace("AddDefaultCustomItems() : adding item id=%s", id)
                    custom_items[id] = {
                        rarity = value[1],
                        item_level = value[2],
                        equip_location =  value[3],
                        default = true,
                    }
                end
            end
        end
    end
end

function GpCustom:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace("GearPointsCustom", GpCustom.defaults)
    Logging:Trace("OnInitialize(%s) : custom item count = %s", self:GetName(), Tables.Count(self.db.profile.custom_items))
    self:AddDefaultCustomItems()
end

function GpCustom:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    GearPoints:SetCustomItems(self.db.profile.custom_items)
end

function GpCustom:OnDisable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    GearPoints:ResetCustomItems()
end