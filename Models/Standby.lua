local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util  = AddOn.Libs.Util
local Objects = Util.Objects
local Tables = Util.Tables
local Strings = Util.Strings
local Date = AddOn.components.Models.Date
local DateFormat = AddOn.components.Models.DateFormat
local Logging = AddOn.components.Logging
local UI = AddOn.components.UI
local L = AddOn.components.Locale

local StandbyMember = Class('StandbyMember')
local StandbyStatus = Class('StandbyStatus')

AddOn.components.Models.StandbyMember = StandbyMember
if _G.R2D2_Testing then
    AddOn.components.Models.StandbyStatus = StandbyStatus
end

local fullDf = DateFormat("mm/dd/yyyy HH:MM:SS")
local TsDecorator = UI.ColoredDecorator(0.25, 0.78, 0.92)

local function processContacts(contacts, timestamp)
    local processed = Tables.New()
    -- only support a single name via contacts (if a string)
    if Objects.IsString(contacts) then
        processed[AddOn.Ambiguate(contacts)] = {}
    elseif Objects.IsTable(contacts) then
        for _, name in pairs(contacts) do
            processed[AddOn.Ambiguate(name)] = {}
        end
    else
        error("Invalid type for parameter 'contacts' : " .. contacts and type(contacts) or 'nil')
    end
    
    Tables.Map(
        processed,
        function() return StandbyStatus(timestamp, false) end
    )
    
    return processed
end

function StandbyMember:initialize(name, class, contacts, joined)
    -- If the name is nil, create an empty instance - likely being invoked via reconstitute()
    -- probably not the best approach, but for now it will do
    if Util.Objects.IsNil(name) then return end

    if not Date.isInstanceOf(joined, Date) then
        joined = joined and Date(joined) or Date('utc')
    end

    self.name = name
    self.class = class
    self.joined = joined.time
    self.status = StandbyStatus(self.joined, true)
    self.contacts = processContacts(contacts or {}, self.joined)
end

function StandbyMember:afterReconstitute(instance)
    instance.status = StandbyStatus(instance.status.timestamp, instance.status.online)
    instance.contacts = Util.Tables.Map(
            instance.contacts,
            function(e) return StandbyStatus():reconstitute(e) end
    )
    return instance
end


-- @return the timestamp at which player joined the standby roster, formatted in local TZ in format of mm/dd/yyyy HH:MM:SS
function StandbyMember:JoinedTimestamp()
    return TsDecorator:decorate(fullDf:format(self.joined))
end

function StandbyMember:PingedTimestamp()
    return self.status:PingedTimestamp()
end

function StandbyMember:IsPlayer(name)
    return AddOn:UnitIsUnit(self.name, name)
end

function StandbyMember:IsContact(name)
    for contact, _ in pairs(self.contacts) do
        if AddOn:UnitIsUnit(contact, name) then
            return true
        end
    end
    
    return false
end

function StandbyMember:IsPlayerOrContact(name)
    return self:IsPlayer(name) or self:IsContact(name)
end

function StandbyMember:UpdateStatus(name, online)
    if self:IsPlayer(name) then
        self.status = StandbyStatus(nil, online)
    elseif self:IsContact(name) then
        self.contacts[AddOn.Ambiguate(name)] = StandbyStatus(nil, online)
    end
end

function StandbyMember:IsOnline()
    local online = self.status.online
    if not online then
        online = Tables.CountFn(self.contacts, function(status) return status.online and 1 or 0 end) > 0
    end
    return online
end

local OnlineDecorator = UI.ColoredDecorator(0, 1, 0.59)
local OfflineDecorator = UI.ColoredDecorator(0.77, 0.12, 0.23)

function StandbyStatus:initialize(timestamp, online)
    if not Date.isInstanceOf(timestamp, Date) then
        timestamp = timestamp and Date(timestamp) or Date('utc')
    end
    
    self.timestamp = timestamp.time
    self.online = online
end

function StandbyStatus:PingedTimestamp()
    return TsDecorator:decorate(fullDf:format(self.timestamp))
end

function StandbyStatus:OnlineText()
    return self.online and OnlineDecorator:decorate(L["online"]) or OfflineDecorator:decorate(L["offline"])
end

function StandbyStatus:GetText()
    return Strings.Join("/", self:PingedTimestamp(), self:OnlineText())
end