local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local LootHistory, Util, Class


describe("Loot History", function()
    setup(function()
        loadfile('LootHistoryTestData.lua')()
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))(this, {})
        R2D2:OnInitialize()
        R2D2:OnEnable()
        R2D2:CallModule('LootHistory')
        Util = R2D2.Libs.Util
        Class = R2D2.Libs.Class
        LootHistory = R2D2:LootHistoryModule()
        LootHistory:OnInitialize()
        LootHistory.db.factionrealm = LootHistoryTestData
    end)
    
    teardown(function()
        if LootHistory then
            R2D2:DisableModule(LootHistory:GetName())
            LootHistory:OnDisable()
        end
        After()
    end)
    
    describe("provides history", function()
        it("from db (test data)", function()
            local history = LootHistory:GetHistory()
            assert(Util.Tables.Count(history) == 2)
        end)
    end)
    
    describe("builds history", function()
        it("from db (test data)", function()
            local StubSt = Class('StubSt')
            function StubSt:initialize()
                self.data = {}
            end
            function StubSt:SetData(data)
                self.data = data
            end
    
            R2D2.candidates['Macbook-Atiesh'] = R2D2.components.Models.Candidate('Macbook-Atiesh', 'WARLOCK')
            LootHistory.frame = CreateFrame("R2D2_LootHistory")
            LootHistory.frame.rows = {}
            LootHistory.frame.st = StubSt()
            LootHistory.frame.name = StubSt()
            LootHistory.frame.date = StubSt()
            LootHistory:BuildData()
            
            assert(Util.Tables.Count(LootHistory.frame.st.data) == 9)
            assert(Util.Tables.Count(LootHistory.frame.name.data) == 3)
            assert(Util.Tables.Count(LootHistory.frame.date.data) == 9)
        end)
    end)
end)

