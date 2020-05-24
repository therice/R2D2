local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local Util

describe("LibUtil", function()
    setup(function()
        _G.LibUtil_Testing = true
        loadfile(pl.abspath(pl.dirname(this) .. '/LibUtilTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        Util, _ = LibStub('LibUtil-1.1')
    end)
    teardown(function()
        _G.LibUtil_Testing = nil
    end)
    describe("Tables", function()
        it("get(s) table entry via path", function()
            local data = Util.Tables.Get(TestTable, "defaults.profile")
            assert.is.Not.Nil(data.buttons)
            assert.is.Not.Nil(data.responses)
            data = Util.Tables.Get(TestTable, "defaults.profile.buttons.default")
            assert.is.Not.Nil(data)
            assert.equal(4, data.numButtons)
        end)
        it("set(s) table entry via path", function()
            local K1 = "kk"
            local K2 = "ll"

            local T = {
                tp = {

                }
            }

            Util.Tables.Set(T, 'tp', K1, {a='b'})
            Util.Tables.Set(T, 'tp', K2, {})
            Util.Tables.Set(T, 'tp', "a", "big", "path", true)
            assert.equal('b', Util.Tables.Get(T, 'tp', K1, 'a'))
            assert.equal(0, Util.Tables.Count(Util.Tables.Get(T, 'tp', K2)))
            assert.equal(true, Util.Tables.Get(T, 'tp.a.big.path'))
        end)
        it("copy and map", function()
            local copy =
                Util(TestTable2)
                    :Copy()
                    :Map(
                        function(entry)
                            return entry.test and {} or entry
                        end
                )()

            print(Util.Objects.ToString(copy))
        end)
        it("provides keys", function()
            local keys = Util(TestTable2):Keys()()
            local copy = {}
            for _, v in pairs(keys) do
                assert(Util.Objects.In(v, 'a', 'b', 'c', 'd'))
                Util.Tables.Push(copy, v)
            end
            
            print(Util.Objects.ToString(copy))
        end)
        it("sorts associatively", function()
            local t = {
                ['test'] = {a=1,b='Zed'},
                ['foo'] = {a=2,b='Bar'},
                ['aba'] = {a=100, b = 'Qre'},
            }
            
            local t2 = Util.Tables.ASort(t, function (a,b) return a[2].b < b[2].b end)
            local idx = 1
            for _, v in pairs(t2) do
                assert(v[1] == (idx == 1 and 'foo' or idx == 2 and 'aba' or idx == 3 and 'test' or nil))
                idx = idx + 1
            end
        end)
        it("copys, maps, and flips", function()
            local t =  {
                Declined    = { 1, 'declined' },
                Unavailable = { 2, 'unavailable' },
                Unsupported = { 3, 'unsupported' },
            }
    
            print(Util.Objects.ToString(t))
            local t2 = Util(t):Copy():Map(function (e) return e[1] end):Flip()()
            print(Util.Objects.ToString(t2))
        end)
    end)
end)
