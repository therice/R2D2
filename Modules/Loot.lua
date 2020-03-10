local _, AddOn = ...
local Loot      = AddOn:NewModule("Loot", "AceEvent-3.0", "AceTimer-3.0")
local Logging   = AddOn.components.Logging
local UI        = AddOn.components.UI
local L         = AddOn.components.Locale

local ENTRY_HEIGHT = 80

function Loot:AddItem(offset, k, item)
    self.items[offset+k] = {
        link = item.link,
        ilvl = item.ilvl,
        texture = item.texture,
        rolled = false,
        equipLoc = item.equipLoc,
        subType = item.subType,
        typeID = item.typeID,
        subTypeID = item.subTypeID,
        isTier = item.token,
        isRelic = item.relic,
        classes = item.classes,
        sessions = {item.session},
        isRoll = item.isRoll,
        owner = item.owner,
        typeCode = item.typeCode,
    }
end

function Loot:GetFrame()
    if self.frame then return self.frame end
    Logging:Trace("GetFrame() : creating loot frame")
    self.frame = UI:CreateFrame("R2D2_LootFrame", "Loot", L["r2d2_loot_frame"], 250, 375)
    self.frame.title:SetPoint("BOTTOM", self.frame, "TOP", 0 ,-5)
    self.frame.itemTooltip = UI:CreateGameTooltip("Loot", self.frame.content)
    return self.frame
end

function Loot:Show()
    self.frame:Show()
end

do
    local EntryProto = {
        Update = function(entry, item)
            if not item then
                Logging:Warn("EntryProto.Update() : No item provided")
            end

            entry.item = item
        end,
        Show = function(entry) entry.frame:Show() end,
        Hide = function(entry) entry.frame:Hide() end,
        Create = function(entry, parent)
        end,
    }

    local mt = { __index = EntryProto}

    Loot.EntryManager = {
        numEntries = 0,
        entries = {},
        trashPool = {},
    }
end

function Loot:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.items = {} -- item.i = {name, link, lvl, texture} (i == session)
    self.frame = self:GetFrame()
end

function Loot:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:Hide()
    self.items = {}
end
