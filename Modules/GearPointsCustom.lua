local AddOnName, AddOn = ...
local GpCustom = AddOn:NewModule("GearPointsCustom", "AceBucket-3.0", "AceEvent-3.0", "AceHook-3.0")
local ItemUtil = AddOn.Libs.ItemUtil
local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Objects = Util.Objects
local UI = AddOn.components.UI
local COpts = UI.ConfigOptions
local Dialog = AddOn.Libs.Dialog
local GuildStorage = AddOn.Libs.GuildStorage
local ACD = AddOn.Libs.AceConfigDialog

GpCustom.defaults = {
    profile = {
        enabled = true,
        custom_items = {

        },
        ignored_default_items = {
        
        }
    }
}

-- These are arguments for configuring options via UI
-- See UI/Config.lua
GpCustom.options = {
    name = L['gp_custom'],
    desc = L['gp_custom_desc'],
    args = {
        help = COpts.Description(L["gp_custom_help"], nil, 0),
        add = COpts.Execute("Add", 2, "Add a new custom item", function (...) GpCustom:OnAddItemClick(...) end),
        remove = COpts.Execute("Delete", 3, "Delete current custom item", function (...) GpCustom:OnDeleteItemClick(...) end)
    }
}

local Wand, Thrown =
    GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND),
    GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_THROWN)

local EquipmentLocations = {
    INVTYPE_HEAD                                                     = INVTYPE_HEAD,
    INVTYPE_NECK                                                     = INVTYPE_NECK,
    INVTYPE_SHOULDER                                                 = INVTYPE_SHOULDER,
    INVTYPE_CHEST                                                    = INVTYPE_CHEST,
    INVTYPE_WAIST                                                    = INVTYPE_WAIST,
    INVTYPE_LEGS                                                     = INVTYPE_LEGS,
    INVTYPE_FEET                                                     = INVTYPE_FEET,
    INVTYPE_WRIST                                                    = INVTYPE_WRIST,
    INVTYPE_HAND                                                     = INVTYPE_HAND,
    INVTYPE_FINGER                                                   = INVTYPE_FINGER,
    INVTYPE_TRINKET                                                  = INVTYPE_TRINKET,
    INVTYPE_CLOAK                                                    = INVTYPE_CLOAK,
    INVTYPE_WEAPON                                                   = L["%s %s"]:format(_G.INVTYPE_WEAPON, _G.WEAPON),
    INVTYPE_SHIELD                                                   = SHIELDSLOT,
    INVTYPE_2HWEAPON                                                 = L["%s %s"]:format(_G.INVTYPE_2HWEAPON, _G.WEAPON),
    INVTYPE_WEAPONMAINHAND                                           = L["%s %s"]:format(_G.INVTYPE_WEAPONMAINHAND, _G.WEAPON),
    INVTYPE_WEAPONOFFHAND                                            = L["%s %s"]:format(_G.INVTYPE_WEAPONOFFHAND, _G.WEAPON),
    INVTYPE_HOLDABLE                                                 = INVTYPE_HOLDABLE,
    INVTYPE_RANGED                                                   = INVTYPE_RANGED,
    INVTYPE_WAND                                                     = Wand,
    INVTYPE_THROWN                                                   = Thrown,
    INVTYPE_RELIC                                                    = INVTYPE_RELIC,
    CUSTOM_SCALE                                                     = L["custom_scale"],
    CUSTOM_GP                                                        = L["custom_gp"],
}

local EquipmentLocationsSort, NoGuild, selectedItem = {}, "No Guild", nil

do
    for i, v in pairs(Tables.ASort(EquipmentLocations, function(a,b) return a[2] < b[2] end)) do
        EquipmentLocationsSort[i] = v[1]
    end
end

function GpCustom:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.Libs.AceDB:New('R2D2_CustomItems', GpCustom.defaults, NoGuild)
end

function GpCustom:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    
    if IsInGuild() then
        GuildStorage.RegisterCallback(
                self,
                GuildStorage.Events.GuildNameChanged,
                function()
                    GuildStorage.UnregisterCallback(self, GuildStorage.Events.GuildNameChanged)
                    GpCustom:PerformEnable()
                end
        )
    else
        self:PerformEnable()
    end
end

