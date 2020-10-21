local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Loot, LootStatistics, Util, CDB
local history = {}


describe("History - Loot Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        loadfile(pl.abspath(pl.dirname(this) .. '/LootTestData.lua'))()
        Loot = R2D2.components.Models.History.Loot
        LootStatistics = R2D2.components.Models.History.LootStatistics
        CDB = R2D2.components.Models.CompressedDb
        Util = R2D2.Libs.Util

        for k,v in pairs(LootTestData) do
            history[k] = CDB.static:decompress(v)
        end

    end)

    teardown(function()
        history = {}
        After()
    end)

    describe("creation", function()
        it("from no args", function()
            local entry = Loot()
            assert(entry:FormattedTimestamp() ~= nil)
            assert(entry.id:match("(%d+)-(%d+)"))
        end)
        it("from instant #travisignore", function()
            local entry = Loot(1585928063)
            assert(entry:FormattedTimestamp() == "04/03/2020 09:34:23")
            assert(entry.id:match("1585928063-(%d+)"))
        end)
    end)

    describe("marshalling", function()
        it("to table", function()
            local entry = Loot(1585928063)
            local asTable = entry:toTable()
            assert(asTable.timestamp == 1585928063)
            assert(asTable.version ~= nil)
            assert(asTable.version.major >= 1)
        end)
        it("from table", function()
            local entry1 = Loot(1585928063)
            local asTable = entry1:toTable()
            local entry2 = Loot():reconstitute(asTable)
            assert.equals(entry1.id, entry2.id)
            assert.equals(entry1.timestamp, entry2.timestamp)
            assert.equals(entry1.version.major, entry2.version.major)
            -- invoke to make sure class meta-data came back with reconstitute
            entry2.version:nextMajor()
            assert.equals(tostring(entry1.version), tostring(entry2.version))
        end)
    end)

    describe("stats", function()
        it("creation", function()
            local stats = LootStatistics()
            for k,  e in pairs(history) do
                for i, v in ipairs(e) do
                    stats:ProcessEntry(k, v, i)
                end
            end

            local se = stats:Get('Gnomechómsky-Atiesh')
            local totals = se:CalculateTotals()
            assert(totals.count == 14)
            assert(totals.raids.count == 10)
        end)
    end)

    describe("export and import", function()
        it("json", function()
            local export, history = {}, {}

            local toAdd = 10
            for _,v in pairs(LootTestDataLarge) do
                Util.Tables.Push(history, CDB.static:decompress(v))
                toAdd = toAdd -1
                if toAdd == 0 then
                    break
                end
            end

            for k,  e in pairs(history) do

                local loot = export[k]
                if not loot then
                    loot = {}
                    export[k] = loot
                end

                for _, v in ipairs(e) do
                    Util.Tables.Push(loot, Loot():reconstitute(v):toTable())
                end
            end

            local json = R2D2.Libs.JSON:Encode(export, nil, {pretty = true, indent = "  "})
            local import = R2D2.Libs.JSON:Decode(json)
            assert(Util.Tables.Equals(export, import, true))
        end)
    end)
end)