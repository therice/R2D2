local _, AddOn = ...
local GP = AddOn:NewModule("GearPoints", "AceHook-3.0", "AceEvent-3.0")
local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Objects = Util.Objects
local COpts = AddOn.components.UI.ConfigOptions
local LibGP = AddOn.Libs.GearPoints
local UI = AddOn.components.UI
local Award = AddOn.components.Models.Award

local DisplayName = {}
DisplayName.OneHWeapon  = L["%s %s"]:format(_G.INVTYPE_WEAPON, _G.WEAPON)
DisplayName.TwoHWeapon  = L["%s %s"]:format(_G.INVTYPE_2HWEAPON, _G.WEAPON)
DisplayName.MainHWeapon = L["%s %s"]:format(_G.INVTYPE_WEAPONMAINHAND, _G.WEAPON)
DisplayName.OffHWeapon  = L["%s %s"]:format(_G.INVTYPE_WEAPONOFFHAND, _G.WEAPON)

GP.defaults = {
    profile = {
        enabled = true,
        -- this is the minimum value for GP
        gp_min = 1,
        formula = {
            gp_base             = 4.8,
            gp_coefficient_base = 2.5,
            gp_multiplier       = 1,

        },
        -- todo : remove silly suffixes and comment value, no need for multiple entires by slot
        slot_scaling = {
            head_scale_1            = 1,
            head_comment_1          = _G.INVTYPE_HEAD,
            neck_scale_1            = 0.5,
            neck_comment_1          = _G.INVTYPE_NECK,
            shoulder_scale_1        = 0.75,
            shoulder_comment_1      = _G.INVTYPE_SHOULDER,
            chest_scale_1           = 1,
            chest_comment_1         = _G.INVTYPE_CHEST,
            waist_scale_1           = 0.75,
            waist_comment_1         = _G.INVTYPE_WAIST,
            legs_scale_1            = 1,
            legs_comment_1          = _G.INVTYPE_LEGS,
            feet_scale_1            = 0.75,
            feet_comment_1          = _G.INVTYPE_FEET,
            wrist_scale_1           = 0.5,
            wrist_comment_1         = _G.INVTYPE_WRIST,
            hand_scale_1            = 0.75,
            hand_comment_1          = _G.INVTYPE_HAND,
            finger_scale_1          = 0.5,
            finger_comment_1        = _G.INVTYPE_FINGER,
            trinket_scale_1         = 0.75,
            trinket_comment_1       = _G.INVTYPE_TRINKET,
            cloak_scale_1           = 0.5,
            cloak_comment_1         = _G.INVTYPE_CLOAK,
            shield_scale_1          = 0.5,
            shield_comment_1        = _G.SHIELDSLOT,
            weapon_scale_1          = 1.5,
            weapon_comment_1        = DisplayName.OneHWeapon,
            weapon2h_scale_1        = 2,
            weapon2h_comment_1      = DisplayName.TwoHWeapon,
            weaponmainh_scale_1     = 1.5,
            weaponmainh_comment_1   = DisplayName.MainHWeapon,
            weaponoffh_scale_1      = 0.5,
            weaponoffh_comment_1    = DisplayName.OffHWeapon,
            holdable_scale_1        = 0.5,
            holdable_comment_1      = _G.INVTYPE_HOLDABLE,
            -- Bows, Crossbows, Guns (could split them up if merited, but they all seems to be considered equal)
            ranged_scale_1          = 1.5,
            ranged_comment_1        = _G.INVTYPE_RANGED,
            wand_scale_1            = 0.5,
            wand_comment_1          = GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND),
            thrown_scale_1          = 0.5,
            thrown_comment_1        = GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_THROWN),
            relic_scale_1           = 0.667,
            relic_comment_1         = _G.INVTYPE_RELIC,
        },
        -- scale is the percentage of GP to give to character for that type of award
        -- user_visible determines if the award type is presented as option to user for loot response
        -- color determines how the response is displayed in game if available to user
        --
        -- each entry here that is user visible will be presented to player as a response option
        -- when loot is available for award
        award_scaling = {
            ms_need  = {
                scale = 1,
                user_visible = true,
                color = {0,1,0.59,1},
            },
            os_greed = {
                scale = 0.5,
                user_visible = true,
                color = {1,0.96,0.41,1},
            },
            minor_upgrade = {
                scale = 0.75,
                user_visible = true,
                color = {0.96,0.55,0.73,1},
            },
            pvp = {
                scale = 0.25,
                user_visible = true,
                color = {0.77,0.12,0.23,1},
            },
            disenchant = {
                scale = 0,
                user_visible = false,
                color = {0.25, 0.78, 0.92, 1},
            },
            bank = {
                scale = 0,
                user_visible = false,
                color = {0.53, 0.53, 0.93, 1},
            },
            free = {
                scale = 0,
                user_visible = false,
                color = {0, 0.44, 0.87, 1},
            }
        }
    }
}