function GpCustom:PerformEnable()
    Logging:Debug("PerformEnable(%s) : %s", self:GetName(), tostring(GuildStorage:GetGuildName()))
    
    self.db:SetProfile(GuildStorage:GetGuildName() and GuildStorage:GetGuildName() or NoGuild)
    self:AddDefaultCustomItems()
    ItemUtil:SetCustomItems(self.db.profile.custom_items)
    self:RegisterBucketMessage(AddOn.Constants.Messages.ConfigTableChanged, 5, "ConfigTableChanged")
    
    Logging:Debug("OnInitialize(%s) : custom item count = %s", self:GetName(), Tables.Count(self.db.profile.custom_items))
end

function GpCustom:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:UnregisterAllBuckets()
    ItemUtil:ResetCustomItems()
end

function GpCustom:AddDefaultCustomItems()
    local config = self.db.profile
    if not config.custom_items then
        config.custom_items = Tables.New()
    end
    local custom_items = config.custom_items
    local ignored_default_items = config.ignored_default_items
    
    local faction = UnitFactionGroup("player")
    local defaultCustomItems = AddOn:GetDefaultCustomItems()
    
    if Tables.Count(defaultCustomItems) > 0 then
        for id, value in Objects.Each(defaultCustomItems) do
            -- make sure the item applies to player's faction
            if not Objects.IsSet(value[4]) or Objects.Equals(value[4], faction) then
                local id_key = tostring(id)
                if not custom_items[id_key] and not ignored_default_items[id_key] then
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

