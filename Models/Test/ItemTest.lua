local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Models, ItemUtil

local function CreateItem(id)
    local _, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(id)
    local itemId = link and ItemUtil:ItemLinkToId(link)
    return Models.Item:new(
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

local function CreateItemEntry(id)
    local item = CreateItem(id)
    return  Models.ItemEntry:new(item, nil, 1, false, nil, false, "default")
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
            assert(item:IsValid())
        end)
        it("is cloned", function()
            local item1 = CreateItem(18832)
            local item2 = item1:clone()
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
            local itemEntry = CreateItemEntry(18832)
            assert.equals(itemEntry.id, 18832)
            assert.equals(itemEntry.typeCode, "default")
            assert.equals(true, itemEntry:IsValid())

        end)
        it("is created from item link", function()
            local itemEntry = Models.ItemEntry:new('|cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r', nil, 1, false, nil, false, "default")
            assert.equals(itemEntry.id, 18832)
            assert.equals(itemEntry.typeCode, "default")
        end)
        it("is cloned", function()
            local itemEntry1 = CreateItemEntry(18832)
            local itemEntry2 = itemEntry1:clone()
            assert.equals(itemEntry1.id, itemEntry2.id)
            assert.equals(itemEntry1.typeCode, itemEntry2.typeCode)
        end)
        it("is reconstituted", function()
            local itemEntry1 = Models.ItemEntry:new('|cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r', nil, 1, false, nil, false, "default")
            local itemEntry2 = Models.ItemEntry:new():reconstitute(itemEntry1:toTable())
            assert.equals(itemEntry1.id, itemEntry2.id)
            assert.equals(itemEntry1.typeCode, itemEntry2.typeCode)
        end)
        it("is validated", function()
            local itemEntry = Models.ItemEntry:new('|cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r', nil, 1, false, nil, false, "default")
            assert(itemEntry:IsValid())
            assert(not itemEntry.session)
            itemEntry.id = 0
            assert(not itemEntry:IsValid())
            itemEntry:Validate(1)
            assert(itemEntry:IsValid())
            assert(itemEntry.session)
        end)
    end)

    describe("LootEntry", function()
        it("is created", function()
            local itemEntry = CreateItemEntry(18832)
            local lootEntry = Models.LootEntry:new(itemEntry)

            assert.equals(itemEntry.id, lootEntry.id)
            assert(lootEntry:IsValid())
            assert(60, lootEntry.timeLeft)
        end)
        it("is cloned", function()
            local lootEntry1 = Models.LootEntry:new(CreateItemEntry(18832))
            local lootEntry2 = lootEntry1:clone()
            assert.equals(lootEntry1.id, lootEntry1.id)
            assert.equals(lootEntry2.typeCode, lootEntry2.typeCode)
            assert.equals(lootEntry2.timeLeft, lootEntry2.timeLeft)
        end)
        it("supports rolled creation", function()
            local rolled = Models.LootEntry.Rolled()
            assert(rolled.rolled)
        end)
    end)
end)