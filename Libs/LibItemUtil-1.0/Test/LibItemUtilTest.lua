local pl = require('pl.path')

local itemUtil
describe("LibItemUtil", function()
    setup(function()
        _G.LibItemUtil_Testing = true
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))()
        itemUtil, _ = LibStub('LibItemUtil-1.0')
    end)
    teardown(function()
        _G.LibItemUtil_Testing = nil
    end)
    describe("item ids", function()
        it("resolved from item links", function()
            id = itemUtil:ItemlinkToID("|cff9d9d9d|Hitem:7073::::::::::::|h[Broken Fang]|h|r")
            assert.equals(id, 7073)
        end)
        it("resolve whether a class can use", function()
            assert.is.True(itemUtil:ClassCanUse("ROGUE", 18832))
            assert.is.Not.True(itemUtil:ClassCanUse("DRUID", 18832))
        end)
    end)
end)
