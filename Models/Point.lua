local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util  = AddOn.Libs.Util
local Objects = Util.Objects
local Tables = Util.Tables
local Logging = AddOn.Libs.Logging
local GuildStorage = AddOn.Libs.GuildStorage


local GuildMember = AddOn.components.Models.GuildMember
local PointEntry = Class('PointEntry', GuildMember)
local Award = Class('Award')

AddOn.components.Models.PointEntry = PointEntry
AddOn.components.Models.Award = Award

local function MinimumGp()
    return AddOn:GearPointsModule().db.profile.gp_min
end

local function NormalizeGp(gp)
    return math.max(gp, MinimumGp())
end

local function DecodeNode(note)
    if Util.Objects.IsSet(note) then
        local ep, gp = string.match(note, "^(%d+),(%d+)$")
        if ep and gp then
            return tonumber(ep), NormalizeGp(gp)
        end
    end
    return 0, MinimumGp()
end

local function EncodeNote(ep, gp)
    return string.format("%d,%d", math.max(ep, 0), NormalizeGp(gp))
end

function PointEntry:initialize(name, class, rank, rankIndex, ep, gp)
    GuildMember.initialize(self, name, class, rank, rankIndex)
    self.ep = ep
    self.gp = NormalizeGp(gp)
end

function PointEntry:FromGuildMember(member)
    local ep, gp = DecodeNode(member.officerNote)
    return PointEntry:new(member.name, member.class, member.rank, member.rankIndex, ep, gp)
end

function PointEntry:GetPR()
    return Util.Numbers.Round(self.ep / NormalizeGp(self.gp), 2)
end

function PointEntry:Get()
    return self.ep, self.gp, self:GetPR()
end

function PointEntry:ToNote()
    return EncodeNote(self.ep, self.gp)
end


local ActionType = {
    Add      = 1,
    Subtract = 2,
    Reset    = 3,
}

local SubjectType = {
    Character = 1, -- one or more named characters
    Guild     = 2, -- guild members
    Raid      = 3, -- raid members
    Standby   = 4, -- standby/bench members
}

local ResourceType = {
    Ep  = 1,
    Gp  = 2,
}

Award.ActionType = ActionType
Award.TypeIdToAction = tInvert(ActionType)

Award.SubjectType = SubjectType
Award.TypeIdToSubject = tInvert(SubjectType)

Award.ResourceType = ResourceType
Award.TypeIdToResource = tInvert(ResourceType)

function Award:initialize(data)
    -- if data was specified, and not a table
    if data and not(Objects.IsTable(data)) then
        error("The specified data was not of the appropriate type : " + type(data))
    end
    
    -- the type of performed award
    self.actionType = data and data.actionType or nil
    -- the type of the subject on which award was performed
    self.subjectType = data and data.subjectType or nil
    -- the subjects of the award
    self.subjects = data and data.subjects or nil
    -- the type of the resource, for specified subject, on which award was performed
    self.resourceType = data and data.resourceType or nil
    -- the quantity of the award
    self.resourceQuantity = data and data.resourceQuantity or nil
    -- an optional description of award
    self.description = data and data.description or nil
    -- in the case of award being associated with an item, this will be set
    -- if set, will be of type ItemAward
    self.item = nil
end

function Award:GetSubjectOriginText()
    return Award.TypeIdToSubject[self.subjectType]
end

function Award:SetSubjects(type, ...)
    if not Tables.ContainsValue(SubjectType, type) then
        error("Invalid Subject Type specified")
    end
    -- Logging:Debug("SetSubjects(%s)", tostring(type))
    
    self.subjectType = type
    if self.subjectType == ActionType.Character then
        self.subjects = Tables.New(...)
    else
        local subjects = Tables.New(...)
        -- Logging:Debug("SetSubjects() : current subject count is %d, %s", Tables.Count(subjects), Objects.ToString(subjects))
        if Tables.Count(subjects) == 0 then
            if self.subjectType == SubjectType.Guild then
                for name, _ in pairs(GuildStorage:GetMembers()) do
                    -- Logging:Debug("Adding %s", name)
                    Tables.Push(subjects, name)
                end
            elseif self.subjectType == SubjectType.Raid then
                for i = 1, GetNumGroupMembers() do
                    local name = GetRaidRosterInfo(i)
                    Tables.Push(subjects, name)
                end
            end
        end
        
        if Tables.Count(subjects) == 0 then
            Logging:Warn("SetSubjects(%d) : No subjects could be discovered", self.subjectType)
        end
        
        self.subjects = subjects
    end
    
    --Logging:Debug("%s", Util.Objects.ToString(self.subjects))
    Tables.Map(self.subjects, function(subject)
        -- Logging:Debug("%s => %s", subject, tostring(AddOn:GetUnitClass(subject) or "UNKNOWN"))
        return {subject, AddOn:GetUnitClass(subject)}
    end)
    --Logging:Debug("%s", Util.Objects.ToString(self.subjects))
end

function Award:SetAction(type)
    if not Tables.ContainsValue(ActionType, type) then
        error("Invalid Action Type specified")
    end
    
    self.actionType = type
end

function Award:SetResource(type, quantity)
    -- you don't have to specify a resource type if already set
    if Util.Objects.IsSet(type) then
        if not Tables.ContainsValue(ResourceType, type) then error("Invalid Resource Type specified") end
        self.resourceType = type
    end
    
    if not Util.Objects.IsNumber(quantity) then error("Resource Quantity must be a number") end
    
    self.resourceQuantity = quantity
end


