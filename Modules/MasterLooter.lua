local _, AddOn = ...
local ML        = AddOn:NewModule("MasterLooter", "AceEvent-3.0", "AceBucket-3.0", "AceComm-3.0", "AceTimer-3.0", "AceHook-3.0")
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local ItemUtil  = AddOn.Libs.ItemUtil

local db

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
end

function ML:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    db = AddOn.db
    self.lootTable = {}
    self.lootQueue = {}
    self.running = false
end

function ML:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:UnregisterAllEvents()
    self:UnregisterAllBuckets()
    self:UnregisterAllComm()
    self:UnregisterAllMessages()
    self:UnhookAll()
end

function ML:GetItemInfo(item)
    -- https://wow.gamepedia.com/API_GetItemInfo
    local name, link, rarity, ilvl, _, type, subType, _, equipLoc, texture,
    _, typeID, subTypeId, bindType, _, _, _ = GetItemInfo(item)
    local itemId = link and addon:ItemLinkToId(link)
    if name then
        local customItem = ItemUtil:GetCustomItem(itemId)
        return {
            ["link"]        = link,
            ["quality"]     = (customItem and customItem[1]) or rarity,
            ["ilvl"]        = (customItem and customItem[2]) or ilvl,
            ["type"]        = type,
            ["equipLoc"]    = (customItem and customItem[3]) or equipLoc,
            ["subType"]     = subType,
            ["texture"]     = texture,
            ["boe"]         = bindType == LE_ITEM_BIND_ON_EQUIP,
            ["typeID"]      = typeID,
            ["subTypeID"]   = subTypeId,
            ["classes"]     = ItemUtil:GetItemClassesAllowedFlag(link)
        }
    else
        return nil
    end
end