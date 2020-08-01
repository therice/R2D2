local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local encounter, util

describe("LibEncounter(Localized)", function()
    setup(function()
        _G.LibEncounter_Testing = true
        _G.GetLocale = function() return "frFR" end
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(
                this,
                {
                    function() SetLocale("frFR") end
                }
        )
        encounter, _ = LibStub('LibEncounter-1.0', true)
        util, _ = LibStub('LibUtil-1.1', true)
    end)
    teardown(function()
        _G.LibEncounter_Testing = nil
        After()
    end)
    describe("map ids", function()
        it("resolved from map names", function()
            assert.equal(409, encounter:GetMapId('Cœur du Magma'))
        end)
    end)
end)