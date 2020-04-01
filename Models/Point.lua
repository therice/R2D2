local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util  = AddOn.Libs.Util

local PointEntry = Class('PointEntry')

AddOn.components.Models.PointEntry = PointEntry

local function DecodeNode(note)
    if Util.Objects.IsSet(note) then
        local ep, gp = string.match(note, "^(%d+),(%d+)$")
        if ep and gp then
            return tonumber(ep), tonumber(gp)
        end
    end
    return 0, 0
end

local function EncodeNote(ep, gp)
    return string.format("%d,%d", math.max(ep, 0), math.max(gp, 0))
end

function PointEntry:initialize(name, ep, gp, rank, rankIndex, class)
    self.name = name
    self.ep = ep
    self.gp = gp
    self.rank = rank
    self.rankIndex = rankIndex
    self.class = class
end

function PointEntry:FromGuildMember(member)
    local ep, gp = DecodeNode(member.note)
    return PointEntry:new(member.name, ep, gp, member.rank, member.rankIndex, member.class)
end

function PointEntry:GetPR()
    return Util.Numbers.Round(self.ep / math.max(self.gp, 1), 2)
end

function PointEntry:Get()
    return self.ep, self.gp, self:GetPR()
end

function PointEntry:ToNote()
    return EncodeNote(self.ep, self.gp)
end