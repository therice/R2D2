local _, AddOn = ...
local Util = AddOn.Libs.Util
local Class = AddOn.Libs.Class
local ItemUtil = AddOn.Libs.ItemUtil
local GP = AddOn.Libs.GearPoints

local Item = Class('Item')
local ItemEntry = Class('ItemEntry', Item)
local ItemAward = Class('ItemAward')
local LootEntry = Class('LootEntry', ItemEntry)
local AllocateEntry = Class('AllocateEntry', ItemEntry)

AddOn.components.Models.Item = Item
AddOn.components.Models.ItemEntry = ItemEntry
AddOn.components.Models.ItemAward = ItemAward
AddOn.components.Models.LootEntry = LootEntry
AddOn.components.Models.AllocateEntry = AllocateEntry

--
-- Item
--
-- This is intended to be a wrapper around item information obtained via native APIs, with additional attributes
-- such as classes which can use
--

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

function Item:initialize(id, link, quality, ilvl, type, equipLoc, subType, texture, typeId, subTypeId, bindType, classes)
    self.id          = id
    self.link        = link
    self.quality     = quality
    self.ilvl        = ilvl
    self.typeId      = typeId
    self.type        = type
    self.equipLoc    = equipLoc
    self.subTypeId   = subTypeId
    self.subType     = subType
    self.texture     = texture
    self.boe         = (bindType == LE_ITEM_BIND_ON_EQUIP)
    self.classes     = classes
    self.gp          = nil -- this is the base GP value of the item (as calculated using LibGearPoints)
end

