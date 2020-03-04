local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local encounter, util
describe("LibItemUtil", function()
    setup(function()
        _G.LibEncounter_Testing = true
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))(this, {})
        encounter, _ = LibStub('LibEncounter-1.0', true)
        util, _ = LibStub('LibUtil-1.1', true)
    end)
    teardown(function()
        _G.LibEncounter_Testing = nil
    end)
    describe("creature names", function()
        it("resolved from ids", function()
            assert.equal("Lucifron", encounter:GetCreatureName(12118))
        end)
    end)
    describe("map names", function()
        it("resolved from map ids", function()
            assert.equal("Molten Core", encounter:GetMapName(409))
        end)
    end)
    describe("map ids", function()
        it("resolved from creature ids", function()
            assert.equal(409, encounter:GetCreatureMapId(12118))
        end)
    end)
    describe("creature detail", function()
        it("resolved from creature ids", function()
            local creature, map = encounter:GetCreatureDetail(12118)
            assert.equal("Molten Core", map)
            assert.equal("Lucifron", creature)
        end)
        it("blah blah", function()
            local t = {
                creatures = {
                    ['1'] = 2,
                    ['31'] = 3,
                    ted = 4,
                }
            }
            assert.equal(4, util.Tables.Get(t, 'creatures', 'ted'))
            assert.equal(4, util.Tables.Get(t, 'creatures.ted'))
            assert.equal(3, util.Tables.Get(t, 'creatures.31'))
        end)
    end)
end)