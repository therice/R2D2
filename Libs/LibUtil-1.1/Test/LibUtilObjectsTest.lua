local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Util

describe("LibUtil", function()
    setup(function()
        _G.LibUtil_Testing = true
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        Util, _ = LibStub('LibUtil-1.1')
    end)
    teardown(function()
        _G.LibUtil_Testing = nil
    end)
    describe("Objects", function()
        it("provides round-robin entry implementation", function()
            local e = Util.Objects.WeightedRoundRobinEntry('a', 1)
            assert(e.id == 'a')
            assert(e.weight == 1)
            e = Util.Objects.WeightedRoundRobinEntry('b')
            assert(e.id == 'b')
            assert(e.weight == 0)
            e:incr()
            assert(e.weight == 1)
            e:incr(3)
            assert(e.weight == 4)
            e:decr()
            assert(e.weight == 3)
            e:decr(2)
            assert(e.weight == 1)
        end)
        it("provides round-robin implementation", function()
            local t = {}
            for i=97,122 do
                Util.Tables.Push(t, string.char(i))
            end

            -- empty, to start, operations
            local rr = Util.Objects.WeightedRoundRobin()
            assert.is.Nil(rr:peek())
            assert.is.Nil(rr:next())
            local i, e = rr:find('z')
            assert.is.Nil(i)
            assert.is.Nil(e)
            rr:add('a')
            rr:add('b')
            e = rr:peek()
            assert(e.id == 'a')

            -- populated, to start, operations
            rr = Util.Objects.WeightedRoundRobin(t)
            --print(Util.Objects.ToString(rr:toTable()))
            assert(rr:peek().id == 'a')
            assert(rr:peek().id == 'a')

            e = rr:next()
            assert(e.id == 'a')
            assert(e.weight == 1)
            assert(rr:peek().id == 'b')

            --print(Util.Objects.ToString(rr:toTable()))

            i, e = rr:find('p')
            assert(i == 15)
            assert.is.Not.Nil(e)
            assert(e.id == 'p')

            rr:remove('p')
            i, e = rr:find('p')
            assert.is.Nil(i)
            assert.is.Nil(e)


            rr:add('p')
            i, e = rr:find('p')
            assert(i == 25) -- only rotated once, so insertion index will be 26 - 1

            --print(Util.Objects.ToString(rr:toTable()))

            t = {'a', 'b', 'z', 'e'}
            rr = Util.Objects.WeightedRoundRobin(t)
            assert(#rr.entries == 4)
            Util.Tables.Push(t, 'zz')
            rr:ensure(t)
            assert(#rr.entries == 5)
            i, e = rr:find('zz')
            assert(i == #rr.entries)
            assert(e.id == 'zz')
            rr:next()
            t = {'a', 'e', 'zz', 'aa'}
            rr:ensure(t)
            assert(#rr.entries == 4)
            for _, v in pairs(t) do
                i, e = rr:find(v)
                assert(e.id == v)
            end

            rr = Util.Objects.WeightedRoundRobin(t)
            rr:skip()
            assert(rr:peek().id == 'e')
            rr:next()
            assert(rr:peek().id == 'a')
        end)
        it("provides round-robin reconstitution", function()
            local t = {}
            for i=97,122 do
                Util.Tables.Push(t, string.char(i))
            end
            Util.Tables.Shuffle(t)

            local rr1 = Util.Objects.WeightedRoundRobin(t)
            rr1:next()
            rr1:next()
            rr1:next()
            -- print(Util.Objects.ToString(rr1:toTable()))

            local rr2 = Util.Objects.WeightedRoundRobin():reconstitute(rr1:toTable())
            -- print(Util.Objects.ToString(rr2:toTable()))

            local function EntriesToTable(entries)
                return Util.Tables.Map(
                        Util.Tables.Copy(entries),
                        function(e) return e:toTable() end
                )
            end

            local e1 = EntriesToTable(rr1.entries)
            local e2 = EntriesToTable(rr2.entries)
            assert(Util.Tables.Equals(e1, e2, true))

            -- call next() on each instance to make sure reconstitution put into class instance
            rr1:next()
            rr2:next()
        end)
    end)
end)
