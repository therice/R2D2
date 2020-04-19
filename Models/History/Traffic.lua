local _, AddOn = ...
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local Objects = Util.Objects
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local GuildStorage = AddOn.Libs.GuildStorage
local History = AddOn.components.Models.History.History

local Award = Class('Award', History)
local Traffic = Class('Traffic', Award)

AddOn.components.Models.History.Award = Award
AddOn.components.Models.History.Traffic = Traffic

local ActionType = {
    Add      = 1,
    Subtract = 2,
    Reset    = 3,
}

local SubjectType = {
    Character = 1, -- one or more named characters
    Guild     = 2, -- guild members
    Raid      = 3, -- raid members
}

local ResourceType = {
    Ep  = 1,
    Gp  = 2,
}

-- doubling of references is due to re-factoring and numerous usages of existing Traffic refs
-- only the Award ones should really exist, with all existing references to Traffic changed

Award.ActionType = ActionType
Award.TypeIdToAction = tInvert(ActionType)

Traffic.ActionType = Award.ActionType
Traffic.TypeIdToAction = Award.TypeIdToAction

Award.SubjectType = SubjectType
Award.TypeIdToSubject = tInvert(SubjectType)

Traffic.SubjectType = Award.SubjectType
Traffic.TypeIdToSubject = Award.TypeIdToSubject

Award.ResourceType = ResourceType
Award.TypeIdToResource = tInvert(ResourceType)

Traffic.ResourceType = Award.ResourceType
Traffic.TypeIdToResource = Award.TypeIdToResource


function Award:initialize(instant, data)
    History.initialize(self, instant)
    
    -- if data was specified, and not a table of instance of this class - that's an error
    if data and not(Objects.IsTable(data) or Award.isInstanceOf(data, Award)) then
        error("The specified Award data was not of the appropriate type : " + type(data))
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
end

function Award:GetSubjectOriginText()
    return Traffic.TypeIdToSubject[self.subjectType]
end

function Award:SetSubjects(type, ...)
    if not Tables.ContainsValue(SubjectType, type) then
        error("Invalid Subject Type specified")
    end
    Logging:Debug("SetSubjects(%s)", tostring(type))
    
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


function Traffic:initialize(instant, data)
    Award.initialize(self, instant, data)
    
    -- the name of the actor which performed the action
    self.actor = nil
    -- the class of the actor which performed the action
    self.actorClass = nil
    -- the value of the resource before the action
    self.resourceBefore = nil
    -- an optional identifier for the loot history entry associated with this traffic entry
    -- this will only be set for GP resource types and as a result of that loot
    -- being awarded to this entry's subject
    self.lootHistoryId = nil
    
    --[[
    There are additional (optional) attributes which may be set based upon origin of traffic
    
    E.G. #1 map, instance, and boss will be set for GP/EP traffic from an instance encounter
    E.G. #2 item, response, and responseId will be set for GP traffic from an item award
    
    If a traffic entry is created from a user initiated action, such as manual award of GP/EP, then these
    attributes won't be present
    --]]
end

function Traffic:Finalize()
    -- this step only applicable for individual characters
    if self.subjectType == SubjectType.Character and Tables.Count(self.subjects) == 1 then
        if self.resourceType then
            --Logging:Debug('Finalize(%s) : %s', self.subjects[1], AddOn.Ambiguate(self.subjects[1]))
            local ep, gp, _ = AddOn:PointsModule().Get(self.subjects[1][1])
            if self.resourceType == ResourceType.Ep then
                self.resourceBefore = ep
            elseif self.resourceType == ResourceType.Gp then
                self.resourceBefore = gp
            end
        end
    end
end