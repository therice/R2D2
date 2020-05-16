local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Models, Util

describe("Encounter Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../Test/TestSetup.lua'))(this, {})
        Models = R2D2.components.Models
        Util = R2D2.Libs.Util
    end)
    
    teardown(function()
        After()
    end)
    
    describe("Encounter", function()
        it("is created from start parameters", function()
            local e = Models.Encounter(1, "encounterName1", 1, 40)
            assert(e.id == 1)
            assert(e.name == "encounterName1")
            assert(e.difficultyId == 1)
            assert(e.groupSize == 40)
            assert(not e:IsSuccess())
        end)
        it("is created from end parameters", function()
            local e = Models.Encounter(2, "encounterName2", 9, 40, true)
            assert(e.id == 2)
            assert(e.name == "encounterName2")
            assert(e.difficultyId == 9)
            assert(e.groupSize == 40)
            assert(e:IsSuccess())
        end)
    end)
end)
