local _, AddOn = ...
local TrafficHistory= AddOn:NewModule("TrafficHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging       = AddOn.Libs.Logging
local Util          = AddOn.Libs.Util
local Objects       = Util.Objects
local Tables        = Util.Tables
local UI            = AddOn.components.UI
local L             = AddOn.components.Locale
local Models        = AddOn.components.Models
local Traffic       = Models.History.Traffic

TrafficHistory.options = {
    name = 'Traffic History',
    desc = 'Traffic History Description',
    ignore_enable_disable = true,
    args = {
        openHistory = {
            order = 5,
            name = "Open Traffic History",
            desc = "Desc",
            type = "execute",
            func = function()
                AddOn:CallModule("TrafficHistory")
            end,
        },
    },
}

TrafficHistory.defaults = {
    profile = {
        enabled = true,
    }
}

function TrafficHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.Libs.AceDB:New('R2D2_TrafficDB', TrafficHistory.defaults)
end

function TrafficHistory:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end

function TrafficHistory:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
end

function TrafficHistory:EnableOnStartup()
    return false
end

function TrafficHistory:GetHistory()
    return self.db.factionrealm
end

function TrafficHistory:AddEntry(entry)
    local history = self:GetHistory()
    tinsert(history, entry:toTable())
end

-- @param actionType see Models.History.Traffic.ActionType
-- @param subjectType see Models.History.Traffic.SubjectType
-- @param subjects the subject names for specified subject type (e.g. characters)
-- @param resourceType see Models.History.Traffic.ResourceType
-- @param resourceQuantity the quantity for specified resource type
-- @param desc the description for entry
-- @param beforeSend an optional function to invoke with created entry prior to sending out (via message and command)
function TrafficHistory:CreateEntry(actionType, subjectType, subjects, resourceType, resourceQuantity, desc, beforeSend)
    local C = AddOn.Constants
    if (AddOn:TestModeEnabled() and not AddOn:DevModeEnabled()) then return end
    local entry = Traffic()
    entry.actor = AddOn.playerName
    entry:SetAction(actionType)
    entry:SetSubjects(subjectType, Objects.IsTable(subjects) and unpack(subjects) or subjects)
    entry:SetResource(resourceType, resourceQuantity)
    entry.description = desc
    entry:Finalize()
    
    -- if there was a function specified for callback before sending, invoke it now with the entry
    if beforeSend and Objects.IsFunction(beforeSend) then beforeSend(entry) end
    
    AddOn:SendMessage(C.Messages.TrafficHistorySend, entry)
    -- todo : support settings for sending and tracking history
    -- todo : send to guild or group? guild for now
    AddOn:SendCommand(C.guild, C.Commands.TrafficHistoryAdd, entry)
    return entry
end

-- @param actionType see Models.History.Traffic.ActionType
-- @param subjectType see Models.History.Traffic.SubjectType
-- @param resourceType see Models.History.Traffic.ResourceType
-- @param lootHistoryEntry the loot history entry associated with traffic entry
-- @param desc the description for entry
function TrafficHistory:CreateFromLootHistory(actionType, subjectType, resourceType, lootHistoryEntry, awardData)
    local baseGp, awardGp = awardData.baseGp, awardData.awardGp
    
    local function BeforeSend(entry)
        entry.lootHistoryId = lootHistoryEntry.id
        -- copy over attributes to traffic entry which are relevant
        -- could ignore them and rely upon loot history for later retrieval, but there's no guarantee
        -- the loot and traffic histories are not pruned independently
        for _, attr in pairs(Tables.New('item', 'mapId', 'instance', 'boss', 'response', 'responseId', 'typeCode')) do
            Logging:Debug("CreateFromLootHistory(%s)", tostring(attr))
            entry[attr] = lootHistoryEntry[attr]
        end
        
        entry.baseGp = baseGp
        entry.awardScale = awardData.awardScale
    end
    
    return self:CreateEntry(
            actionType,
            subjectType,
            {lootHistoryEntry.owner},
            resourceType,
            awardGp and awardGp or baseGp,
            "",
            BeforeSend
    )
end