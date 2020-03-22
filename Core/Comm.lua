local _, AddOn = ...
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Objects   = Util.Objects
local L         = AddOn.components.Locale
local Models    = AddOn.components.Models

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

    -- todo : add gear levels (as needed)

    self:SendCommand(target, C.Commands.Response, session, self.playerName,
            {
                gear1 = nil,
                gear2 = nil,
                ilvl = nil,
                diff = 0,
                note = nil,
                response = response,
                roll = roll
            }
    )
end


function AddOn:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Debug("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)

    local C = AddOn.Constants

    if prefix == C.name then
        local success, command, data = self:Deserialize(serializedMsg)

        Logging:Debug("OnCommReceived() : test=%s, command=%s", tostring(success), command)

        if success then
            if command == C.Commands.LootTable then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self.lootTable = unpack(data)
                    if not self.enabled then
                        for i = 1, #self.lootTable do
                            self:SendResponse(C.group, i, C.Responses.Disabled)
                        end
                        Logging:Debug("Sent Disabled response to %s", sender)
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

                    -- for anyone that is currently part of group, but outside of instances
                    -- automatically respond to each item
                    if GetNumGroupMembers() >= 10 and not IsInInstance() then
                       self:Debug("Raid member, but not in the instance. Responding to each item to that affect.")
                        Util.Tables.Iter(self.lootTable,
                                function(entry, session)
                                    self:SendResponse(C.group, session, C.Responses.NotInRaid,
                                            nil, entry.link, entry.ilvl, true
                                    )
                                end
                        )
                    end

                    self:DoAutoPass(self.lootTable)
                    self:SendLootAck(self.lootTable)

                    AddOn:CallModule("Loot")
                    AddOn:GetModule("Loot"):Start(self.lootTable)
                else
                    self:Warn("Recevied LootTable from %s, but they are not MasterLooter", sender)
                end
            elseif command == C.Commands.LootTableAdd and self:UnitIsUnit(sender, self.masterLooter) then

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
                    Logging:Warn("Non-MasterLooter %s send end of session command", sender)
                end
            end
        end
    end
end