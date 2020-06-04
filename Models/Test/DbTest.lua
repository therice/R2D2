local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local CompressedDb, Db, Util

describe("DB Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/DbTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this).. '/../../Test/TestSetup.lua'))(this, {})
        CompressedDb = R2D2.components.Models.CompressedDb
        Db = R2D2.Libs.AceDB:New('R2D2_TestDB')
        Util = R2D2.Libs.Util
        R2D2:OnInitialize()
        R2D2:OnEnable()
    end)
    
    teardown(function()
        After()
    end)
    
    describe("DB", function()
        it("handles compress and decompress", function()
            for _, v in pairs(TestData) do
                local c = CompressedDb.static:compress(v)
                local d = CompressedDb.static:decompress(c)

                if Util.Objects.IsString(v) then
                    assert(Util.Strings.Equal(v, d))
                elseif Util.Objects.IsTable(v) then
                    assert(Util.Tables.Equals(v, d, true))
                end
            end
        end)
        it("handles single-value set/get via key", function()
            local db = CompressedDb(Db)
            for k, v in pairs(TestData) do
                db:put(k, v)
            end

            print('Length=' .. #db)

            local c_ipairs = CompressedDb.static.ipairs

            for k, _ in c_ipairs(db) do
                print(format("ipairs(%d)/get(%d)", k, k) .. ' =>'  .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_ipairs(db) do
                print("ipairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end

        end)
        it("handles single-value get/set via insert", function()
            local db = CompressedDb(Db.factionrealm)
            for _, v in pairs(TestData) do
                db:insert(v)
            end

            local c_pairs = CompressedDb.static.pairs


            for k, _ in c_pairs(db) do
                print(format("pairs(%d)/get(%d)", k, k) .. ' =>'  .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_pairs(db) do
                print("pairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end
        end)

        it("handles table set/get via key", function()
            local db = CompressedDb(Db.factionrealm)
            for _, k in pairs({'a', 'b', 'c'}) do
                db:put(k, {})
                print(Util.Objects.ToString(db:get(k)))
            end

            for _, v in pairs({{a='a', b=1, c= true}, {c='c', d=10.6, e=false}}) do
                for _, k in pairs({'a', 'b', 'c'}) do
                    db:insert(v, k)
                end
            end

            print('Length_1=' .. #Db)
            print('Length_2=' .. #db)


            local c_pairs = CompressedDb.static.pairs

            for k, _ in c_pairs(db) do
                print(format("pairs(%s)/get(%s)", k, k) .. ' =>' .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_pairs(db) do
                print("pairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end
        end)
        
        --[[
        it("scratch case", function()
            local Traffic = R2D2.components.Models.History.Traffic
            local Award = R2D2.components.Models.Award
            -- [183]
            local t = CompressedDb.static:decompress("AV4xXlReU2FjdG9yXlNHbm9tZWNow7Ntc2t5LUF0aWVzaF5TZGVzY3JpcHRpb25eU0F3YXJkZWR+YDI4fmBFUH5gZm9yfmBOZWZhcmlhbn5gKFZpY3RvcnkpXlNpZF5TMTU5MDgwODIxMS0xODQwXlNzdWJqZWN0c15UXnReU3Jlc291cmNlVHlwZV5OMV5TdmVyc2lvbl5UXlNtaW5vcl5OMF5TcGF0Y2heTjBeU21ham9yXk4xXnReU3N1YmplY3RUeXBlXk4zXlNhY3Rpb25UeXBlXk4xXlN0aW1lc3RhbXBeTjE1OTA4MDgyMTFeU3Jlc291cmNlUXVhbnRpdHleTjI4XlNhY3RvckNsYXNzXlNXQVJMT0NLXnReXg==")
            local ao = Award(t)
            local ho = Traffic():reconstitute(t)
            print(Util.Objects.ToString(ao:toTable()))
            print(Util.Objects.ToString(ho:toTable()))
            
            local subjects = {
                {"Whoo-Atiesh", "WARRIOR"},
                {"Tarazed-Atiesh", "PALADIN"},
                {"Kerridwen-Atiesh", "PRIEST"},
                {"Bigmagik-Atiesh", "HUNTER"},
                {"Saberian-Atiesh", "PALADIN"},
                {"Keelut-Atiesh", "HUNTER"},
                {"Entario-Atiesh", "HUNTER"},
                {"Findell-Atiesh", "HUNTER"},
                {"Grumpler-Atiesh", "HUNTER"},
                {"Modi-Atiesh", "WARLOCK"},
                {"Yashamaru-Atiesh", "WARLOCK"},
                {"Hobson-Atiesh", "PALADIN"},
                {"Ravenett-Atiesh", "WARRIOR"},
                {"Cirse-Atiesh", "WARLOCK"},
                {"Humanwarr-Atiesh", "WARRIOR"},
                {"Avalona-Atiesh", "WARLOCK"},
                {"Divinitee-Atiesh", "PRIEST"},
                {"Ingtar-Atiesh", "WARRIOR"},
                {"Zhitnik-Atiesh", "PALADIN"},
                {"Abramelin-Atiesh", "MAGE"},
                {"Kaiserina-Atiesh", "WARRIOR"},
                {"Gnomechómsky-Atiesh", "WARLOCK"},
                {"Pittypatt-Atiesh", "MAGE"},
                {"Warwicker-Atiesh", "MAGE"},
                {"Shipbeef-Atiesh", "MAGE"},
                {"Apolloion-Atiesh", "PALADIN"},
                {"Halcyon-Atiesh", "ROGUE"},
                {"Rarebear-Atiesh", "DRUID"},
                {"Stomatopada-Atiesh", "PALADIN"},
                {"Skogr-Atiesh", "DRUID"},
                {"Atarian-Atiesh", "WARRIOR"},
                {"Wreqt-Atiesh", "WARRIOR"},
                {"Zùùl-Atiesh", "PRIEST"},
                {"Padrion-Atiesh", "WARRIOR"},
                {"Ivannah-Atiesh", "PRIEST"},
                {"Taleath-Atiesh", "DRUID"},
                {"Bullfrog-Atiesh", "ROGUE"},
                {"Beernard-Atiesh", "PRIEST"},
                {"Mexica-Atiesh", "WARRIOR"}
            }
            ao:SetSubjects(Award.SubjectType.Raid, unpack(subjects))
            
            local hn = Traffic(ho.timestamp, ao)
            for _, attr in pairs({'actor', 'actorClass', 'resourceBefore', 'lootHistoryId', 'id'}) do
                hn[attr] = ho[attr]
            end
            
            print(Util.Objects.ToString(hn:toTable(), 8))
            print(CompressedDb.static:compress(hn:toTable()))
        end)
        --]]
    end)
end)