-- create an Item via GetItemInfo
-- item can be a number, name, itemString, or itemLink
-- https://wow.gamepedia.com/API_GetItemInfo
function Item:FromGetItemInfo(item)
    local name, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(item)
    local id = link and ItemUtil:ItemLinkToId(link)
    if name then
        -- check to see if a custom item has been setup for the id
        -- which overrides anything provided by API
        local customItem = ItemUtil:GetCustomItem(id)
        return Item:new(
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

function Item:IsValid()
    return ((self.id and self.id > 0) and Util.Strings.IsSet(self.link))
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

-- @param awardReason an optional number, which indicates the user's response for which the item is being awarded
-- @return tuple of numbers : BASE_GP, AWARD_GP (nil if no awardReason specified)
function Item:GetGp(awardReason)
    if not self.gp then
        self.gp = GP:GetValue(self.link)
    end
    
    local awardGp
    if awardReason then
        local awardScale = AddOn:GearPointsModule():GetAwardScale(awardReason)
        if awardScale then
            awardGp = math.floor(self.gp * awardScale)
        end
    end
    
    return self.gp, awardGp
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

--
-- ItemEntry
--
-- Extends Item with support for additional attributes required to represent the item
-- as an entry during the allocation process (which isn't associated with a specific candidate)
--

-- @param item      ItemID|itemString|itemLink|Item
-- @param lootSlot  Index of the item within the loot table
-- @param awarded   Has associated item been awarded?
-- @param owner     The owner of the item (if any)
-- @param sent      Has entry been transmitted to others
-- @param typeCode  The associated type code used to determine which set of buttons to use for this entry
function ItemEntry:initialize(item, bagged, lootSlot, awarded, owner, sent, typeCode, isRoll)
    if not item then return end

    if type(item) ~= 'table' then
        item = Item:FromGetItemInfo(item)
        -- if it couldn't be created, just set to an empty instance
        if not item then
            item = Item:new()
        end
    end
    Item.initialize(self,
            item.id,
            item.link,
            item.quality,
            item.ilvl,
            item.type,
            item.equipLoc,
            item.subType,
            item.texture,
            item.typeId,
            item.subTypeId,
            item.boe,
            item.classes
    )

    -- now add the entry attributes
    self.bagged = bagged
    self.lootSlot = lootSlot
    self.awarded = awarded
    self.owner = owner
    self.isSent = sent
    self.typeCode = typeCode
    self.isRoll = isRoll
end

function ItemEntry:UpdateForTransmit()
    -- if no equipment location set and we have a link
    -- then update it
    if not self.equipLoc and self.link then
        self.equipLoc = select(4, GetItemInfoInstant(self.link))
    end
    -- todo : nil these out?
    -- self.typeId = nil
    -- self.subTypeId = nil
    return self
end

-- validates item entry is valid, re-populating as necessary
-- then associates passed session if not set
function ItemEntry:Validate(session)
    -- if we're missing necessary item data, bring it in
    if not self:IsValid() then
        Util.Tables.CopyInto(self, Item:FromGetItemInfo(self.link))
    end

    self.session = self.session or session
    return self
end

-- converts an ItemEntry into a table which is suitable for displaying in LootSession UI
-- this doesn't return an instance with metatable set, just a simple table
function ItemEntry:ToRow(session, cols)
    local row = {
        session = session,
        texture = self.texture or nil,
        link = self.link,
        owner = self.owner,
        cols = cols
    }
    return row
end

function ItemEntry:ToLootEntry(timeout)
    return LootEntry:new(self, timeout)
end

function ItemEntry:ToAllocateEntry()
    return AllocateEntry:new(self)
end

local function CreateItemEntry(self, data, callback)
    if data and type(data) == 'table' then
        ItemEntry.initialize(
                self,
                -- this is going to pull along extra attributes, but the super constructor will
                -- ignore them and take remainder from parameters
                data:toTable(),
                data.bagged,
                data.lootSlot,
                data.awarded,
                data.owner,
                data.isSent,
                data.typeCode,
                data.isRoll
        )

        if callback then callback() end
    end
end

--
-- LootEntry
--
-- Extends ItemEntry with support for additional attributes required to present the
-- entry to candidates for stating interest (need, greed, etc.)
--
function LootEntry:initialize(itemEntry, timeout)
    CreateItemEntry(self, itemEntry,
            function()
                self.rolled = false
                self.note = nil
                self.sessions = itemEntry.session and { itemEntry.session } or {}
                self.timeLeft = timeout and timeout or false
            end
    )
end

-- return an instance with only rolled attribute, set to true
function LootEntry.Rolled()
    local instance = LootEntry:new()
    instance.rolled = true
    return instance
end

--
-- AllocateEntry
--
-- Extends ItemEntry with support for additional attributes required to allocate (award) the
-- associated item to a character
--

function AllocateEntry:initialize(itemEntry)
    CreateItemEntry(self, itemEntry,
            function()
                self.added = false
                self.candidates = {}
            end
    )
end

function AllocateEntry:GetItemAward(session, candidate, reason)
    return ItemAward(self, session, candidate, reason)
end

function AllocateEntry:GetReRollData(session, isRoll, noAutopass)
    return {
        session     = session,
        link        = self.link,
        ilvl        = self.ilvl,
        texture     = self.texture,
        equipLoc    = self.equipLoc,
        classes     = self.classes,
        isRoll      = isRoll,
        noAutopass  = noAutopass,
        owner       = self.owner,
        typeCode    = self.typeCode,
    }
end

function AllocateEntry:GetCandidateResponse(name)
    return self.candidates[name]
end

function AllocateEntry:AddCandidateResponse(name, class, rank)
    self.candidates[name] =
        AddOn.components.Models.CandidateResponse:new(name, class, rank)
end

--
-- ItemAward
--
-- Contains the data necessary for attempting an item award. It doesn't infer anything about whether the award
-- was successful
--

function ItemAward:initialize(allocation, session, candidate, reason)
    if not allocation or not AllocateEntry.isInstanceOf(allocation, AllocateEntry) then
        error("The specified 'allocation' instance was not of type AllocateEntry : " .. type(allocation))
    end

    -- CandidateResponse instance
    local cr = allocation.candidates[candidate]
    local awardReason, baseGp, awardGp = nil, nil, nil
    -- if there was a reason provided, it will have the award scale key/reason
    if reason and Util.Objects.IsTable(reason) then
        awardReason = reason.award_scale
    -- otherwise, get the award scale key/reason from response
    else
        awardReason = AddOn:GetResponse(self.typeCode or self.equipLoc, cr.response).award_scale
    end
    
    baseGp, awardGp = allocation:GetGp(awardReason)

    self.session = session
    self.winner = candidate
    self.class = cr.class
    self.responseId = cr.response
    self.reason = reason
    self.gear1 = cr.gear1
    self.gear2 = cr.gear2
    self.link = allocation.link
    self.baseGp = baseGp
    self.awardGp = awardGp
    self.awardReason = awardReason
    self.awardScale = AddOn:GearPointsModule():GetAwardScale(awardReason)
    self.isToken = allocation.token
    self.note = cr.note
    self.equipLoc = allocation.equipLoc
    self.typeCode = allocation.typeCode
    self.texture = allocation.texture
    -- normalized response based upon combination of response / reason
    -- this is super unpleasant and should be consolidated into one set of attributes
    -- which is set consistently and used consistently
    self.normalizedResponse = {
        id    = nil,
        text  = nil,
        color = nil
    }
end

function ItemAward:GetGp()
    return self.awardGp and self.awardGp or self.baseGp
end

function ItemAward:NormalizedResponse()
    if not self.normalizedResponse.id then
        local response = AddOn:GetResponse(self.typeCode or self.equipLoc, self.responseId)
        self.normalizedResponse.id = self.reason and self.reason.sort - 400 or self.responseId
        self.normalizedResponse.text = self.reason and self.reason.text or response.text
        self.normalizedResponse.color = self.reason and self.reason.color or response.color
    end
    
    return self.normalizedResponse
end
