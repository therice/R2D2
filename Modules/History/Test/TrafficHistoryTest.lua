local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local TrafficHistory, Util, Class, CDB, Sync


local function NewTrafficHistoryDb(data)
    -- need to add random # to end or it will have the same data
    local db = R2D2.Libs.AceDB:New('R2D2_TrafficDB' .. random(100), TrafficHistory.defaults)
    local count = 0
    for player, history in pairs(data) do
        db.factionrealm[player] = history
        count = count + 1
    end
    TrafficHistory.db = db
    TrafficHistory.history = CDB(db.factionrealm)
    print("New TrafficHistory with count = " .. count .. " self.db.factionrealm = " .. Util.Tables.Count(TrafficHistory.db.factionrealm))
end

describe("Loot History", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/TrafficHistoryTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this).. '/../../../Test/TestSetup.lua'))(this, {})
        
        R2D2:OnInitialize()
        R2D2:OnEnable()
        R2D2:CallModule('TrafficHistory')
        Util = R2D2.Libs.Util
        Class = R2D2.Libs.Class
        CDB = R2D2.components.Models.CompressedDb
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
    end)
end)
