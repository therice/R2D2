local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local TrafficHistory, Util, Class, CDB, Sync, History, Date


local function NewTrafficHistoryDb(data)
    -- need to add random # to end or it will have the same data
    local db = R2D2.Libs.AceDB:New('R2D2_TrafficDB' .. random(100), TrafficHistory.defaults)
    local count = 0
    for k, history in pairs(data) do
        db.factionrealm[k] = history
        count = count + 1
    end
    TrafficHistory.db = db
    TrafficHistory.history = CDB(db.factionrealm)
    print("New TrafficHistory with count = " .. count .. " (maxn=" .. table.maxn(data) .. ") self.db.factionrealm = " .. Util.Tables.Count(TrafficHistory.db.factionrealm) .. " (maxn=" .. table.maxn(TrafficHistory.db.factionrealm) .. ")")
end

describe("Traffic History", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/TrafficHistoryTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this).. '/../../../Test/TestSetup.lua'))(this, {})
        
        R2D2:OnInitialize()
        R2D2:OnEnable()
        R2D2:CallModule('TrafficHistory')
        Util = R2D2.Libs.Util
        Class = R2D2.Libs.Class
        CDB = R2D2.components.Models.CompressedDb
        Date = R2D2.components.Models.Date
        History = R2D2.components.History
        Sync = R2D2:SyncModule()
        Sync:OnInitialize()
        TrafficHistory = R2D2:TrafficHistoryModule()
        TrafficHistory:OnInitialize()
        NewTrafficHistoryDb(TrafficHistoryTestData2)
    end)

    teardown(function()
        if TrafficHistory then
            R2D2:DisableModule(TrafficHistory:GetName())
            TrafficHistory:OnDisable()
        end
        After()
    end)

    describe("imports history", function()
        it("from sync", function()
            local handler = Sync.handlers['TrafficHistory']
            local data = handler.send()
            NewTrafficHistoryDb(TrafficHistoryTestData1)
            handler.receive(data)
        end)
        it("from export", function()
            NewTrafficHistoryDb(TrafficHistoryTestData2)
            History.Import(TrafficHistory:GetName(), TrafficExport)
            assert(#TrafficHistory.db.factionrealm == 721)
        end)
    end)

    describe("handles",  function()
        it("corrupt data", function()
            NewTrafficHistoryDb(TrafficHistoryTestData3)
            TrafficHistory:OnEnable()
            TrafficHistory:BuildData()
        end)
        it("non-corrupt data", function()
            NewTrafficHistoryDb(TrafficHistoryTestData4)
            TrafficHistory:OnEnable()
            TrafficHistory:BuildData()
        end)
    end)
    describe("processes history", function()
        NewTrafficHistoryDb(TrafficHistoryTestData2)
        TrafficHistory:OnEnable()

        local count
        local function IncrementCount(row)
            count = count + 1
            print(Util.Objects.ToString(row.entry:toTable()))
        end

        it("from selection", function()
            count = 0
            TrafficHistory.frame.st:SetSelection(2)
            for _, row in History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.Selection)() do
                IncrementCount(row)
            end
            TrafficHistory.frame.st:ClearSelection()
            assert(count == 1)
        end)
        it("from filter", function()
            count = 0
            TrafficHistory.SetFilterValues("Cirse-Atiesh")
            TrafficHistory.frame.st:SortData()
            for _, row in History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.Filtered)() do
                IncrementCount(row)
            end
            assert(count == 36)
            TrafficHistory.SetFilterValues(nil)
        end)
        it("from age (younger) #travisignore", function()
            -- calculate # days between now and 2020-05-23
            count = 0
            local now = Date()
            now:hour(00)
            now:min(00)
            now:sec(00)
            local cutoff = Date(2020, 05, 23, 00, 00, 00)
            local days = math.floor(os.difftime(now.time, cutoff.time) / (24 * 60 * 60))
            for _, row in History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.AgeYounger, days)() do
                IncrementCount(row)
            end
            print(count)
            assert(count == 53)
        end)
        it("from age (older) #travisignore", function()
            -- calculate # days between now and 2020-05-23
            count = 0
            local now = Date()
            now:hour(00)
            now:min(00)
            now:sec(00)
            local cutoff = Date(2020, 05, 23, 00, 00, 00)
            local days = math.floor(os.difftime(now.time, cutoff.time) / (24 * 60 * 60))
            for _, row in History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.AgeOlder, days)() do
                IncrementCount(row)
            end
            print(count)
            assert(count == 103)
        end)
        it("all", function()
            count = 0
            for _, row in History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.All)() do
                IncrementCount(row)
            end
            assert(count == 156)
        end)
    end)

    describe("exports history", function()
        NewTrafficHistoryDb(TrafficHistoryTestData2)
        TrafficHistory:OnEnable()

        it("from small data", function()
            TrafficHistory.SetFilterValues("Cirse-Atiesh")
            TrafficHistory.frame.st:SortData()
            local exported = TrafficHistory:ExportHistory(History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.Filtered))
            TrafficHistory.frame.st:ClearSelection()
            assert(exported:len() < 40000)
            assert(History.FromJson(exported))
        end)

        it("from large data", function()
            local exported = TrafficHistory:ExportHistory(History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.All))
            assert(History.FromJson(exported))
        end)
    end)

    describe("deletes history", function()
        it("from small data", function()
            NewTrafficHistoryDb(TrafficHistoryTestData2)
            TrafficHistory:OnEnable()
            TrafficHistory.SetFilterValues("Cirse-Atiesh")
            TrafficHistory.frame.st:SortData()
            local deleted = TrafficHistory:DeleteHistory(History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.Filtered))
            assert(Util.Tables.Sum(deleted) == 36)
            assert(#TrafficHistory.frame.st.filtered == 0)
            assert(#TrafficHistory.frame.rows == (156-36))
            TrafficHistory.frame.st:ClearSelection()
        end)
        it("from large data", function()
            NewTrafficHistoryDb(TrafficHistoryTestData2)
            TrafficHistory:OnEnable()
            local deleted = TrafficHistory:DeleteHistory(History.Iterator(TrafficHistory:GetName(), History.ProcessTypes.All))
            --print(Util.Objects.ToString(deleted))
            --print(Util.Objects.ToString(Util.Tables.Sum(deleted)))
            assert(Util.Tables.Sum(deleted) == 156)
            assert(#TrafficHistory.frame.rows == 0)
        end)
    end)
end)
