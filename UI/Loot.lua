local _, AddOn = ...
local Loot      = AddOn:NewModule("Loot", "AceEvent-3.0", "AceTimer-3.0")
local Logging   = AddOn.components.Logging
local UI        = AddOn.components.UI

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
    Logging:Debug("GetFrame() : creating loot frame")
    self.frame =
        UI("Frame", "R2D2_LootFrame")
            .SetTitle("R2D2 Loot Frame")
            .SetHeight(250).SetWidth(375)()
    self.frame.itemTooltip = UI.CreateGameTooltip("R2D2_LootFrame", self.frame.content)
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
            entry.width = parent:GetWidth()
            entry.frame = UI("Frame", "Default_R2D2_LootFrame_Entry("..Loot.EntryManager.numEntries..")", parent)
                .SetWidth(entry.width)
                .SetHeight(ENTRY_HEIGHT)
                .SetPoint("TOPLEFT", parent, "TOPLEFT")()
            -- item icon
            --entry.icon = UI("Icon")
            --        .SetSize(ENTRY_HEIGHT*0.78, ENTRY_HEIGHT*0.78)
            --        .SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 9, -5)
            --        .AddTo(entry.frame)()
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
    self:Show()
end

function Loot:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:Hide()
    self.items = {}
end
