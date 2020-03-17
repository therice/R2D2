local _, AddOn = ...

local Item = { }
local ItemEntry = { }

AddOn.components.Models.Item = Item
AddOn.components.Models.ItemEntry = ItemEntry

local Util = AddOn.Libs.Util

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

function ItemEntry:Populate(entry, item, slotIndex, owner, awarded, sent)
    entry["lootSlot"] = slotIndex
    entry["owner"] = owner
    entry["awarded"] = awarded
    entry["isSent"] = sent
    if item then Util.Tables.CopyInto(entry, item) end
end