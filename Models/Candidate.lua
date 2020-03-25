local _, AddOn = ...
local Class     = AddOn.Libs.Class

local Candidate = Class('Candidate')

AddOn.components.Models.Candidate = Candidate

function Candidate:initialize(name, class, rank, enchanter, lvl, ilvl)
    self.name        = name
    self.class       = class
    self.rank        = rank or ""
    self.enchanter   = enchanter
    self.enchant_lvl = lvl
    self.item_lvl    = ilvl
end