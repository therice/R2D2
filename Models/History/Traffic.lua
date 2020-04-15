local _, AddOn = ...
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local GuildStorage = AddOn.Libs.GuildStorage
local History = AddOn.components.Models.History.History
local UI = AddOn.components.UI


local Traffic = Class('Traffic', History)

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

Traffic.ActionType = ActionType
Traffic.TypeIdToAction = tInvert(ActionType)

Traffic.SubjectType = SubjectType
Traffic.TypeIdToSubject = tInvert(SubjectType)

Traffic.ResourceType = ResourceType
Traffic.TypeIdToResource = tInvert(ResourceType)

function Traffic:initialize(instant)
    History.initialize(self, instant)
    -- the name of the actor which performed the action
    self.actor = nil
    -- the type of performed action
    self.actionType = nil
    -- the type of the subject on which action was performed
    self.subjectType = nil
    -- the subjects of the action
    self.subjects = {}
    -- the type of the resource, for specified subject, on which action was performed
    self.resourceType = nil
    -- the value of the resource before the action
    self.resourceBefore = nil
    -- the quantity of the performed action
    self.resourceQuantity = nil
    -- an optional description of traffic
    self.description = nil
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

function Traffic:SetSubjects(type, ...)
    if not Tables.ContainsValue(SubjectType, type) then
        error("Invalid Subject Type specified")
    end
    
    self.subjectType = type
    if self.subjectType == ActionType.Character then
        self.subjects = Tables.New(...)
    else
        local subjects = Tables.New(...)
        if Tables.Count(subjects) == 0 then
            if self.subjectType == SubjectType.Guild then
                subjects = GuildStorage:GetMembers()
                for name, _ in pairs(subjects) do
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
    Logging:Debug("%s", Util.Objects.ToString(self.subjects))
    Tables.Map(self.subjects, function(subject)
        Logging:Debug("%s => %s", subject, tostring(AddOn:GetUnitClass(subject) or "UNKNOWN"))
        return {subject, AddOn:GetUnitClass(subject)}
    end)
    Logging:Debug("%s", Util.Objects.ToString(self.subjects))
end

function Traffic:SetAction(type)
    if not Tables.ContainsValue(ActionType, type) then
        error("Invalid Action Type specified")
    end
    
    self.actionType = type
end

function Traffic:SetResource(type, quantity)
    -- you don't have to specify a resource type if already set
    if Util.Objects.IsSet(type) then
        if not Tables.ContainsValue(ResourceType, type) then error("Invalid Resource Type specified") end
        self.resourceType = type
    end
    
    if not Util.Objects.IsNumber(quantity) then error("Resource Quantity must be a number") end
    
    self.resourceQuantity = quantity
end

function Traffic:Finalize()
    -- this step only applicable for invidiual characters
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