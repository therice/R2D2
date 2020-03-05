local _, AddOn = ...
local GP        = AddOn:NewModule("GearPoints", "AceHook-3.0", "AceEvent-3.0")
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Tables    = Util.Tables
local Objects   = Util.Objects
local COpts     = AddOn.components.UI.ConfigOptions
local LibGP     = AddOn.Libs.GearPoints

local DisplayName = {}
DisplayName.OneHWeapon  = L["%s %s"]:format(_G.INVTYPE_WEAPON, _G.WEAPON)
DisplayName.TwoHWeapon  = L["%s %s"]:format(_G.INVTYPE_2HWEAPON, _G.WEAPON)
DisplayName.MainHWeapon = L["%s %s"]:format(_G.INVTYPE_WEAPONMAINHAND, _G.WEAPON)
DisplayName.OffHWeapon  = L["%s %s"]:format(_G.INVTYPE_WEAPONOFFHAND, _G.WEAPON)

GP.defaults = {
    profile = {
        enabled             = true,
        gp_base             = 4.8,
        gp_coefficient_base = 2.5,
        gp_multiplier       = 1,
        gp_min              = 1,
        head_scale_1        = 1,
        head_comment_1      = _G.INVTYPE_HEAD,
        neck_scale_1        = 0.5,
        neck_comment_1      = _G.INVTYPE_NECK,
        shoulder_scale_1    = 0.75,
        shoulder_comment_1  = _G.INVTYPE_SHOULDER,
        chest_scale_1       = 1,
        chest_comment_1     = _G.INVTYPE_CHEST,
        waist_scale_1       = 0.75,
        waist_comment_1     = _G.INVTYPE_WAIST,
        legs_scale_1        = 1,
        legs_comment_1      = _G.INVTYPE_LEGS,
        feet_scale_1        = 0.75,
        feet_comment_1      = _G.INVTYPE_FEET,
        wrist_scale_1       = 0.5,
        wrist_comment_1     = _G.INVTYPE_WRIST,
        hand_scale_1        = 0.75,
        hand_comment_1      = _G.INVTYPE_HAND,
        finger_scale_1      = 0.5,
        finger_comment_1    = _G.INVTYPE_FINGER,
        trinket_scale_1     = 0.75,
        trinket_comment_1   = _G.INVTYPE_TRINKET,
        cloak_scale_1       = 0.5,
        cloak_comment_1     = _G.INVTYPE_CLOAK,
        shield_scale_1      = 0.5,
        shield_comment_1    = _G.SHIELDSLOT,
        weapon_scale_1      = 1.5,
        weapon_comment_1    = DisplayName.OneHWeapon,
        weapon2h_scale_1    = 2,
        weapon2h_comment_1  = DisplayName.TwoHWeapon,
        weaponmainh_scale_1 = 1.5,
        weaponmainh_comment_1 = DisplayName.MainHWeapon,
        weaponoffh_scale_1  = 0.5,
        weaponoffh_comment_1= DisplayName.OffHWeapon,
        holdable_scale_1    = 0.5,
        holdable_comment_1  = _G.INVTYPE_HOLDABLE,
        ranged_scale_1      = 2, -- Bows, Guns, Crossbows
        ranged_comment_1    = _G.INVTYPE_RANGED,
        wand_scale_1        = 0.5,
        wand_comment_1      = GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND),
        thrown_scale_1      = 0.5,
        thrown_comment_1    = GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_THROWN),
        relic_scale_1       = 0.667,
        relic_comment_1     = _G.INVTYPE_RELIC,
    }
}

-- These are arguments for configuring options via UI
-- See UI/Config.lua
GP.options = {
    name = L['gp'],
    desc = L['gp_desc'],
    args = {
        help = COpts.Description(L["gp_help"]),
        headerEquation = COpts.Header(L["equation"], nil, 10),
        equation = {
            order = 11,
            type = "group",
            inline = true,
            name = "",
            args = {
                -- http://www.epgpweb.com/help/gearpoints
                help = COpts.Description("GP = base * (coefficient ^ ((item_level / 26) + (item_rarity - 4)) * slot_multiplier) * multiplier", "large"),
                gp_base = COpts.Range("base", 2, 1, 1000),
                gp_coefficient_base = COpts.Range("coefficient", 3, 1, 100),
                gp_multiplier = COpts.Range("multiplier", 4, 1, 100),
            },
        },
        headerSlots = COpts.Header(L["slots"], nil, 20),
    }
}

do
    local gpdefaults = GP.defaults.profile
    -- table for storing processed defaults which needed added as arguments
    local slotArgs = Tables.New()

    -- iterate the keys in alphabetical order
    for _, key in Objects.Each(Tables.Sort(Tables.Keys(gpdefaults))) do
        local parts = {strsplit('_', key)}
        if #parts == 3 and Objects.In(parts[2], 'scale', 'comment') then
            local slot = parts[1]
            local slot_input = parts[2]
            local slotTable = slotArgs[slot] or Tables.New()

            if slot_input == 'scale' then
                slotTable[key] = COpts.Range(L["slot_multiplier"], 2, 0, 5, nil, {width='double'})
            elseif slot_input == 'comment' then
                local displayName = gpdefaults[key]
                slotTable['displayname'] = displayName
                slotTable['help'] = COpts.Description(displayName)
                slotTable[key] = COpts.Input(L['slot_comment'], 3, {width='double'})
            end

            slotArgs[slot] = slotTable
        end
    end

    -- capture a reference to GP configuration option's arguments
    -- this is where we'll be adding the slot specific entries
    local gpargs = GP.options.args

    local order = 21
    -- todo : this is going to sort by slot and not the display name, maybe cleanup when done
    for _, slot in Objects.Each(Tables.Sort(Tables.Keys(slotArgs))) do
        local displayname = slotArgs[slot].displayname
        gpargs[slot] = {
            order = order,
            type = "group",
            name = displayname,
            desc = L["item_slot_with_name"]:format(displayname),
            args = Tables.CopyUnselect(slotArgs[slot], 'displayname')
        }
        order = order + 1
    end

    Tables.Release(slotArgs)
end

function GP:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    -- replace the library string representation function with our utility (more detail)
    LibGP:SetToStringFn(Objects.ToString)
    self.db = AddOn.db:RegisterNamespace(self:GetName(), GP.defaults)
end

function GP:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    LibGP:SetScalingConfig(self.db.profile)
    LibGP:SetFormulaInputs(self.db.profile.gp_base, self.db.profile.gp_coefficient_base, self.db.profile.gp_multiplier)
end
