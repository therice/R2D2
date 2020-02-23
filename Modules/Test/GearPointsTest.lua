local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

describe("GearPoints", function()
    setup(function()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../Test/TestSetup.lua'))(this, {})
    end)
    teardown(function()
       After()
    end)

    describe("module", function()
        it("is initialized", function()

        end)
    end)
end)