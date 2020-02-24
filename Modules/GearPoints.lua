local _,namespace = ...
local G = _G

local GP        = namespace:NewModule("GearPoints", "AceHook-3.0", "AceEvent-3.0")
local L         = namespace.components.Locale
local logging   = namespace.components.Logging
local LibGP     = LibStub("LibGearPoints-1.2")

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

function GP:OnEnable()
    logging:Debug("OnEnable(%s)", self:GetName())
    LibGP:SetScalingConfig(self.db.profile)
    LibGP:SetFormulaInputs(self.db.profile.gp_base, self.db.profile.gp_coefficient_base, self.db.profile.gp_multiplier)
end

function GP:OnInitialize()
    logging:Debug("OnInitialize(%s)", self:GetName())
    -- replace the library string representation function with our utiltiy (more detail)
    LibGP:SetToStringFn(namespace.components.Util.Objects.ToString)
    self.db = namespace.db:RegisterNamespace(self:GetName(), GP.defaults)
end
