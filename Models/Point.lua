local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util  = AddOn.Libs.Util

local GuildMember = AddOn.components.Models.GuildMember
local PointEntry = Class('PointEntry', GuildMember)

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

function PointEntry:initialize(name, class, rank, rankIndex, ep, gp)
    GuildMember.initialize(self, name, class, rank, rankIndex)
    self.ep = ep
    self.gp = gp
end

function PointEntry:FromGuildMember(member)
    local ep, gp = DecodeNode(member.officerNote)
    return PointEntry:new(member.name, member.class, member.rank, member.rankIndex, ep, gp)
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