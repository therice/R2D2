local _, AddOn = ...
local Class = AddOn.Libs.Class
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util

local Encounter = Class('Encounter')
AddOn.components.Models.Encounter = Encounter

-- https://wow.gamepedia.com/ENCOUNTER_START
--      ENCOUNTER_START: encounterID, "encounterName", difficultyID, groupSize
-- https://wow.gamepedia.com/ENCOUNTER_END
--       ENCOUNTER_END: encounterID, "encounterName", difficultyID, groupSize, success
--
-- These are in the order expected from arguments to the events listed above
local EncounterFields = {'id', 'name', 'difficultyId', 'groupSize', 'success'}

function Encounter:initialize(...)
    local t = Util.Tables.Temp(...)
    for index, field in pairs(EncounterFields) do
        self[field] = t[index]
    end
    Util.Tables.ReleaseTemp(t)
end

function Encounter:IsSuccess()
    return self.success and (self.success == 1)
end

Encounter.None = Encounter(nil, _G.UNKNOWN, nil, nil)