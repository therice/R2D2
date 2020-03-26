local _, AddOn = ...
local Class     = AddOn.Libs.Class

local Candidate = Class('Candidate')
local CandidateResponse = Class('CandidateResponse')

AddOn.components.Models.Candidate = Candidate
AddOn.components.Models.CandidateResponse = CandidateResponse

function Candidate:initialize(name, class, rank, enchanter, lvl, ilvl)
    self.name        = name
    self.class       = class
    self.rank        = rank or ""
    self.enchanter   = enchanter
    self.enchant_lvl = lvl
    self.item_lvl    = ilvl
end

function CandidateResponse:initialize(name, class, rank)
    self.name = name
    self.class = class
    self.rank = rank
    self.response = "ANNOUNCED"
    self.ilvl = ""
    self.diff = ""
    self.gear1 = nil
    self.gear2 = nil
    self.note = nil
    self.roll = nil
end

function CandidateResponse:Set(key, value)
    self[key] = value
end

function CandidateResponse:Get(key)
    return self[key]
end