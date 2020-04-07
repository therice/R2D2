local _, AddOn = ...
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local GuildStorage = AddOn.Libs.GuildStorage
local History = AddOn.components.Models.History.History


local Traffic = Class('Traffic')
local EpTraffic = Class('EpTraffic', Traffic)
local GpTraffic = Class('GpTraffic', Traffic)

AddOn.components.Models.History.Traffic = Traffic
AddOn.components.Models.History.EpTraffic = EpTraffic
AddOn.components.Models.History.GpTraffic = GpTraffic

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
    -- the quantity of the performed action
    self.resourceQuantity = nil
    -- an optional description of traffic
    self.description = nil
end

function Traffic:SetSubjects(type, ...)
    if not Tables.ContainsValue(SubjectType, type) then
        error("Invalid Subject Type specified")
    end
    
    self.subjectType = type
    if self.subjectType == ActionType.Character then
        self.subjects = {...}
    else
        local subjects = {...}
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
        if not Tables.ContainsValue(ResourceType, type) then
            error("Invalid Resource Type specified")
        end
        self.resourceType = type
    end
    
    if not Util.Objects.IsNumber(quantity) then
        error("Resource Quantity must be a number")
    end
    self.resourceQuantity = quantity
end

function EpTraffic:initialize(instant)
    Traffic.initialize(self, instant)
    self.resourceType = ResourceType.Ep
end

function GpTraffic:initialize(instant)
    Traffic.initialize(self, instant)
    self.resourceType = ResourceType.Gp
end