local function AddItemToConfigOptions(options, id)
    local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(id)
    if name then
        -- Logging:Debug('AddItemToConfigOptions() : Adding %s (%s)', link, id)
        local custom_item_args = Tables.New()
        custom_item_args['custom_items.'..id..'.header'] = COpts.Description(link, 'large', 0, { image=texture })
        --custom_item_args['custom_items.'..id..'.header'] = COpts.Execute(
        --        name, 0, link,
        --        function()
        --            ACD.tooltip:SetHyperlink(link)
        --            ACD.tooltip:Show()
        --            --
        --            --if UI.tooltip and UI.tooltip.showing then
        --            --    UI:HideTooltip()
        --            --else
        --            --    UI:CreateHypertip(link)
        --            --end
        --        end,
        --        { image = texture }
        --)
        custom_item_args['custom_items.'..id..'.filler'] = COpts.Header('', nil, 1)
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
        custom_item_args['custom_items.'..id..'.equip_location'] = COpts.Select(L['equipment_loc'], 4,  L['equipment_loc_desc'], EquipmentLocations, nil, nil, {width='double', sorting=EquipmentLocationsSort})
        custom_item_args['custom_items.'..id..'.scale'] = COpts.Range(
                L["slot_multiplier"], 5, 0, 5, nil,
                {
                    width='double',
                    hidden = function ()
                        local item = GpCustom.db.profile.custom_items[tostring(id)]
                        return item and item.equip_location ~= 'CUSTOM_SCALE' or false
                    end
                }
        )
        custom_item_args['custom_items.'..id..'.gp'] = COpts.Range(
                L["gp"], 6, 0, 250, nil,
                {
                    width = 'double',
                    hidden = function ()
                        local item = GpCustom.db.profile.custom_items[tostring(id)]
                        return item and item.equip_location ~= 'CUSTOM_GP' or false
                    end
                }
        )
        
        options[id] = {
            type = 'group',
            name = name,
            icon = texture,
            get = function(i)
                selectedItem = Util.Strings.Split(tostring(i[#i]), '.')[2]
                -- Logging:Debug("get(%s)", tostring(i[#i]))
                return AddOn.GetDbValue(GpCustom, i)
            end,
            hidden = function ()
                local item = GpCustom.db.profile.custom_items[tostring(id)]
                -- Logging:Debug("%d = %s", id, Objects.ToString(item))
                if item == nil then return true else return false end
            end,
            args = custom_item_args,
        }
    else
        Logging:Trace('AddItemToConfigOptions() : Item %s not available, submitting query', id)
        ItemUtil:QueryItemInfo(id, function() AddItemToConfigOptions(options, id) end)
    end
end

function GpCustom:BuildConfigOptions()
    local options = Util.Tables.Copy(self.options)
    for _, id in Objects.Each(Tables.Sort(Tables.Keys(self.db.profile.custom_items))) do
        AddItemToConfigOptions(options.args, id)
    end
    return options
end

function GpCustom:ConfigTableChanged(msg)
    Logging:Trace("ConfigTableChanged() : '%s", Util.Objects.ToString(msg))
    ItemUtil:SetCustomItems(self.db.profile.custom_items)
end

function GpCustom:OnAddItemClick(...)
    local f = self:GetAddItemFrame()
    f.Reset()
    f:Show()
end

function GpCustom:AddItem(item)
    Logging:Debug("AddItem() : %s", Util.Objects.ToString(item))
    local id = item['id']
    if id then
        -- remove id from table, don't want to store it
        item['id'] = nil
        AddOn.SetDbValue(GpCustom, {'custom_items.'.. id}, item)
        AddOn.Libs.AceConfigRegistry:NotifyChange("R2D2")
    end
end

function GpCustom:GetAddItemFrame()
    if self.addItemFrame then return self.addItemFrame end
    
    local f = UI:CreateFrame("R2D2_Add_Custom_Item", "AddCustomItem", L["r2d2_add_custom_item_frame"], 150, 200, false)
    f:SetWidth(225)
    f:SetPoint("TOPRIGHT", ACD.OpenFrames[AddOnName].frame, "TOPLEFT", 150)
    
    function f.Reset()
        f.itemName.Reset()
        f.itemIcon.Reset()
        f.itemLvl.Reset()
        f.itemType.Reset()
        f.item = nil
        f.add:Disable()
    end
    
    function f.Query()
        f.Reset()
        
        local itemId = f.queryInput:GetText()
        Logging:Debug("Query(%s)", tostring(itemId))
    
        local function query(id)
            local name, link, rarity, ilvl, _, _, subType, _, equipLoc, texture= GetItemInfo(itemId)
            Logging:Trace(
                    "%s => %s, %s, %s, %s, %s, %s",
                    tostring(itemId), tostring(link), tostring(rarity), tostring(ilvl),
                    tostring(subType), tostring(equipLoc), tostring(EquipmentLocations[equipLoc])
            )
            if name then
    
                if Util.Strings.Equal(subType, Wand) then equipLoc = "INVTYPE_WAND" end
                if Util.Strings.Equal(equipLoc, "INVTYPE_RANGEDRIGHT") then equipLoc = "INVTYPE_RANGED" end
                if not EquipmentLocations[equipLoc] then equipLoc = "CUSTOM_SCALE" end
                
                f.item = {
                    id = itemId,
                    rarity = rarity or 4,
                    item_level = ilvl or 0,
                    equip_location = equipLoc,
                    default = false,
                }
                
                f.itemName.Set(name, f.item.rarity)
                f.itemIcon.Set(link, texture)
                f.itemLvl.Set(f.item.item_level)
                f.itemType.Set(f.item.equip_location)
                f.add:Enable()
            else
                ItemUtil:QueryItemInfo(id, function() query(id) end)
            end
        end
        
        if not itemId or not tonumber(itemId) then
            f.itemName:SetText(UI.ColoredDecorator(0.77,0.12,0.23,1):decorate(L['invalid_item_id']))
            f.itemName:Show()
        else
            query(itemId)
        end
    end
    
    local itemName = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("CENTER", f.content, "TOP", 0, -25)
    f.itemName = itemName
    function f.itemName.Reset()
        f.itemName:SetText(nil)
        f.itemName:Hide()
    end
    function f.itemName.Set(name, rarity)
        f.itemName:SetText(UI.ColoredDecorator(GetItemQualityColor(rarity)):decorate(name))
        f.itemName:Show()
    end
    
    local itemIcon = UI:New("IconBordered", f.content)
    itemIcon:SetPoint("TOPLEFT", f.content, "TOPLEFT", 10, -35)
    f.itemIcon = itemIcon
    function f.itemIcon.Reset()
        f.itemIcon:SetNormalTexture("Interface\\InventoryItems\\WoWUnknownItem01")
        f.itemIcon:SetScript("OnEnter", nil)
        f.itemIcon:SetScript("OnLeave", nil)
    end
    function f.itemIcon.Set(link, texture)
        f.itemIcon:SetNormalTexture(texture)
        f.itemIcon:SetScript("OnEnter", function() UI:CreateHypertip(link) end)
        f.itemIcon:SetScript("OnLeave", function() UI:HideTooltip() end)
    end
    
    local queryLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queryLabel:SetPoint("LEFT", f.itemIcon, "RIGHT", 5, 0)
    queryLabel:SetText(L["item_id"])
    f.queryLabel = queryLabel

    local queryInput = UI:New("EditBox", f.content)
    queryInput:SetHeight(20)
    queryInput:SetWidth(50)
    queryInput:SetPoint("LEFT", f.queryLabel, "RIGHT", 10, 0)
    f.queryInput = queryInput


    local queryExecute = UI:CreateButton("", f.content)
    queryExecute:SetSize(25, 25)
    queryExecute:SetPoint("LEFT", f.queryInput, "RIGHT", 10, 0)
    queryExecute:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    queryExecute:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    queryExecute:SetScript("OnClick", function () f.Query() end)
    f.queryExecute = queryExecute
    
    local itemLvlLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLvlLabel:SetPoint("TOPLEFT", f.itemIcon, "TOPLEFT", 5, -55)
    itemLvlLabel:SetText(L["item_lvl"])
    f.itemLvlLabel = itemLvlLabel
    
    local itemLvl = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLvl:SetPoint("LEFT", f.itemLvlLabel, "RIGHT", 10, 0)
    itemLvl:SetTextColor(1, 1, 1, 1)
    f.itemLvl = itemLvl
    function f.itemLvl.Reset()
        f.itemLvlLabel:Hide()
        f.itemLvl:SetText(nil)
        f.itemLvl:Hide()
    end
    function f.itemLvl.Set(lvl)
        f.itemLvlLabel:Show()
        f.itemLvl:SetText(tostring(lvl))
        f.itemLvl:Show()
    end
    
    local itemTypeLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemTypeLabel:SetPoint("TOPLEFT", f.itemLvlLabel, "TOPLEFT", 0, -25)
    itemTypeLabel:SetText(L["equipment_loc"])
    f.itemTypeLabel = itemTypeLabel
    
    local itemType = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemType:SetPoint("LEFT", f.itemTypeLabel, "RIGHT", 10, 0)
    itemType:SetTextColor(1, 1, 1, 1)
    f.itemType = itemType
    function f.itemType.Reset()
        f.itemTypeLabel:Hide()
        f.itemType:SetText(nil)
        f.itemType:Hide()
    end
    function f.itemType.Set(equipLoc)
        f.itemTypeLabel:Show()
        f.itemType:SetText(EquipmentLocations[equipLoc])
        f.itemType:Show()
    end
    
    
    local close = UI:CreateButton(_G.CANCEL, f.content)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -13, 5)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    local add = UI:CreateButton(_G.ADD, f.content)
    add:SetPoint("RIGHT", f.close, "LEFT", -25)
    add:SetScript("OnClick", function() self:AddItem(f.item); f:Hide() end)
    f.add = add
    
    self.addItemFrame = f
    return self.addItemFrame
end

-- custom item deletion
function GpCustom:OnDeleteItemClick(...)
    Dialog:Spawn(AddOn.Constants.Popups.ConfirmDeleteItem, selectedItem)
end

function GpCustom.DeleteItemOnShow(frame, item)
    UI.DecoratePopup(frame)
    -- the info should be available, because deleting an already displayed item
    -- therefore, no need to check if link is set
    local _, link = GetItemInfo(item)
    frame.text:SetText(format(L['confirm_delete_item'], link))
end

function GpCustom.DeleteItemOnClickYes(frame, item)
    Logging:Debug("DeleteItemOnClickYes(%s)", tostring(item))
    
    item = tostring(item)
    local existing_item = GpCustom.db.profile.custom_items[item]
    if existing_item and existing_item.default then
        GpCustom.db.profile.ignored_default_items[item] = true
    end
    -- could do this, but don't get the callback for configuration change
    -- GpCustom.db.profile.custom_items[item] = nil
    AddOn.SetDbValue(GpCustom, {'custom_items.'..item}, nil)
    AddOn.Libs.AceConfigRegistry:NotifyChange("R2D2")
end

function GpCustom.DeleteItemOnClickNo()
    -- intentionally left blank
end