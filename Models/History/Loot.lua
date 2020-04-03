local _, AddOn = ...
local Class     = AddOn.Libs.Class
local Date      = AddOn.components.Models.Date

local Loot = Class('Loot')
AddOn.components.Models.History.Loot = Loot

local counter = 0

local function counterGetAndIncr()
    local value = counter
    counter = counter + 1
    return value
end

function Loot:initialize()
    -- all timestamps will be in UTC/GMT and require use cases to convert to local TZ
    local instant = Date('utc')
    -- for versioning history entries, this is independent of add-on version
    self.version = AddOn.components.Models.SemanticVersion:new(1, 0)
    -- unique identifier should multiple instances be created at same instant3
    self.id = instant.time .. '-' .. counterGetAndIncr()
    self.timestamp = instant.time
    self.owner = nil
    self.mapId = nil
    self.instance = nil
    self.boss = nil
    self.response = nil
    self.responseId = nil
    self.class = nil
    self.groupSize = nil
    self.note = nil
    self.typeCode = nil
end

-- 04/02/20 19:40:29