local MAJOR_VERSION = "LibEncounter-1.0"
local MINOR_VERSION = 11303

local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- Boss localization
local LB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()
-- Zone localization (e.g. raids)
local LZ = LibStub("LibBabble-SubZone-3.0"):GetLookupTable()
local Util = LibStub("LibUtil-1.1")



-- collection of maps (for encounters)
lib.Maps = {

}

-- collection of creatures (for encounters)
lib.Creatures = {

}

-- collection of encounters
lib.Encounters = {

}


function lib:GetCreatureMapId(creatureId)
    local encounters = Util(lib.Encounters)
        :CopyFilter(
            function(v, i)
                return v.creature_id == creatureId
            end
    )()

    if Util.Tables.Count(encounters) == 0 then
        error(("No encounters found for creature id=%s"):format(creatureId))
    end

    if Util.Tables.Count(encounters) > 1 then
        error(("Multiple encounters found for creature id=%s"):format(creatureId))
    end

    return Util.Tables.First(encounters).map_id
end

function lib:GetCreatureName(creatureId)
    local creatureName
    --  map id to the creature, then look up from localization
    local creature = lib.Creatures[creatureId]
    if creature then creatureName = LB[creature.name] end

    return creatureName
end

function lib:GetMapName(mapId)
    local mapName
    --  map id to the map's name key, then look up from localization
    local map = lib.Maps[mapId]
    if map then mapName = LZ[map.name] end

    return mapName
end

function lib:GetCreatureDetail(creatureId)
    local map_id = self:GetCreatureMapId(creatureId)
    return self:GetCreatureName(creatureId), self:GetMapName(map_id)
end

function lib:GetEncounterCreatureId(encounterId)
    local encounter = lib.Encounters[encounterId]
    local creatureId
    
    if encounter then creatureId = encounter.creature_id end
    
    return creatureId
end