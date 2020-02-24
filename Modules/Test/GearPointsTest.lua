local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local gp
local libGp

describe("GearPoints", function()
    setup(function()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../Test/TestSetup.lua'))(this, {})
        libGp = LibStub('LibGearPoints-1.2')

        -- todo : figure out the initialization BS here
        R2D2:OnInitialize()
        gp = R2D2:GetModule("GearPoints")
        gp:OnInitialize()
        R2D2:OnEnable()
        gp:OnEnable()
    end)

    teardown(function()
       After()
    end)

    describe("module", function()
        -- validate that after initializtion/enabling that values are correct
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
    end)
end)