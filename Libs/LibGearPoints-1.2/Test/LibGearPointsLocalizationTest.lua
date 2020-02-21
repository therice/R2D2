local pl = require('pl.path')


local gearPoints
describe("LibGearPoints (localized to 'deDE')", function()
    setup(function()
        loadfile('LibGearPointsTestUtil.lua')()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))(
                {
                    function() SetLocale("deDE") end
                }
        )
        gearPoints, _ = LibStub('LibGearPoints-1.2')
    end)
    teardown(function()
        _G.LibGearPoints_Testing = nil
    end)
    describe("scaling factor", function()
        it("key can be determined from equipment location", function()
            assert.equal("ranged", gearPoints:GetScaleKey(nil, "Bögen"))
        end)
    end)
end)