local _, AddOn = ...
local Class = AddOn.Libs.Class
local Date = AddOn.components.Models.Date
local DateFormat = AddOn.components.Models.DateFormat
local SemanticVersion = AddOn.components.Models.SemanticVersion

local counter, fullDf, shortDf = 0, DateFormat:new("mm/dd/yyyy HH:MM:SS"), DateFormat("mm/dd/yyyy")

local function counterGetAndIncr()
    local value = counter
    counter = counter + 1
    return value
end

local History = Class('History')
AddOn.components.Models.History.History = History

function History:initialize(instant)
    -- all timestamps will be in UTC/GMT and require use cases to convert to local TZ
    local instant = instant and Date(instant) or Date('utc')
    -- for versioning history entries, this is independent of add-on version
    self.version = SemanticVersion(1, 0)
    -- unique identifier should multiple instances be created at same instant3
    self.id = instant.time .. '-' .. counterGetAndIncr()
    self.timestamp = instant.time
end

function History:afterReconstitute(instance)
    instance.version = SemanticVersion(instance.version)
    return instance
end

-- @return the entry's timestamp formatted in local TZ in format of mm/dd/yyyy HH:MM:SS
function History:FormattedTimestamp()
    return fullDf:format(self.timestamp)
end

-- @return the entry's timestamp formatted in local TZ in format of mm/dd/yyyy
function History:FormattedDate()
    return shortDf:format(self.timestamp)
end

function History:TimestampAsDate()
    return Date(self.timestamp)
end
