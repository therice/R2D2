local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Models, Util

describe("Standby Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../Test/TestSetup.lua'))(this, {})
        Models = R2D2.components.Models
        Util = R2D2.Libs.Util
    end)
    
    teardown(function()
        After()
    end)
    
    describe("Standby Member", function()
        it("is created from parameters (no contacts)", function()
            local m = Models.StandbyMember("Imatest", "WARLOCK", {})
            assert(m.name == "Imatest")
            assert(m.class == "WARLOCK")
            assert(m.joined ~= nil)
            assert(m.status.timestamp == m.joined)
            assert(m.status.online == true)
            assert(Util.Tables.Count(m.contacts) == 0)
        end)
        it("is created from parameters (contacts)", function()
            local m = Models.StandbyMember("Imatest", "WARLOCK", {"Anothertest", "Debugme"})
            assert(m.name == "Imatest")
            assert(m.class == "WARLOCK")
            assert(m.joined ~= nil)
            assert(m.status.timestamp == m.joined)
            assert(m.status.online == true)
            assert(Util.Tables.Count(m.contacts) == 2)

            for name, status in pairs(m.contacts) do
                assert(Util.Objects.In(name, "Anothertest", "Debugme"))
                assert(status.timestamp == m.joined)
                assert(status.online == false)
            end
        end)
        it("supports (de)serialization", function()
            local m1 = Models.StandbyMember("Imatest", "WARLOCK", {"Anothertest", "Debugme"})
            m1.status = Models.StandbyStatus(1602021820, false)
            m1:UpdateStatus('Anothertest', true)

            local m2 = Models.StandbyMember():reconstitute(m1:toTable())
            for name, status in pairs(m2.contacts) do
                assert(Util.Objects.In(name, "Anothertest", "Debugme"))
                assert.Is.Not.Nil(status:GetText())
                assert(Util.Tables.Equals(m1.contacts[name]:toTable(), status:toTable(), true))
            end

            local e1, e2 = m1:toTable(), m2:toTable()
            assert(Util.Tables.Equals(e1, e2, true))
        end)
    end)
end)
