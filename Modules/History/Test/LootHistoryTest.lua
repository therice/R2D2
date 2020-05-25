local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local LootHistory, Util, Class, CDB, Sync


local function NewLootHistoryDb(data)
    -- need to add random # to end or it will have the same data
    local db = R2D2.Libs.AceDB:New('R2D2_LootDB' .. random(100), LootHistory.defaults)
    local count = 0
    for player, history in pairs(data) do
        db.factionrealm[player] = history
        count = count + 1
    end
    LootHistory.db = db
    LootHistory.history = CDB(db.factionrealm)
    print("New LootHistoryDb with count = " .. count .. " self.db.factionrealm = " .. Util.Tables.Count(LootHistory.db.factionrealm))
end

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
        Sync = R2D2:SyncModule()
        Sync:OnInitialize()
        LootHistory = R2D2:LootHistoryModule()
        LootHistory:OnInitialize()
        NewLootHistoryDb(LootHistoryTestData2)
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
            assert(count == 33)
        end)
    end)
    
    describe("builds history", function()
        it("from db (test data) #travisignore", function()
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

            --print(Util.Tables.Count(LootHistory.frame.name.data))
            
            assert(Util.Tables.Count(LootHistory.frame.st.data) == 97)
            assert(Util.Tables.Count(LootHistory.frame.name.data) == 34) -- +1 is for the dummy candidate
            assert(Util.Tables.Count(LootHistory.frame.date.data) == 3)
            assert(Util.Tables.Count(LootHistory.frame.instance.data) == 3)
        end)
    end)
    
    describe("imports history", function()
        it("from sync", function()
            local handler = Sync.handlers['LootHistory']
            local data = handler.send()
            NewLootHistoryDb(LootHistoryTestData1)
            handler.receive(data)
        end)
    end)
end)
