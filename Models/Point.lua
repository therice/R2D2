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
    Decay    = 4,
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
    local text = Award.TypeIdToSubject[self.subjectType]
    local subjectCount = Util.Tables.Count(self.subjects)
    
    if self.subjectType ~= Award.SubjectType.Character and subjectCount ~= 0 then
        text = text .. "(" .. subjectCount .. ")"
    end
    return text
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
                --[[
                    GetInstanceInfo() in IronForge (not in group/raid and not in an instance/dungeon)
                    
                    #{GetInstanceInfo()} == 9
                    
                    'Eastern Kingdoms' (zoneName)
                    none (instanceType)
                    0 (difficultyID)
                    0 (difficultyName)
                    0 (maxPlayers)
                    false (dynamicDifficulty)
                    0 (isDynamic)
                    0 (instanceMapID)
                    nil (instanceGroupSize)
                    
                    https://wowwiki.fandom.com/wiki/API_GetInstanceInfo
                    
                    zoneName, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty,
                        isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo()
				                    
                --]]
                -- todo : as coded, this is not currently working. need to do some testing in raids to sor out
                -- UnitExists / UnitIsConnected / UnitPosition
                -- GetNumGroupMembers vs GetNumRaidMembers
                local instanceName, _, _, _, _, _, _, instanceId = GetInstanceInfo()
                local function IsOnlineAndInInstance(zone, online)
                    local function InZone()
                        -- zone can be nil under certain conditions, if nil then ignore it
                        if Util.Strings.IsSet(zone) then
                            -- likely redundant since passing in online parameter
                            if Util.Strings.Equal(zone, "Offline") then return false end
                            
                            return Util.Strings.Equal(instanceName, zone) or
                                   Util.Strings.Equal(GetRealZoneText(instanceId), zone)
                        end
                        
                        return true
                    end
                    
                    -- online is a number, with 1 being online and otherwise nil
                    return online == 1 and InZone()
                end
    
                Logging:Debug("SetSubjects() : instanceName=%s instanceId=%s", tostring(instanceName), tostring(instanceId))
                
                for i = 1, GetNumGroupMembers() do
                    -- the returned player name won't have realm, so convert using UnitName
                    -- https://wow.gamepedia.com/API_GetRaidRosterInfo
                    local name, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
                    Logging:Debug("SetSubjects(%s) : online=%s zone=%s", tostring(name), tostring(online), tostring(zone))
                    
                    -- be extra careful and use pcall to trap any errors in the evaluation
                    -- if it fails, we'll add the player by default
                    -- local check, add = pcall(function() return IsOnlineAndInInstance(zone, online) end)
                    --
                    -- until the check can be addressed, only check if player is online
                    if not online then
                        Logging:Debug("SetSubjects() : Omitting %s from award, online=%s zone=%s",
                                      tostring(name), tostring(online), tostring(zone)
                        )
                    else
                        Tables.Push(subjects, AddOn:UnitName(name))
                    end
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


function Award:ToAnnouncement()
    local resource, subject = Award.TypeIdToResource[self.resourceType]:upper(), nil
    
    if self.subjectType == SubjectType.Character then
        subject = self.subjects[1][1]
    else
        subject = Award.TypeIdToSubject[self.subjectType]
    end
    
    if Util.Objects.In(self.actionType, ActionType.Add, ActionType.Subtract) then
        -- "X EP added to name"
        return format(
                "%d %s %s %s %s (%s)",
                self.resourceQuantity,
                resource,
                Award.TypeIdToAction[self.actionType]:lower() .. "ed", -- added, subtracted
                self.actionType == ActionType.Add and "to" or "from",
                subject,
                self.description and self.description or "N/A"
        )
    elseif self.actionType == ActionType.Decay then
        -- "Decayed EP for Guild by X%"
        return format(
                "Decayed %s for %s by %d %%",
                resource,
                subject,
                self.resourceQuantity * 100
        )
    elseif self.actionType == ActionType.Reset then
        -- "Reset EP for X"
        return format(
                "Reset %s for %s",
                resource,
                subject
        )
    else
        return "Unhandled Award Announcement (this is a bug)"
    end
end
