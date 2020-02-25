local _, AddOn = ...
local GP        = AddOn:NewModule("GearPoints", "AceHook-3.0", "AceEvent-3.0")
local L         = AddOn.components.Locale
local logging   = AddOn.components.Logging
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

local function HelpPlate(desc, fontSize)
    fontSize = fontSize or 'medium'
    help = {
        order = 1,
        type = "description",
        name = desc,
        fontSize = fontSize,
    }
    return help
end

local function ScalePlate(index)
    scalePlate = {
        name = L["multiplier_with_id"]:format(index),
        type = "range",
        min = 0,
        max = 5,
        step = 0.01,
        order = index * 2,
    }
    return scalePlate
end

local function CommentPlate(index)
    local comment = L["comment_with_id"]:format(index)
    commentPlate = {
        name = comment,
        desc = comment,
        type = "input",
        order = index * 2 + 1,
    }
    return commentPlate
end

-- These are arguments for configuring options via UI
-- See UI/Config.lua
GP.options = {
    name = L['gp'],
    desc = L['gp_desc'],
    args = {
        help = HelpPlate(L["gp_help"]),
        headerEquation = {
            order = 10,
            type = "header",
            name = L["equation"],
        },
        equation = {
            order = 11,
            type = "group",
            inline = true,
            name = "",
            args = {
                -- http://www.epgpweb.com/help/gearpoints
                help = HelpPlate("GP = base * (coefficient ^ ((item_level / 26) + (item_rarity - 4)) * slot_multiplier) * multiplier", "large"),
                gp_base = {
                    order = 2,
                    type = "range",
                    name = "base",
                    min = 1,
                    max = 10000,
                    step = 0.01,
                },
                gp_coefficient_base = {
                    order = 3,
                    type = "range",
                    name = "coefficient",
                    min = 1,
                    max = 100,
                    step = 0.01,
                },
                gp_multiplier = {
                    order = 4,
                    type = "range",
                    name = "multiplier",
                    min = 1,
                    max = 100,
                    step = 0.01,
                },
            },
        },
        headerSlots = {
            order = 20,
            type = "header",
            name = L["slots"],
        },
        head = {
            order = 21,
            type = "group",
            name = _G.INVTYPE_HEAD,
            args = {
                help = HelpPlate(_G.INVTYPE_HEAD),
                head_scale_1 = ScalePlate(1),
                head_comment_1 = CommentPlate(1),
            },
        },
        neck = {
            order = 22,
            type = "group",
            name = _G.INVTYPE_NECK,
            args = {
                help = HelpPlate(_G.INVTYPE_NECK),
                neck_scale_1 = ScalePlate(1),
                neck_comment_1 = CommentPlate(1),
            },
        },
    }
}

function GP:OnInitialize()
    logging:Debug("OnInitialize(%s)", self:GetName())
    -- replace the library string representation function with our utility (more detail)
    LibGP:SetToStringFn(AddOn.components.Util.Objects.ToString)
    self.db = AddOn.db:RegisterNamespace(self:GetName(), GP.defaults)
end

function GP:OnEnable()
    logging:Debug("OnEnable(%s)", self:GetName())
    LibGP:SetScalingConfig(self.db.profile)
    LibGP:SetFormulaInputs(self.db.profile.gp_base, self.db.profile.gp_coefficient_base, self.db.profile.gp_multiplier)
end