GP.DefaultAwardColor = GP.defaults.profile.award_scaling.ms_need.color

-- These are arguments for configuring options via UI
-- See UI/Config.lua
GP.options = {
    name = L['gp'],
    desc = L['gp_desc'],
    args = {
        help = COpts.Description(L["gp_help"], nil, 9),
        headerEquation = COpts.Header(L["equation"], nil, 10),
        equation = {
            order = 11,
            type = "group",
            inline = true,
            name = "",
            args = {
                -- http://www.epgpweb.com/help/gearpoints
                help = COpts.Description("|cfffcd400GP = base * (coefficient ^ ((item_level / 26) + (item_rarity - 4)) * equipment_slot_multiplier) * multiplier|r", "medium"),
                ["formula.gp_base"] = COpts.Range("base", 2, 1, 1000),
                ["formula.gp_coefficient_base"] = COpts.Range("coefficient", 3, 1, 100),
                ["formula.gp_multiplier"] = COpts.Range("multiplier", 4, 1, 100),
            },
        },
        awardHeader = COpts.Header(L["awards"], nil, 20),
        awards = {
            order = 21,
            type = "group",
            inline = true,
            name = "",
            args = {
                help = COpts.Description(L["award_scaling_help"], "medium"),
            }
        },
        slotsHeader = COpts.Header(L["equipment_slots"], nil, 40),
        slotsHelp = COpts.Description(L["equipment_slots_help"], "medium", 41),
    }
}

-- mappings from slot to description for ones that are more complex/nuanced than a single
-- constant
local EquipmentSlotDescription = {
    ['ranged'] =
        Util.Strings.Join(', ',
          GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_BOWS),
          GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_CROSSBOW),
          GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GUNS)
        )
}

