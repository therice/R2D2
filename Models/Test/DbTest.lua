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
    end)
end)