local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Models, ItemUtil

local function CreateItem(id)
    local _, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(id)
    local itemId = link and ItemUtil:ItemLinkToId(link)
    return Models.Item:New(
            itemId,
            link,
            rarity,
            ilvl,
            type,
            equipLoc,
            subType,
            texture,
            typeId,
            subTypeId,
            bindType,
            ItemUtil:GetItemClassesAllowedFlag(link)
    )
end

describe("Item Model", function()
    setup(function()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../Test/TestSetup.lua'))(this, {})
        R2D2:OnInitialize()
        R2D2:OnEnable()
        Models = R2D2.components.Models
        ItemUtil = R2D2.Libs.ItemUtil
    end)

    teardown(function()
        After()
    end)

    describe("Item", function()
        it("is created", function()
            local item = CreateItem(18832)
            assert.equals(item.id, 18832)
        end)
        it("is cloned", function()
            local item1 = CreateItem(18832)
            local item2 = item1:Clone()
            assert.equals(item1.id, item2.id)
        end)
        it("provides expected text", function()
            local item = CreateItem(18832)
            assert.equals("One-Hand, One-Handed Swords", item:GetTypeText())
            assert.equals("70", item:GetLevelText())
        end)
    end)

    describe("ItemEntry", function()
        it("is created from item", function()
            local item = CreateItem(18832)
            local itemEntry = Models.ItemEntry:New(item, 1, false, nil, false, "default")
            assert.equals(itemEntry.id, 18832)
            assert.equals(itemEntry.typeCode, "default")
        end)
        it("is created from item link", function()
            local itemEntry = Models.ItemEntry:New('|cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r', 1, false, nil, false, "default")
            assert.equals(itemEntry.id, 18832)
            assert.equals(itemEntry.typeCode, "default")
        end)
        it("is cloned", function()
            local item = CreateItem(18832)
            local itemEntry1 = Models.ItemEntry:New(item, 1, false, nil, false, "default")
            local itemEntry2 = itemEntry1:Clone()
            assert.equals(itemEntry1.id, itemEntry2.id)
            assert.equals(itemEntry1.typeCode, itemEntry2.typeCode)
        end)
    end)
end)