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
        it("copies and maps", function()
            local copy =
                Util(TestTable2)
                    :Copy()
                    :Map(
                        function(entry)
                            return entry.test and {} or entry
                        end
                )()

            assert(Util.Tables.Equals(copy['a'], {}))
            assert(Util.Tables.Equals(copy['b'], {test=false}))
            assert(Util.Tables.Equals(copy['c'], {test=false}))
            assert(Util.Tables.Equals(copy['d'], {}))
        end)
        it("provides keys", function()
            local keys = Util(TestTable2):Keys()()
            local copy = {}
            for _, v in pairs(keys) do
                assert(Util.Objects.In(v, 'a', 'b', 'c', 'd'))
                Util.Tables.Push(copy, v)
            end
            assert(Util.Tables.Equals(keys, copy))
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
        it("copies, maps, and flips", function()
            local t =  {
                Declined    = { 1, 'declined' },
                Unavailable = { 3, 'unavailable' },
                Unsupported = { 2, 'unsupported' },
            }
            
            local t2 = Util(t):Copy():Map(function (e) return e[1] end):Flip()()
            assert(t2[1] == 'Declined')
            assert(t2[2] == 'Unsupported')
            assert(t2[3] == 'Unavailable')
        end)
        it("copies without mutate", function()
            local o = {
                a = {1, "b", true},
                b = {2, "c", true},
                c = {3, "d", false},
            }
            local c = Util(o):Copy()()
            Util.Tables.Remove(c, "b")
            assert(Util.Tables.ContainsKey(o, 'b'))
            assert(not Util.Tables.ContainsKey(c, 'b'))
        end)
        it("yields difference", function()
            local source = {
                a = {true},
                b = {},
                c = false,
                x = {}
            }
    
            local target = {
                a = {true},
                b = {3},
                d = {},
            }
    
            local delta1 = Util.Tables.CopyUnselect(source, unpack(Util.Tables.Keys(target)))
            local delta2 = Util.Tables.CopyUnselect(target, unpack(Util.Tables.Keys(source)))
                    
            --local delta =
            --    Util(source)
            --        :CopyFilter(
            --            function(v, k)
            --                print(Util.Objects.ToString(k) .. ' = ' .. Util.Objects.ToString(v))
            --                if Util.Tables.ContainsKey(target, k) then
            --                    local v2 = target[k]
            --                    if type(v) == type(v2) then
            --                        return Util.Objects.Equals(v, v2)
            --                    end
            --                end
            --                print('default')
            --                return true
            --            end,
            --            true,
            --            false,
            --            true
            --    )()
            
            print(Util.Objects.ToString(delta1))
            print(Util.Tables.Count(delta1))
            print(Util.Objects.ToString(delta2))
            print(Util.Tables.Count(delta2))
    
            local deltac = Util.Tables.CopyUnselect({a=1, b=1, c=1}, 'a', 'b', 'c')
            print(Util.Objects.ToString(deltac))
            print(Util.Tables.Count(deltac))
        end)
    end)
end)