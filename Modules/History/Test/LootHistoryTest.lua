local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local LootHistory, Util, Class, CDB, Sync, History, Date, JSON


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
    print("New LootHistoryDb with count = " .. count .. " (maxn=" .. table.maxn(data) .. ") self.db.factionrealm = " .. Util.Tables.Count(LootHistory.db.factionrealm) .. " (maxn=" .. table.maxn(LootHistory.db.factionrealm) .. ")")
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
        Date = R2D2.components.Models.Date
        History = R2D2.components.History
        JSON = R2D2.Libs.JSON
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
        it("from export", function()
            NewLootHistoryDb(LootHistoryTestData2)
            History.Import(LootHistory:GetName(), LootExport)
            print(#LootHistory.db.factionrealm)
            assert(Util.Tables.Count(LootHistory.db.factionrealm) == 62)
        end)
    end)

    describe("processes history", function()
        NewLootHistoryDb(LootHistoryTestData2)
        LootHistory:OnEnable()

        local count
        local function IncrementCount(row)
            count = count + 1
            -- print(Util.Objects.ToString(row.entry:toTable()))
        end

        it("from selection", function()
            count = 0
            LootHistory.frame.st:SetSelection(2)
            for _, row in History.Iterator(LootHistory:GetName(), History.ProcessTypes.Selection)() do
                IncrementCount(row)
            end
            LootHistory.frame.st:ClearSelection()
            assert(count == 1)
        end)
        it("from filter", function()
            count = 0
            LootHistory.SetFilterValues("Cirse-Atiesh")
            LootHistory.frame.st:SortData()

            for _, row in History.Iterator(LootHistory:GetName(), History.ProcessTypes.Filtered)() do
                IncrementCount(row)
            end

            print(count)
            assert(count == 36)
            LootHistory.SetFilterValues(nil)
        end)
        it("from age (younger)", function()
            -- calculate # days between now and 2020-05-23
            count = 0
            local now = Date()
            now:hour(00)
            now:min(00)
            now:sec(00)
            local cutoff = Date(2020, 05, 23, 00, 00, 00)
            local days = math.floor(os.difftime(now.time, cutoff.time) / (24 * 60 * 60))
            for _, row in History.Iterator(LootHistory:GetName(), History.ProcessTypes.AgeYounger, days)() do
                IncrementCount(row)
            end
            assert(count == 35)
        end)
        it("from age (older)", function()
            -- calculate # days between now and 2020-05-23
            count = 0
            local now = Date()
            now:hour(00)
            now:min(00)
            now:sec(00)
            local cutoff = Date(2020, 05, 23, 00, 00, 00)
            local days = math.floor(os.difftime(now.time, cutoff.time) / (24 * 60 * 60))
            for _, row in History.Iterator(LootHistory:GetName(), History.ProcessTypes.AgeOlder, days)() do
                IncrementCount(row)
            end
            assert(count == 62)
        end)
        it("all", function()
            count = 0
            for _, row in History.Iterator(LootHistory:GetName(), History.ProcessTypes.All)() do
                IncrementCount(row)
            end
            assert(count == 97)
        end)
    end)

    describe("exports history", function()
        NewLootHistoryDb(LootHistoryTestData2)
        LootHistory:OnEnable()

        it("from small data", function()
            LootHistory.SetFilterValues("Cirse-Atiesh")
            LootHistory.frame.st:SortData()
            local exported = LootHistory:ExportHistory(History.Iterator(LootHistory:GetName(), History.ProcessTypes.Filtered))
            LootHistory.frame.st:ClearSelection()
            assert(exported:len() < 40000)
            assert(History.FromJson(exported))
        end)

        it("from large data", function()
            local exported = LootHistory:ExportHistory(History.Iterator(LootHistory:GetName(), History.ProcessTypes.All))
            assert(History.FromJson(exported))
        end)
    end)

    describe("deletes history", function()
        it("from small data", function()
            NewLootHistoryDb(LootHistoryTestData2)
            LootHistory:OnEnable()
            LootHistory.SetFilterValues("Cirse-Atiesh")
            LootHistory.frame.st:SortData()
            local deleted = LootHistory:DeleteHistory(History.Iterator(LootHistory:GetName(), History.ProcessTypes.Filtered))
            assert(Util.Tables.Sum(deleted) == 36)
            assert(Util.Tables.ContainsKey(deleted, "Cirse-Atiesh"))
            assert(Util.Tables.Count(deleted) == 1)
            assert(#LootHistory.frame.st.filtered == 0)
            assert(#LootHistory.frame.rows == (97-36))
            LootHistory.frame.st:ClearSelection()
        end)
        it("from large data", function()
            NewLootHistoryDb(LootHistoryTestData2)
            LootHistory:OnEnable()
            local deleted = LootHistory:DeleteHistory(History.Iterator(LootHistory:GetName(), History.ProcessTypes.All))
            --print(Util.Objects.ToString(deleted))
            --print(Util.Objects.ToString(Util.Tables.Sum(deleted)))
            assert(Util.Tables.Sum(deleted) == 97)
            assert(#LootHistory.frame.rows == 0)
        end)
    end)


    describe("handles",  function()
        it("corrupt data", function()
            NewLootHistoryDb(LootHistoryTestData3)
            LootHistory:OnEnable()
            LootHistory:BuildData()
        end)
        it("non-corrupt data", function()
            NewLootHistoryDb(LootHistoryTestData4)
            LootHistory:OnEnable()
            LootHistory:BuildData()
        end)
    end)

end)