do
    local awardScalingDefaults = GP.defaults.profile.award_scaling
    -- capture a reference to GP configuration option's arguments
    -- this is where we'll be adding the dynamic settings
    local aargs = GP.options.args.awards.args

    for award, _ in pairs(awardScalingDefaults) do
        aargs['award_scaling.' .. award .. '.scale'] = COpts.Range(L[award], 1, 0, 1, 0.01, {isPercent = true, width = 'double', desc=format(L["award_scaling_for_reason"], L[award])})
    end

    local scalingDefaults = GP.defaults.profile.slot_scaling
    -- table for storing processed defaults which needed added as arguments
    local slotArgs = Tables.New()

    -- iterate the keys in alphabetical order
    for _, key in Objects.Each(Tables.Sort(Tables.Keys(scalingDefaults))) do
        -- e.g ranged_comment_1, ranged_comment_1
        local parts = {strsplit('_', key)}
        -- only deal with key(s) that have 3 parts and contain 'scale' and 'comment'
        if #parts == 3 and Objects.In(parts[2], 'scale', 'comment') then
            local slot = parts[1] -- this will be the slot name, e.g. 'weapon', 'ranged', 'head'
            local slot_input = parts[2] -- this will be the input name, e.g. 'scale', 'comment'
            local slotTable = slotArgs[slot] or Tables.New()

            if slot_input == 'scale' then
                slotTable[key] = COpts.Range(L["slot_multiplier"], 2, 0, 5, nil, {width='double'})
            elseif slot_input == 'comment' then
                local displayName = scalingDefaults[key]
                slotTable['displayname'] = displayName
                slotTable['help'] = COpts.Description(displayName)
                slotTable[key] = COpts.Input(L['slot_comment'], 3, {width='double'})
            end

            slotArgs[slot] = slotTable
        end
    end

    -- capture a reference to GP configuration option's arguments
    -- this is where we'll be adding the dynamic settings
    local gpargs = GP.options.args

    local order = 42
    for _, slotArray in pairs(Tables.ASort(slotArgs, function(a,b) return a[2].displayname < b[2].displayname end)) do
        local slot = slotArray[1]
        local displayname = slotArray[2].displayname
        local description =  L["item_slot_with_name"]:format(displayname)
        if EquipmentSlotDescription[slot] then
            description = EquipmentSlotDescription[slot]
        end
        
        gpargs[slot] = {
            order = order,
            type = "group",
            name = displayname,
            desc = description,
            -- the mapping of keys to include the 'scaling.' prefix is to map into the db properly
            -- not everything needs prefixed, but these won't be stored (e.g. help)
            args =  Tables.MapKeys(Tables.CopyUnselect(slotArgs[slot], 'displayname'),  function(key) return 'slot_scaling.'..key end)
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
    AddOn:SyncModule():AddHandler(
            self:GetName(),
            format("%s %s", L['gp'], L['settings']),
            function() return self.db.profile end,
            function(data) self:ImportData(data) end
    )
end

function GP:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    LibGP:SetScalingConfig(self.db.profile.slot_scaling)
    LibGP:SetFormulaInputs(
            self.db.profile.formula.gp_base,
            self.db.profile.formula.gp_coefficient_base,
            self.db.profile.formula.gp_multiplier
    )
end

-- @param awardReason the reason (string) that an item was awarded (e.g. ms_need)
-- @return the award_scaling entry for the specified reason
local function AwardReasonToKey(awardReason)
    if not awardReason then return end
    if not Objects.IsString(awardReason) then error("Award Reason must be a 'string' (the award_scaling name)") end
    
    if not Util.Tables.Search(
            GP.db.profile.award_scaling,
            function(_, key)
                return key == awardReason
            end
    ) then
        awardReason = nil
    end
    
    return awardReason
end

function GP:GetAwardColor(awardReason)
    awardReason = AwardReasonToKey(awardReason)
    if not awardReason then return GP.DefaultAwardColor end
    -- Logging:Debug("GetAwardColor(%s)", tostring(awardReason))
    local award = self.db.profile.award_scaling[awardReason]
    if award and award.color then
        return award.color
    end
end

function GP:GetAwardScale(awardReason)
    awardReason = AwardReasonToKey(awardReason)
    if not awardReason then return end
    -- Logging:Debug("GetAwardScale(%s)", tostring(awardReason))
    local award = self.db.profile.award_scaling[awardReason]
    if award and award.scale then
        return tonumber(award.scale)
    end
end


---@param item any instance of Models.Item
---@param awardReason string the award reason key for award_scaling table (can be nil)
---@return string representation of GP, including any scale for award (if specified)
function GP:GetGpTextColored(item, awardReason)
    local baseGp, awardGp = item:GetGp(awardReason)
    local text = UI.ColoredDecorator(GP.DefaultAwardColor):decorate(tostring(baseGp))
    if awardGp and awardGp > 0 then
        awardGp = UI.ColoredDecorator(self:GetAwardColor(awardReason)):decorate(tostring(awardGp))
        text = awardGp .. "(" .. text .. ")"
    end
    return text
end


-- @param itemAward instance as generated via LootAllocate:GetAwardPopupData (which is of type ItemAward)
function GP:OnAwardItem(itemAward)
    if not itemAward then error('No item award provided') end
    
    Logging:Debug("OnAwardItem : %s", Objects.ToString(itemAward, 3))
    local award = Award()
    award:SetSubjects(Award.SubjectType.Character, itemAward.winner)
    award:SetAction(Award.ActionType.Add)
    award:SetResource(Award.ResourceType.Gp, itemAward:GetGp())
    
    -- set a description on award based upon response
    local response = itemAward:NormalizedResponse()
    award.description = format(L["awarded_item_for_reason"], itemAward.link,
                                UI.ColoredDecorator(response.color):decorate(response.text))
    
    -- set reference to item for award, which will be used for any history
    award.item = itemAward
    
    -- confirmation is already done at this point, no need to prompt again
    AddOn:PointsModule():Adjust(award)
end