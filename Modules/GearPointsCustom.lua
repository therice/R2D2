local _, AddOn = ...
local GpCustom      = AddOn:NewModule("GearPointsCustom", "AceHook-3.0", "AceEvent-3.0")
local GearPoints    = AddOn.Libs.GearPoints
local L             = AddOn.components.Locale
local Logging       = AddOn.components.Logging
local Util          = AddOn.Libs.Util
local Tables        = Util.Tables
local Objects       = Util.Objects
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
                local id_key = tostring(id)
                if not custom_items[id_key] then
                    Logging:Trace("AddDefaultCustomItems() : adding item id=%s", id_key)
                    custom_items[id_key] = {
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

function GpCustom:SetupConfigOptions()
    local custom_items_args = GpCustom.options.args

    for _, id in Objects.Each(Tables.Sort(Tables.Keys(self.db.profile.custom_items))) do
        local custom_item_args = Tables.New()
        -- todo : if never seen before will return nil, need to register for callback
        local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(tonumber(id))
        if name then
            Logging:Debug('SetupConfigOptions() : Adding %s (%s)', link, id)
            custom_item_args['custom_items.'..id..'.header'] =  COpts.Description(link, 'large', 0, {image=texture})
            custom_item_args['custom_items.'..id..'.filler_1'] = COpts.Header('', nil, 1)
            custom_item_args['custom_items.'..id..'.rarity'] = COpts.Select(L['quality'], 2,  L['quality_desc'],
                    {
                        [0] = ITEM_QUALITY0_DESC, -- Poor
                        [1] = ITEM_QUALITY1_DESC, -- Common
                        [2] = ITEM_QUALITY2_DESC, -- Uncommon
                        [3] = ITEM_QUALITY3_DESC, -- Rare
                        [4] = ITEM_QUALITY4_DESC, -- Epic
                        [5] = ITEM_QUALITY5_DESC, -- Legendary
                        [6] = ITEM_QUALITY6_DESC, -- Artifact
                    }, nil, nil, {width='double'})
            custom_item_args['custom_items.'..id..'.item_level'] = COpts.Range(L['item_lvl'], 3, 1, 100, 1, {desc=L['item_lvl_desc'], width='double'})
            custom_item_args['custom_items.'..id..'.equip_location'] = COpts.Select('Equipment', 4,  'Equipment Desc',
                    {
                        INVTYPE_HEAD            = INVTYPE_HEAD,
                        INVTYPE_NECK            = INVTYPE_NECK,
                        INVTYPE_SHOULDER        = INVTYPE_SHOULDER,
                        INVTYPE_CHEST           = INVTYPE_CHEST,
                        INVTYPE_ROBE            = INVTYPE_ROBE,
                        INVTYPE_WAIST           = INVTYPE_WAIST,
                        INVTYPE_LEGS            = INVTYPE_LEGS,
                        INVTYPE_FEET            = INVTYPE_FEET,
                        INVTYPE_WRIST           = INVTYPE_WRIST,
                        INVTYPE_HAND            = INVTYPE_HAND,
                        INVTYPE_FINGER          = INVTYPE_FINGER,
                        INVTYPE_TRINKET         = INVTYPE_TRINKET,
                        INVTYPE_CLOAK           = INVTYPE_CLOAK,
                        INVTYPE_WEAPON          = INVTYPE_WEAPON,
                        INVTYPE_SHIELD          = INVTYPE_SHIELD,
                        INVTYPE_2HWEAPON        = INVTYPE_2HWEAPON,
                        INVTYPE_WEAPONMAINHAND  = INVTYPE_WEAPONMAINHAND,
                        INVTYPE_WEAPONOFFHAND   = INVTYPE_WEAPONOFFHAND,
                        INVTYPE_HOLDABLE        = INVTYPE_HOLDABLE,
                        INVTYPE_RANGED          = INVTYPE_RANGED,
                        INVTYPE_THROWN          = INVTYPE_THROWN,
                        INVTYPE_RELIC           = INVTYPE_RELIC,
                        INVTYPE_WAND            = INVTYPE_WAND,
                        --["INVTYPE_BOWS"]        = GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_BOWS),
                    }, nil, nil, {width='double'})


            custom_items_args[id] = {
                type = 'group',
                name = name,
                icon = texture,
                args = custom_item_args,
            }
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
    self:SetupConfigOptions()
end

function GpCustom:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    GearPoints:ResetCustomItems()
end