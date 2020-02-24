local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))


local gearPoints
describe("LibGearPoints (localized to 'deDE')", function()
    setup(function()
        loadfile('LibGearPointsTestUtil.lua')()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))(
                this,
                {
                    function() SetLocale("deDE") end
                }
        )
        gearPoints, _ = LibStub('LibGearPoints-1.2')
    end)
    teardown(function()
        After()
    end)
    describe("scaling factor", function()
        it("key can be determined from equipment location", function()
            assert.equal("ranged", gearPoints:GetScaleKey(nil, "Bögen"))
        end)
    end)
end)