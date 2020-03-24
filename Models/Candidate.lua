local _, AddOn = ...
local Util = AddOn.Libs.Util

local Candidate = { }
Candidate.__index = Candidate

AddOn.components.Models.Candidate = Candidate

function Candidate:New(name, class, rank, enchanter, lvl, ilvl)
    local instance = {
        name        = name,
        class       = class,
        rank        = rank or "",
        enchanter   = enchanter,
        enchant_lvl = lvl,
        item_lvl    = ilvl,
    }
    return setmetatable(instance, Candidate)
end

function Candidate:Reconstitute(instance)
    return setmetatable(instance, Candidate)
end

function Candidate:Clone()
    local copy = Util.Tables.Copy(self)
    return setmetatable(copy, Candidate)
end
