local _, AddOn = ...
local Util = AddOn.Libs.Util
local Objects = Util.Objects
local Tables = Util.Tables
local Class = AddOn.Libs.Class
local Models = AddOn.components.Models
local Award = Models.Award
local History = Models.History.History

local Traffic = Class('Traffic', History)
local TrafficStatistics = Class('TrafficStatistics')
local TrafficStatisticsEntry = Class('TrafficStatisticsEntry')

AddOn.components.Models.History.Traffic = Traffic
AddOn.components.Models.History.TrafficStatistics = TrafficStatistics
AddOn.components.Models.History.TrafficStatisticsEntry = TrafficStatisticsEntry

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


-- Loot Statistics
function TrafficStatistics:initialize()
    -- mapping from character name to associated stats
    self.entries = {}
end

function TrafficStatistics:Get(name)
    return self.entries[name]
end

function TrafficStatistics:GetOrAdd(name)
    local entry
    if not Util.Tables.ContainsKey(self.entries, name) then
        entry = TrafficStatisticsEntry()
        self.entries[name] = entry
    else
        entry = self.entries[name]
    end
    return entry
end

function TrafficStatistics:ProcessEntry(entry)
    -- force entry into class instance
    if not Traffic.isInstanceOf(entry, Traffic) then
        entry = Traffic():reconstitute(entry)
    end
    
    local appliesTo = Util(entry.subjects):Copy(function(subject) return subject[1] end):Flip()()
    local stats = Util(appliesTo):Copy(function(_, name) return self:GetOrAdd(name) end, true)()
    for _, si in pairs(stats) do si:AddAward(entry) end
end

function TrafficStatisticsEntry:initialize()
    self.awards = {}
    self.totals = {
        awards = {
        
        }
    }
    self.totalled = false
end

function TrafficStatisticsEntry:AddAward(award)
    if not Tables.ContainsKey(self.awards, award.resourceType) then
       self.awards[award.resourceType] = {}
    end
    
    -- print(Objects.ToString(award, 2))
    -- this tracks resource type to action and amount
    Tables.Push(self.awards[award.resourceType],
                {
                    award.actionType,
                    award.resourceQuantity,
                }
    )
    
    -- todo : do we want to track raids, bosses, etc? if so, it's there - just need to record it
    self.totalled = false
end

function TrafficStatisticsEntry:CalculatePending()
    return not self.totalled and Tables.Count(self.awards) > 0
end

function TrafficStatisticsEntry:CalculateTotals()
    if self:CalculatePending() then
        for rt, actions in pairs(self.awards) do
            local totals = 0
            local count = 0
            for _, oper in pairs(actions) do
                local o, q = unpack(oper)
                if o == Award.ActionType.Add then
                    totals = totals + q
                elseif o == Award.ActionType.Subtract then
                    totals = totals - q
                elseif o == Award.ActionType.Reset then
                    -- this one is different, do we just
                end
                count = count + 1
            end
    
            self.totals.awards[rt] = {
                count = 0,
                total = 0,
            }
            self.totals.awards[rt].count = count
            self.totals.awards[rt].total = totals
        end
    end
    
    -- index is the resource type (i.e. EP and GP)
    -- {awards = {{total = 0, count = 3}, {total = 273, count = 25}}}
    return self.totals
end