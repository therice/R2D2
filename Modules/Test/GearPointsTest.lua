local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local gp, ep, libGp, Models, ItemUtil, Util

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


describe("GearPoints", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../Test/TestSetup.lua'))(this, {})
        libGp = LibStub('LibGearPoints-1.2')
        Models = R2D2.components.Models
        ItemUtil = R2D2.Libs.ItemUtil
        Util = R2D2.Libs.Util
        
        R2D2:OnInitialize()
        gp = R2D2:GetModule("GearPoints")
        gp:OnInitialize()
        ep = R2D2:GetModule("EffortPoints")
        ep:OnInitialize()
        R2D2:OnEnable()
        gp:OnEnable()
        ep:OnEnable()
    end)

    teardown(function()
       After()
    end)

    describe("module", function()
        -- validate that after initialization/enabling that values are correct
        it("is initialized", function()
            assert.is.Not.Nil(gp)
            assert.is.True(gp:IsEnabled())
            local base, coefficientBase, multiplier = libGp:GetFormulaInputs()
            assert.equal(4.8, base)
            assert.equal(2.5, coefficientBase)
            assert.equal(1, multiplier)
            assert.equal(22, GetSize(libGp:GetScalingConfig()))

            local gp, comment = libGp:GetValue(18832)
            assert.equal(84,gp)
            assert.equal(comment, "One-Hand Weapon")
        end)
        it("calculates gp", function()
            local itemEntry = CreateItemEntry(18832)
            local allocation = itemEntry:ToAllocateEntry()
            allocation.candidates["Gnomechomsky"] = {
                class = 'WARLOCK'
            }
            local base, actual1 = allocation:GetGp("os_greed")
            assert(base == 84)
            assert(actual1 == 42)
            
            -- this is based upon the fact we statically return 521 (AQ40) via GetInstanceInfo() in our test setup
            ep.db.profile.raid['531'] = {
                scaling = true,
                scaling_pct = 0.5
            }
            
            local award = allocation:GetItemAward(1, "Gnomechomsky", { award_scale = 'os_greed' })
            local actual2 = award:GetGp()
            assert(actual2 == 21)
        end)
    end)
end)