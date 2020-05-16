local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Traffic, TrafficStatistics, Util, CDB
local history = {}

describe("History - Traffic Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        loadfile(pl.abspath(pl.dirname(this) .. '/TrafficTestData.lua'))()
        Traffic = R2D2.components.Models.History.Traffic
        TrafficStatistics = R2D2.components.Models.History.TrafficStatistics
        Util = R2D2.Libs.Util
        CDB = R2D2.components.Models.CompressedDb
    
        for _,v in pairs(TrafficTestData) do
            Util.Tables.Push(history, CDB.static:decompress(v))
        end
    end)
    
    teardown(function()
        history = {}
        After()
    end)
    
    describe("stats", function()
        it("creation", function()
            local stats = TrafficStatistics()
            for _, v in pairs(history) do
                stats:ProcessEntry(v)
            end
            
            
            local se = stats:Get('Annasthétic-Atiesh')
            se:CalculateTotals()
        end)
    end)
end)