local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util = AddOn.Libs.Util
local Logging = AddOn.Libs.Logging
local Date = AddOn.components.Models.Date
local DateFormat = AddOn.components.Models.DateFormat
local SemanticVersion =  AddOn.components.Models.SemanticVersion

local Loot = Class('Loot')
AddOn.components.Models.History.Loot = Loot

local counter, df = 0, DateFormat:new("mm/dd/yyyy HH:MM:SS")

local function counterGetAndIncr()
    local value = counter
    counter = counter + 1
    return value
end

local ResponseOrigin = {
    Unknown             = 0,
    CandidateResponse   = 1,
    AwardReason         = 2,
}

function Loot:initialize(instant)
    -- all timestamps will be in UTC/GMT and require use cases to convert to local TZ
    local instant = instant and Date(instant) or Date('utc')
    -- for versioning history entries, this is independent of add-on version
    self.version = SemanticVersion(1, 0)
    -- unique identifier should multiple instances be created at same instant3
    self.id = instant.time .. '-' .. counterGetAndIncr()
    self.timestamp = instant.time
    -- link to the awarded item
    self.item = nil
    self.itemTypeId = nil
    self.itemSubTypeId = nil
    -- who received the item
    self.owner = nil
    -- identifier for map (instance)
    self.mapId = nil
    -- the instance name
    self.instance = nil
    -- the instance boss (or unknown)
    self.boss = _G.UNKNOWN
    -- the text of the candidate's response or award reason
    self.response = nil
    -- the id of the candidate's response or award reason
    self.responseId = nil
    -- number indicating if response was taken award reason (e.g. not from candidate's response)
    self.responseOrigin = ResponseOrigin.Unknown
    -- the display color of the candidate's response or award reason
    self.color = nil
    -- the class of the winner
    self.class = nil
    -- size of group in which the item ws won
    self.groupSize = nil
    -- any note provided by candidate when responding
    self.note = nil
    -- the response type code
    self.typeCode = nil
end

function Loot:IsCandidateResponse()
    return self.responseOrigin == ResponseOrigin.CandidateResponse
end

function Loot:IsAwardReason()
    return self.responseOrigin == ResponseOrigin.AwardReason
end

function Loot:SetOrigin(fromAwardReason)
    local origin = (fromAwardReason and ResponseOrigin.AwardReason) or ResponseOrigin.CandidateResponse
    self.responseOrigin = origin
end

-- @return the entry's timestamp formatted in local TZ
function Loot:FormattedTimestamp()
    return df:format(self.timestamp)
end

function Loot:TimestampAsDate()
    return Date(self.timestamp)
end

function Loot:afterReconstitute(instance)
    instance.version = SemanticVersion(instance.version)
    return instance
end