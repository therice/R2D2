local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local LootHistory, Util, Class, CDB


describe("Loot History", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/LootHistoryTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this).. '/../../../Test/TestSetup.lua'))(this, {})
        
        R2D2:OnInitialize()
        R2D2:OnEnable()
        R2D2:CallModule('LootHistory')
        Util = R2D2.Libs.Util
        Class = R2D2.Libs.Class
        CDB = R2D2.components.Models.CompressedDb
        LootHistory = R2D2:LootHistoryModule()
        LootHistory:OnInitialize()
    
        local db = R2D2.Libs.AceDB:New('R2D2_LootDB', LootHistory.defaults)
        for player, history in pairs(LootHistoryTestData) do
            db.factionrealm[player] = history
        end
        
        LootHistory.db = db
        LootHistory.history = CDB(db.factionrealm)
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
            local c_pairs = CDB.static.pairs
            local count = 0
            for _, _ in c_pairs(history) do
                count = count + 1
            end
            print(count)
            assert(count == 14)
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
            LootHistory.frame.instance = StubSt()
            LootHistory:BuildData()


            assert(Util.Tables.Count(LootHistory.frame.st.data) == 105)
            assert(Util.Tables.Count(LootHistory.frame.name.data) == 15)
            assert(Util.Tables.Count(LootHistory.frame.date.data) == 12)
            assert(Util.Tables.Count(LootHistory.frame.instance.data) == 3)
        end)
    end)
end)

