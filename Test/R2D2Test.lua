local pl = require('pl.path')
local logFile

describe("R2D2Test", function()
    setup(function()
        _G.R2D2_Testing = true
        logFile = io.open(pl.abspath('.') .. '/R2D2Test.log', 'w')
        _G.R2D2_Testing_GetLogFile = function() return logFile end
        loadfile(pl.abspath(pl.abspath('.') .. '/TestSetup.lua'))()
    end)
    teardown(function()
        logFile:close()
        _G.R2D2_Testing = nil
    end)
    describe("R2D2", function()
        it("is initialized", function()
            R2D2:OnInitialize()
        end)
        it("is enabled", function()
            R2D2:OnEnable()
        end)
        it("prints chat commands", function()
            R2D2:ChatCommand("VerSION A BEBPP")
            R2D2:ChatCommand("help")
            R2D2:ChatCommand("notacommand")
        end)
    end)
end)

