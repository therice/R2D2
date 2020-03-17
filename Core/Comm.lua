local _, AddOn = ...
local Logging   = AddOn.components.Logging
local Strings   = AddOn.Libs.Util.Strings
local Objects   = AddOn.Libs.Util.Objects
local L         = AddOn.components.Locale

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

function AddOn:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Debug("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)

    local C = AddOn.Constants

    if prefix == C.name then
        local test, command, data = self:Deserialize(serializedMsg)

        Logging:Debug("OnCommReceived() : test=%s, command=%s", tostring(test), command)

        if test then
            if command == C.Commands.MasterLooterDb and not self.isMasterLooter then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self:OnMasterLooterDbReceived(unpack(data))
                else
                    Logging:Warn("Non-MasterLooter %s sent DB", sender)
                end
            elseif command == C.Commands.Candidates then
                self.candidates = unpack(data)
            elseif command == C.Commands.PlayerInfoRequest then
                self:SendCommand(sender, C.Commands.PlayerInfo, self:GetPlayerInfo())
            elseif command == C.Commands.LootTable then

            elseif command == C.Commands.LootTableAdd and self:UnitIsUnit(sender, self.masterLooter) then

            end
        end
    end
end

-- Send the msg to the channel if it is valid. Otherwise just print the message.
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

function AddOn:MessageId(...)
    return Strings.join('_', AddOn.Constants.name, ...)
end