local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Traffic, TrafficStatistics, Util, CDB, Award, Base64, Compression
local history = {}

describe("History - Traffic Model", function()
    setup(function()
        _G.LibUtil_Testing = true
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        loadfile(pl.abspath(pl.dirname(this) .. '/TrafficTestData.lua'))()
        Traffic = R2D2.components.Models.History.Traffic
        TrafficStatistics = R2D2.components.Models.History.TrafficStatistics
        Util = R2D2.Libs.Util
        CDB = R2D2.components.Models.CompressedDb
        Award = R2D2.components.Models.Award
        Compression = Util.Compression
        Base64 = R2D2.Libs.Base64

        for _,v in pairs(TrafficTestData) do
            Util.Tables.Push(history, CDB.static:decompress(v))
        end
    end)

    teardown(function()
        history = {}
        After()
        _G.LibUtil_Testing = nil
    end)

    describe("stats", function()
        it("creation", function()
            local stats = TrafficStatistics()
            for _, v in pairs(history) do
                stats:ProcessEntry(v)
            end

            local se = stats:Get('Gnomechómsky-Atiesh')
            local totals = se:CalculateTotals()
            assert(totals.awards[Award.ResourceType.Ep].count == 16)
            assert(totals.awards[Award.ResourceType.Ep].total == 275)
            assert(totals.awards[Award.ResourceType.Ep].decays == 1)
            assert(totals.awards[Award.ResourceType.Ep].resets == 0)

            assert(totals.awards[Award.ResourceType.Gp].count == 0)
            assert(totals.awards[Award.ResourceType.Gp].total == 0)
            assert(totals.awards[Award.ResourceType.Gp].decays == 1)
            assert(totals.awards[Award.ResourceType.Gp].resets == 0)
        end)
    end)

    describe("export and import", function()
        it("json", function()
            local export, history = {}, {}

            local toAdd = 10
            for _,v in pairs(TrafficTestDataLarge) do
                Util.Tables.Push(history, CDB.static:decompress(v))
                toAdd = toAdd -1
                if toAdd == 0 then
                    break
                end
            end

            for _, v in pairs(history) do
                Util.Tables.Push(export, Traffic():reconstitute(v):toTable())
            end

            local json = R2D2.Libs.JSON:Encode(export, nil, {pretty = true, indent = "  "})
            local import = R2D2.Libs.JSON:Decode(json)
            assert(Util.Tables.Equals(export, import, true))
        end)
    end)
end)