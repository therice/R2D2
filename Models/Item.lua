local _, AddOn = ...

local Item = { }
local ItemEntry = { }

AddOn.components.Models.Item = Item
AddOn.components.Models.ItemEntry = ItemEntry

local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local Logging = AddOn.Libs.Logging


--[[
Example Item

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
}
--]]
function Item:New(id, link, quality, ilvl, type, equipLoc, subType, texture, typeId, subTypeId, bindType, classes)
    return {
        ["id"]          = id,
        ["link"]        = link,
        ["quality"]     = quality,
        ["ilvl"]        = ilvl,
        ["type"]        = type,
        ["equipLoc"]    = equipLoc,
        ["subType"]     = subType,
        ["texture"]     = texture,
        ["boe"]         = bindType == LE_ITEM_BIND_ON_EQUIP,
        ["typeId"]      = typeId,
        ["subTypeId"]   = subTypeId,
        ["classes"]     = classes
    }
end

function Item:ToString(item)
    return Util.Objects.ToString(item)
end
function Item:Update(item)
    item["equipLoc"] = select(4, GetItemInfoInstant(item.link))
end

function Item:GetLevelText(item)
    if not item or not item.ilvl then return "" end
    return item.ilvl
end

function Item:GetTypeText(item)
    if not item or not item.link then return "" end
    -- todo : special case trinkets?
    Logging:Debug("%s", Item:ToString(item))

    local id = ItemUtil:ItemLinkToId(item.link)
    if Util.Strings.IsSet(item.equipLoc) and getglobal(item.equipLoc) then
        -- todo : .. " " .. (item.type or "")
        return getglobal(item.equipLoc)
    else
        return item.subType or ""
    end
end

function ItemEntry:Populate(entry, item, slotIndex, owner, awarded, sent)
    entry["lootSlot"] = slotIndex
    entry["owner"] = owner
    entry["awarded"] = awarded
    entry["isSent"] = sent
    if item then Util.Tables.CopyInto(entry, item) end
end