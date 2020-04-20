local _, AddOn = ...
local Util = AddOn.Libs.Util
local Objects = Util.Objects
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local Award = AddOn.components.Models.Award
local History = AddOn.components.Models.History.History

local Traffic = Class('Traffic', History)

AddOn.components.Models.History.Traffic = Traffic

function Traffic:initialize(instant, data)
    History.initialize(self, instant)
    
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
    
    if data then
        if not Award.isInstanceOf(data, Award) then
            error("The specified data was not of the correct type : " .. type(data))
        end
        Tables.CopyInto(self, data:toTable())
        -- if there was an item with data, nil it out - we don't need entire thing
        self.item = nil
    end
    
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
    if self.subjectType == Award.SubjectType.Character and Tables.Count(self.subjects) == 1 then
        if self.resourceType then
            --Logging:Debug('Finalize(%s) : %s', self.subjects[1], AddOn.Ambiguate(self.subjects[1]))
            local ep, gp, _ = AddOn:PointsModule().Get(self.subjects[1][1])
            if self.resourceType == Award.ResourceType.Ep then
                self.resourceBefore = ep
            elseif self.resourceType == Award.ResourceType.Gp then
                self.resourceBefore = gp
            end
        end
    end
end