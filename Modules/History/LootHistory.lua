local _, AddOn = ...
local LootHistory   = AddOn:NewModule("LootHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging       = AddOn.Libs.Logging
local Util          = AddOn.Libs.Util
local L             = AddOn.components.Locale
local Models        = AddOn.components.Models

LootHistory.options = {
    name = 'Loot History',
    desc = 'Loot History Description',
    args = {
    
    }
}

LootHistory.defaults = {
    profile = {
        enabled = true,
    }
}


function LootHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    -- loot history
    self.db = AddOn.Libs.AceDB:New('R2D2_LootDB', LootHistory.defaults)
end

function LootHistory:GetHistory()
    return self.db.factionrealm
end

function LootHistory:AddEntry(winner, entry)
    local history = self:GetHistory()
    if history[winner] then
        tinsert(history[winner], entry:toTable())
    else
        history[winner] = { entry:toTable() }
    end
end

function LootHistory:CreateEntry(winner, link, responseId, boss, reason, session, candidateData)
    local C = AddOn.Constants
    
    -- if in test mode and not development mode, return
    if (AddOn:TestModeEnabled() and not AddOn:DevModeEnabled()) then return end
    
    local ML = AddOn:MasterLooterModule()
    local itemEntry = ML:GetItem(session)
    local equipLoc = itemEntry and itemEntry.equipLoc or "default"
    local typeCode = itemEntry and itemEntry.typeCode
    local response = AddOn:GetResponse(typeCode or equipLoc, responseId)
    -- https://wow.gamepedia.com/API_GetInstanceInfo
    -- name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic,
    --  instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
    local instanceName, _, _, _, _, _, _, instanceId, groupSize = GetInstanceInfo()
    local candidate = ML:GetCandidate(winner)
    Logging:Debug("AddEntry() : %s, %s, %s, %s, %s, %s, %s",
                  winner, link, responseId, tostring(boss), tostring(reason), session, Util.Objects.ToString(candidateData))
   
    local entry = Models.History.Loot()
    entry.item = link
    entry.instance = instanceName
    entry.mapId = instanceId
    entry.boss = boss or _G.UNKNOWN
    entry:SetOrigin(reason and true or false)
    entry.response = reason and reason.text or response.text
    entry.responseId = reason and reason.sort - 400 or responseId
    entry.color = reason and reason.color or response.color
    entry.class = candidate.class
    entry.groupSize = groupSize
    entry.note = candidateData and candidateData.note or nil
    entry.owner = itemEntry and itemEntry.owner or winner
    entry.typeCode = itemEntry and itemEntry.typeCode
    
    AddOn:SendMessage(C.Messages.LootHistorySend, entry, winner, responseId, boss, reason, session, candidateData)
    -- todo : support settings for sending and tracking history
    -- todo : send to guild or group? group for now
    AddOn:SendCommand(C.group, C.Commands.LootHistoryAdd, winner, entry)
    return entry
end

--[[
stats[candidate_name] = {
	[item#] = { -- 5 latest items won
		[1] = lootWon,
		[2] = formatted response string,
		[3] = {color}, -- color format for responses
		[4] = #index,  -- entry index in history[name][index]
	},
	totals = {
		total = total loot won number,
		responses = {
			[i] = {
				[1] = responseText,
				[2] = number of items won,
				[3] = {color},
				[4] = responseId, -- entry index for self.responses. award reasons gets 100 added
			}
		},
		raids = {
			-- each index is a unique raid id made by combining the date and instance
			[xxx] = number of loot won in this raid,
			num = the number of raids
		}
	}
}
--]]
-- todo : make this not suck
function LootHistory:GetStatistics()
    Logging:Trace("GetStatistics()")
    --local check, ret = pcall(
    --        function()
    --            local moreInfoEntries = AddOn:GetNumButtons('default')
    --            local currentTs = Models.Date()
    --
    --            stats = {}
    --            local entry, id
    --            for name, data in pairs(self:GetHistory()) do
    --                local count, responseText, color, raids, latestAwardFound = {}, {},  {}, {}, 0
    --                stats[name] = {}
    --                -- start from end (oldest)
    --                for i = #data, 1, -1 do
    --                    entry = Models.History.Loot():reconstitute(data[i])
    --                    id = entry.responseId
    --                    -- may be string, e.g. "PASS"
    --                    if Util.Objects.IsNumber(id) then
    --                        -- Bump to distinguish from normal awards
    --                        if entry:IsAwardReason() then id = id + 100 end
    --                    end
    --
    --                    count[id] = count[id] and count[id] + 1 or 1
    --                    responseText[id] = responseText[id] and responseText[id] or entry.response
    --                    -- If it's not already added
    --                    if (not color[id] or unpack(color[id],1,3) == unpack{1,1,1}) and
    --                        (entry.color and #entry.color ~= 0)  then
    --                        color[id] = #entry.color ~= 0 and #entry.color == 4 and entry.color or {1,1,1}
    --                    end
    --
    --                    if latestAwardFound < 5 and Util.Objects.IsNumber(id) and not entry:IsAwardReason() and id <= moreInfoEntries then
    --                        local ts = entry:TimestampAsDate()
    --                        Util.Tables.Push(stats[name],
    --                                 {
    --                                     entry.item,
    --                                     format(L["n_ago"], AddOn:ConvertIntervalToString(currentTs:diff(ts):Duration())),
    --                                     color[id],
    --                                     i
    --                                 }
    --                        )
    --                        latestAwardFound = latestAwardFound + 1
    --                    end
    --
    --                    -- if instances span days (e.g. start's on Tuesday and end on Weds), this won't count
    --                    -- raids correctly
    --                    local formattedTs = entry:FormattedDate()
    --                    local raidKey =  formattedTs .. '_' .. entry.instance
    --                    raids[raidKey] = raids[raidKey] and (raids[raidKey] + 1) or 0
    --                end
    --
    --                local total = 0
    --                stats[name].totals = {}
    --                stats[name].totals.responses = {}
    --                for id, num in pairs(count) do
    --                    Util.Tables.Push(stats[name].totals.responses,
    --                         {
    --                            responseText[id],
    --                            num,
    --                            color[id],
    --                            id
    --                         }
    --                    )
    --                    total = total + 1
    --                end
    --
    --                stats[name].totals.total = total
    --                stats[name].totals.raids = raids
    --
    --                total = 0
    --                for _ in pairs(raids) do total = total + 1 end
    --                stats[name].totals.raids.num = total
    --            end
    --
    --            Logging:Debug("GetStatistics() : %s", Util.Objects.ToString(stats, 10))
    --            return stats
    --        end
    --)
    
    local check, ret = pcall(
            function()
                local stats = Models.History.LootStatistics()
                
                for name, data in pairs(self:GetHistory()) do
                    local statsEntry
                    
                    for i = #data, 1, -1 do
                        statsEntry = stats:ProcessEntry(name, data[i], i)
                    end
                end
    
                -- Logging:Debug("GetStatistics() : %s", Util.Objects.ToString(stats, 10))
                return stats
            end
    )
    
    if not check then
        Logging:Warn("Error processing Loot History")
        AddOn:Print("Error processing Loot History")
    else
        return ret
    end
end

