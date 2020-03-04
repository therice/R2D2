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


function lib:GetCreatureMapId(creature_id)
    local map_id

    local encounters = Util(lib.Encounters)
        :CopyFilter(
            function(v, i)
                return v.creature_id == creature_id
            end
    )

    print(Util.Objects.ToString(encounters))

end

function lib:GetCreatureName(creature_id)
    local creature_name
    --  map id to the creature, then look up from localization
    local creature = lib.Creatures[creature_id]
    if creature then
        creature_name = LB[creature.name]
    end

    return creature_name
end

function lib:GetMapName(map_id)
    local map_name
    --  map id to the map's name key, then look up from localization
    local map = lib.Maps[map_id]
    if map then
        map_name = LZ[map.name]
    end

    return map_name
end

function lib:GetCreatureDetail(creature_id)
    local map_id = GetCreatureMapId(creature_id)
    return self:GetMapName(map_id), self:GetCreatureName(creature_id)
end