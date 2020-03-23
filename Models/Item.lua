local _, AddOn = ...
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local GP = AddOn.Libs.GearPoints

local Item = { }
Item.__index = Item

local ItemEntry = { }
ItemEntry.__index = ItemEntry

AddOn.components.Models.Item = Item
AddOn.components.Models.ItemEntry = ItemEntry

--[[
Example Item(s)
{
    equipLoc = INVTYPE_CHEST,
    typeId = 4, -- LE_ITEM_CLASS_ARMOR
    type = Armor,
    ilvl = 62,
    link = [Breastplate of Bloodthirst],
    id = 12757,
    subTypeId = 2, -- LE_ITEM_ARMOR_LEATHER
    subType = Leather,
    classes = 4294967295,
    boe = false,
    texture = 132635,
    quality = 4 -- Epic
},
{   equipLoc = INVTYPE_WEAPON,
    typeId = 2,
    type = Weapon,
    ilvl = 63,
    link = [Alcor's Sunrazor],
    id = 14555,
    subTypeId = 15,
    subType = Daggers,
    classes = 4294967295,
    boe = true,
    texture = 135344,
    quality = 4
}
--]]

-- create an Item from invidiual attributes
function Item:New(id, link, quality, ilvl, type, equipLoc, subType, texture, typeId, subTypeId, bindType, classes)
    local instance = {
        id          = id,
        link        = link,
        quality     = quality,
        ilvl        = ilvl,
        typeId      = typeId,
        type        = type,
        equipLoc    = equipLoc,
        subTypeId   = subTypeId,
        subType     = subType,
        texture     = texture,
        boe         = bindType == LE_ITEM_BIND_ON_EQUIP,
        classes     = classes
    }
    return setmetatable(instance, Item)
end

-- create an Item via GetItemInfo
-- item can be a number, name, itemString, or itemLink
-- https://wow.gamepedia.com/API_GetItemInfo
function Item:FromGetItemInfo(item)
    local name, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(item)
    local id = link and ItemUtil:ItemLinkToId(link)
    if name then
        local customItem = ItemUtil:GetCustomItem(itemId)
        return Item:New(
                id,
                link,
                (customItem and customItem[1]) or rarity,
                (customItem and customItem[2]) or ilvl,
                type,
                (customItem and customItem[3]) or equipLoc,
                subType,
                texture,
                typeId,
                subTypeId,
                bindType,
                ItemUtil:GetItemClassesAllowedFlag(link)
        )
    else
        return nil
    end
end

function Item:Clone()
    local copy = Util.Tables.Copy(self)
    return setmetatable(copy, Item)
end

function Item:GetLevelText()
    if not self.ilvl then return "" end
    return tostring(self.ilvl)
end

function Item:GetTypeText()
    -- local id = self.id or ItemUtil:ItemLinkToId(self.link)
    if Util.Strings.IsSet(self.equipLoc) and getglobal(self.equipLoc) then
        -- todo : special case trinkets?
        -- if equipLoc == "INVTYPE_TRINKET" then
        local typeId = self.typeId
        local subTypeId = self.subTypeId
        if self.equipLoc ~= "INVTYPE_CLOAK" and
            (
                not (typeId == LE_ITEM_CLASS_MISCELLANEOUS and subTypeId == LE_ITEM_MISCELLANEOUS_JUNK) and
                not (typeId == LE_ITEM_CLASS_ARMOR and subTypeId == LE_ITEM_ARMOR_GENERIC) and
                not (typeId == LE_ITEM_CLASS_WEAPON and subTypeId == LE_ITEM_WEAPON_GENERIC)
            ) then
            return getglobal(self.equipLoc).. ", ".. (self.subType or "")
        else
            return getglobal(self.equipLoc)
        end
    else
        return self.subType or ""
    end
end

-- @return number
function Item:GetGp()
    -- todo : could do this at initialization time instead
    if not self.gp then
        self.gp = GP:GetValue(self.link)
    end

    return self.gp
end

function Item:GetGpText()
    local gp = self:GetGp()
    gp = gp or 0
    return tostring(gp)
end

--[[
{
    equipLoc = INVTYPE_FINGER,
    type = Armor,
    typeId = 4,
    link = [Mark of the Dragon Lord],
    typeCode = default,
    subType = Miscellaneous,
    quality = 4,
    classes = 4294967295,
    id = 13143,
    subTypeId = 0,
    isSent = false,
    awarded = false,
    boe = false,
    ilvl = 61,
    texture = 133359
}
--]]


-- @param item      ItemID|itemString|itemLink|Item
-- @param slotIndex Index of the entry
-- @param awarded   Has associated item been awarded?
-- @param owner     The owner of the item (if any)
-- @param sent      Has entry been transmitted to others
-- @param typeCode  The associated type code used to determine which set of buttons to use for this entry
function ItemEntry:New(item, slotIndex, awarded, owner, sent, typeCode)
    local instance
    -- already an Item, just clone it
    if type(item) == 'table' then
        instance = item:Clone()
    -- need to create a new item Item instance
    else
        -- Chance we cannot get the item info, if that happens then instantiate a new table
        instance = Item:FromGetItemInfo(item)
        if not instance then instance = {} end
    end

    -- now add the entry attributes
    instance.lootSlot = slotIndex
    instance.awarded = awarded
    instance.owner = owner
    instance.isSent = sent
    instance.typeCode = typeCode

    return setmetatable(instance, ItemEntry)
end

function ItemEntry:Reconstitute(instance)
    return setmetatable(instance, ItemEntry)
end

function ItemEntry:UpdateForTransmit()
    self.equipLoc = select(4, GetItemInfoInstant(self.link))
    --self.typeId = nil
    --self.subTypeId = nil
    return self
end

-- validates item entry is valid, re-populating as necessary
function ItemEntry:Prepare(session)
    if not self:IsValid() then
        Util.Tables.CopyInto(self, Item:FromGetItemInfo(self.link))
    end

    self.session = self.session or session
    return self
end

function ItemEntry:Clone()
    local copy = Util.Tables.Copy(self)
    return setmetatable(copy, ItemEntry)
end

function ItemEntry:IsValid()
    return self.id and self.link
end

function ItemEntry:GetLevelText()
    return Item.GetLevelText(self)
end

function ItemEntry:GetTypeText()
    return Item.GetTypeText(self)
end

function ItemEntry:GetGpText(includeLevel)
    return Item.GetGpText(self, includeLevel)
end

function ItemEntry:GetGp()
    return Item.GetGp(self)
end