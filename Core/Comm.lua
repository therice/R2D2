local _, AddOn = ...
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Objects   = Util.Objects
local L         = AddOn.components.Locale
local Models    = AddOn.components.Models
local ItemUtil  = AddOn.Libs.ItemUtil

function AddOn:GetAnnounceChannel(channel)
    local C = AddOn.Constants
    return channel == C.group and (IsInRaid() and C.Channels.Raid or C.Channels.Party) or channel
end


function AddOn:SendAnnouncement(msg, channel)
    Logging:Trace("SendAnnouncement(%s) : %s", channel, msg)

    local C = AddOn.Constants
    if channel == C.Channels.None then return end
    if self.testMode then
        msg = "(" .. L["test"] .. ") " .. msg
    end

    if (not IsInGroup() and Objects.In(channel, C.group, C.Channels.Raid, C.Channels.RaidWarning, C.Channels.Party, C.Channels.Instance))
            or channel == C.chat
            or (not IsInGuild() and Objects.In(channel, C.Channels.Guild, C.Channels.Officer)) then
        self:Print(msg)
    elseif (not IsInRaid() and Objects.In(channel, C.Channels.Raid, C.Channels.RaidWarning)) then
        SendChatMessage(msg, C.party)
    else
        SendChatMessage(msg, AddOn:GetAnnounceChannel(channel))
    end
end


function AddOn:SendCommand(target, command, ...)
    local C = AddOn.Constants
    -- send all data as a table, and let receiver unpack it
    local toSend = self:Serialize(command, {...})
    local prefix = C.name

    Logging:Trace("SendCommand(%s, %s) : %s", target, command, Util.Objects.ToString(toSend))

    if target == C.group then
        -- raid
        if IsInRaid() then
            self:SendCommMessage(prefix, toSend, self:IsInNonInstance() and C.Channels.Instance or C.Channels.Raid)
        -- party
        elseif IsInGroup() then
            self:SendCommMessage(prefix, toSend, self:IsInNonInstance() and C.Channels.Instance or C.Channels.Party)
        -- alone (testing)
        else
            self:SendCommMessage(prefix, toSend, C.Channels.Whisper, self.playerName)
        end
    elseif target == C.guild then
        self:SendCommMessage(prefix, toSend, C.Channels.Guild)
    else
        -- If target == "player"
        if self:UnitIsUnit(target, C.player) then
            self:SendCommMessage(prefix, toSend, C.Channels.Whisper, self.playerName)
        else
            self:SendCommMessage(prefix, toSend, C.Channels.Whisper, target)
        end
    end
end

--[[
DEBUG [03/23/20 13:46:06] (Comm.lua:42): SendCommand(group, LootAck) :
^1^SLootAck^T^N1^SDebugme-Atiesh^N3^T^Sresponse^T^t^Sdiff^T^N1^N0^N2^N0^N3^N0^N4^N0^t^Sgear1^T^t^Sgear2^T^t^t^t^^

DEBUG [03/23/20 13:46:07] (LootAllocate.lua:257): OnCommReceived() :
success=true, command=LootAck, data={Debugme-Atiesh, 3 = {gear2 = {}, gear1 = {}, diff = {0, 0, 0, 0}, response = {}}}
DEBUG [03/23/20 13:46:07] (LootAllocate.lua:252): OnCommReceived() :
prefix=R2D2, via=WHISPER, sender=Debugme
--]]

-- Sends a response.
-- @paramsig session [, ...]
-- link, ilvl, and equipLoc must be provided to send out gear information.
-- @param target 		The target of response
-- @param session		The session to respond to.
-- @param response		The selected response, must be index of db.responses.
-- @param note			The player's note.
-- @param roll 			The player's roll.
-- @param link 			The itemLink of the item in the session.
-- @param ilvl			The ilvl of the item in the session.
-- @param equipLoc		The item in the session's equipLoc.
-- @param sendAvgIlvl   Indicates whether we send average ilvl.
function AddOn:SendResponse(target, session, response, roll, link, ilvl, equipLoc, sendAvgIlvl)
    Logging:Trace("SendResponse()")
    local C = AddOn.Constants
    local g1, g2, diff

    if link and ilvl then
        g1, g2 = self:GetGear(link, equipLoc)
        diff = self:GetItemLevelDifference(link, g1, g1)
    end

    self:SendCommand(target, C.Commands.Response,
            session,
            self.playerName,
            {
                gear1 = g1 and ItemUtil:ItemLinkToItemString(g1) or nil,
                gear2 = g2 and ItemUtil:ItemLinkToItemString(g2) or nil,
                ilvl = sendAvgIlvl and self.playersData.ilvl or nil,
                diff = diff,
                note = nil,
                response = response,
                roll = roll
            }
    )
end

