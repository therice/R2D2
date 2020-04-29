local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local Util

describe("LibUtil", function()
    setup(function()
        _G.LibUtil_Testing = true
        loadfile('LibUtilTestData.lua')()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))(this, {})
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
    end)
end)
