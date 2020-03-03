local MAJOR_VERSION = "LibEncounter-1.0"
local MINOR_VERSION = 11303

local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- Boss localization
local LB = LibStub("LibBabble-Boss-3.0")
-- Zone localization (e.g. raids)
local LZ = LibStub("LibBabble-SubZone-3.0")

-- collection of maps (for encounters)
lib.Maps = {

}

-- collection of creatures (for encounters)
lib.Creatures = {

}

-- collection of encounters
lib.Encounters = {

}

-- mapping from creature to encounters
--lib.CreatureEncounters = {
--
--}

function lib:GetCreatureMapId(creature_id)

end

function lib:GetCreatureName(creature_id)
    local creature_name = nil

    --  map id to the creature's name key, then look up from localization
    local creature_name_key = self.Creatures[creature_id]
    if creature_name_key then
        creature_name = LZ[creature_name_key]
    end

    return creature_name
end

function lib:GetMapName(map_id)
    local map_name = nil
    --  map id to the map's name key, then look up from localization
    local map_name_key = self.Maps[map_id]
    if map_name_key then
        map_name = LB[map_name_key]
    end

    return map_name
end

function lib:GetCreatureDetail(creature_id)
    local map_id = GetCreatureMapId(creature_id)
    return self:GetMapName(map_id), self:GetCreatureName(creature_id)
end