-- @param skip the index at which to start for sending acks
function AddOn:SendLootAck(table, skip)
    Logging:Trace("SendLootAck()")
    local C = AddOn.Constants

    local toSend = { gear1 = {}, gear2 = {}, diff = {}, response = {} }
    local hasData = false
    for sess, entry in ipairs(table) do
        local session = entry.session or sess
        if session > (skip or 0) then
            hasData = true
            local g1, g2 = self:GetGear(entry.link, entry.equipLoc)
            local diff = self:GetItemLevelDifference(entry.link, g1, g2)
            toSend.gear1[session] = ItemUtil:ItemLinkToItemString(g1)
            toSend.gear2[session] = ItemUtil:ItemLinkToItemString(g2)
            toSend.diff[session] = diff
            toSend.response[session] = entry.autoPass
        end
    end

    if hasData then
        self:SendCommand(C.group, C.Commands.LootAck, self.playerName, self.playersData.ilvl, toSend)
    end
end


function AddOn:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)

    local C = AddOn.Constants

    if prefix == C.name then
        local success, command, data = self:Deserialize(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, data=%s", tostring(success), command, Util.Objects.ToString(data))

        if success then
            if command == C.Commands.LootTable then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self.lootTable = unpack(data)
                    if not self.enabled then
                        for i = 1, #self.lootTable do
                            self:SendResponse(C.group, i, C.Responses.Disabled)
                        end
                        Logging:Trace("Sent Disabled response to %s", sender)
                    end

                    -- determine how many uncached items there are
                    local uncached = Util.Tables.CountFn(
                            self.lootTable,
                            function(v) return not GetItemInfo(v.link) end
                    )
                    -- if any are uncached, reschedule execution
                    if uncached > 0 then
                        return self:ScheduleTimer("OnCommReceived", 0, prefix, serializedMsg, dist, sender)
                    end

                    -- Unpacking doesn't bring back class meta-data, need to reconstitute the entries
                    Util.Tables.Map(self.lootTable, function (entry) return Models.ItemEntry:Reconstitute(entry) end)
                    self:PrepareLootTable(self.lootTable)

                    -- Received LootTable without having received MasterLooterDb, well...
                    if not self.mlDb then
                        self:Warn("Received LootTable without having MasterLooterDb from %s", sender)
                        self:SendCommand(self.masterLooter, C.Commands.MasterLooterDbRequest)
                        return self:ScheduleTimer("OnCommReceived", 5, prefix, serializedMsg, dist, sender)
                    end

                    if self.isMasterLooter then
                        AddOn:CallModule("LootAllocate")
                        AddOn:GetModule("LootAllocate"):ReceiveLootTable(self.lootTable)
                    end

                    -- for anyone that is currently part of group, but outside of instances
                    -- automatically respond to each item
                    if GetNumGroupMembers() >= 10 and not IsInInstance() then
                       self:Debug("Raid member, but not in the instance. Responding to each item to that affect.")
                        Util.Tables.Iter(self.lootTable,
                                function(entry, session)
                                    self:SendResponse(C.group, session, C.Responses.NotInRaid,
                                            nil, entry.link, entry.ilvl, entry.equipLoc, true
                                    )
                                end
                        )
                    end

                    self:DoAutoPass(self.lootTable)
                    self:SendLootAck(self.lootTable)

                    AddOn:CallModule("Loot")
                    AddOn:GetModule("Loot"):Start(self.lootTable)
                else
                    self:Warn("Received LootTable from %s, but they are not MasterLooter", sender)
                end
            elseif command == C.Commands.LootTableAdd and self:UnitIsUnit(sender, self.masterLooter) then
                local len = #self.lootTable
                for index, entry in pairs(unpack(data)) do
                    self.lootTable[index] = Models.ItemEntry:Reconstitute(entry)
                end
                self:PrepareLootTable(self.lootTable)
                self:DoAutoPass(self.lootTable)
                self:SendLootAck(self.lootTable, len)
                for index, entry in ipairs(self.lootTable) do
                    if index > len then
                        AddOn:GetModule("Loot"):AddSingleItem(entry)
                    end
                end
            elseif command == C.Commands.Candidates then
                self.candidates = unpack(data)
            elseif command == C.Commands.MasterLooterDb and not self.isMasterLooter then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self:OnMasterLooterDbReceived(unpack(data))
                else
                    Logging:Warn("Non-MasterLooter %s sent DB", sender)
                end
            elseif command == C.Commands.PlayerInfoRequest then
                self:SendCommand(sender, C.Commands.PlayerInfo, self:GetPlayerInfo())
            elseif command == C.Commands.LootSessionEnd and self.enabled then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self:Print(format(L["player_ended_session"], self.Ambiguate(self.masterLooter)))
                    self:GetModule("Loot"):Disable()
                    self.lootTable = {}
                else
                    Logging:Warn("Non-MasterLooter %s sent end of session command", sender)
                end
            elseif command == C.Commands.LootAck and not self:UnitIsUnit(sender, "player") and self.enabled then
                if not self.lootTable or #self.lootTable == 0 then
                    Logging:Warn("Received a LootAck without having a loot table")
                    if not self.masterLooter then
                        Logging:Warn("There is currently no assigned Master Looter")
                    end
                    if not self.reconnectPending then
                        self:SendCommand(self.masterLooter, C.Commands.Reconnect)
                        self.reconnectPending = true
                        self:ScheduleTimer("ResetReconnectRequest", 5)
                    end
                end
            end
        end
    end
end