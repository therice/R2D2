local _, AddOn = ...
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Objects   = Util.Objects
local L         = AddOn.components.Locale
local Models    = AddOn.components.Models
local ItemUtil  = AddOn.Libs.ItemUtil
local Compression = AddOn.Libs.Util.Compression


function AddOn:GetAnnounceChannel(channel)
    local C = AddOn.Constants
    return channel == C.group and (IsInRaid() and C.Channels.Raid or C.Channels.Party) or channel
end


function AddOn:SendAnnouncement(msg, channel)
    Logging:Trace("SendAnnouncement(%s) : %s", channel, msg)

    local C = AddOn.Constants
    if channel == C.Channels.None then return end
    if self:TestModeEnabled() then
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

--- scrubs passed value for transmission over the wire
-- specifically, entries that are modeled as classes via LibClass
-- need to have their functions removed as not serializable
-- when they are received, they will be reconstituted into the appropriate class
local function ScrubValue(value)
    local vt = type(value)

    if vt == 'table' and not value.clazz then
        local t = {}
        for k, v in pairs(value) do
            local k1 = ScrubValue(k)
            local v1 = ScrubValue(v)
            t[k1] = v1
        end
        return t
    elseif vt == 'table' and value.clazz then
        return value:toTable()
    else
        return value
    end
end

--- goes through passed arguments, scrubbing them for transmission over the wire
function AddOn.ScrubData(...)
    local scrubbed = Util.Tables.New()
    for i=1,select("#", ...) do
        local v = select(i, ...)
        Util.Tables.Push(scrubbed, ScrubValue(v))
    end
    return scrubbed
end

-- order is significant for types specified here, as that is the order in which they
-- will be attempted, which the next one being fallback, and so forth...
--
-- eventually, we can eliminate chaining and go back to our method of choice
-- however this needs phased out in multiple releases
local Compressors = Compression.GetCompressors(
        Compression.CompressorType.LibDeflate,
        Compression.CompressorType.LibCompressNoOp
)

function AddOn:PrepareForSend(command, ...)
    local serialized = self:Serialize(command, self.ScrubData(...))
    local data = Compressors[1]:compress(serialized, true)
    Logging:Debug("PrepareForSend() : Compressed length '%d' to '%d'", #serialized, #data)
    return data
end

function AddOn:ProcessReceived(msg)
    if not msg then
        Logging:Error("ProcessReceived() : No message was provided")
        return false
    end
    
    local decompressed
    for _, compressor in pairs(Compressors) do
        Logging:Trace("ProcessReceived() : Attempting decompression using %s", compressor:GetName())
        decompressed = compressor:decompress(msg, true)
        if decompressed then
            Logging:Trace("ProcessReceived() : Decompression SUCCEEDED using %s", compressor:GetName())
            break
        end
        
        Logging:Trace("ProcessReceived() : Decompression FAILED using %s", compressor:GetName())
    end
    
    if not decompressed then
        Logging:Warn("ProcessReceived() : Message could not be decompressed")
        return false
    end

    local success, command, data = self:Deserialize(decompressed)
    if not success then
        Logging:Error("ProcessReceived() : Message could not deserialized, '%s' - %s", tostring(command), Util.Objects.ToString(decompressed))
    end
    
    return success, command, data
end

function AddOn:SendCommand(target, command, ...)
    local C = AddOn.Constants

    -- send all data as a table, and let receiver unpack it
    -- before sending, we scrub to insure it can be serialized
    --
    -- local toSend = self:Serialize(command, self.ScrubData(...))
    local toSend = self:PrepareForSend(command, ...)
    local prefix = C.name
    
    Logging:Debug("SendCommand(%s, %s) : %s",
                  target, command,
                  Logging:IsEnabledFor(Logging.Level.Trace) and Util.Objects.ToString(toSend, 1) or '[omitted]'
    )

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

--- Sends a response.
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
function AddOn:SendResponse(target, session, response, note, roll, link, ilvl, equipLoc, sendAvgIlvl)
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
                 gear1    = g1 and ItemUtil:ItemLinkToItemString(g1) or nil,
                 gear2    = g2 and ItemUtil:ItemLinkToItemString(g2) or nil,
                 ilvl     = sendAvgIlvl and self.playersData.ilvl or nil,
                 diff     = diff,
                 note     = note,
                 response = response,
                 roll     = roll
            }
    )
end

---
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
    Logging:Debug("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)

    local C = AddOn.Constants

    if prefix == C.name then
        local success, command, data = self:ProcessReceived(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, from=%s, dist=%s, data=%s",
                      tostring(success), tostring(command), tostring(sender), tostring(dist),
                      Logging:IsEnabledFor(Logging.Level.Trace) and Util.Objects.ToString(data, 1) or '[omitted]'
        )

        if success then
            if command == C.Commands.LootTable then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self.lootTable = unpack(data)
                    if not self.enabled then
                        for i = 1, #self.lootTable do
                            self:SendResponse(C.group, i, C.Responses.Disabled)
                        end
                        Logging:Trace("Sent Disabled response to %s", sender)
                        return
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
                    Util.Tables.Map(self.lootTable, function (entry) return Models.ItemEntry:new():reconstitute(entry) end)
                    self:PrepareLootTable(self.lootTable)
            
                    -- Received LootTable without having received MasterLooterDb, well...
                    if not self.mlDb then
                        Logging:Warn("Received LootTable without having MasterLooterDb from %s", sender)
                        self:SendCommand(self.masterLooter, C.Commands.MasterLooterDbRequest)
                        return self:ScheduleTimer("OnCommReceived", 5, prefix, serializedMsg, dist, sender)
                    end
            
                    -- we're the master looter, then start allocation
                    if self.isMasterLooter then
                        AddOn:CallModule("LootAllocate")
                        AddOn:GetModule("LootAllocate"):ReceiveLootTable(self.lootTable)
                    end
            
                    -- for anyone that is currently part of group, but outside of instances
                    -- automatically respond to each item (if support is enabled)
                    if self:GetMasterLooterDbValue('outOfRaid') and GetNumGroupMembers() >= 8 and not IsInInstance() then
                        Logging:Debug("Raid member, but not in the instance. Responding to each item to that affect.")
                        Util.Tables.Iter(self.lootTable,
                                         function(entry, session)
                                             self:SendResponse(C.group, session, C.Responses.NotInRaid,
                                                               nil, nil, entry.link, entry.ilvl, entry.equipLoc, true
                                             )
                                         end
                        )
                        return
                    end
            
                    self:DoAutoPass(self.lootTable)
                    self:SendLootAck(self.lootTable)
            
                    AddOn:CallModule("Loot")
                    AddOn:GetModule("Loot"):Start(self.lootTable)
                else
                    self:Warn("Received LootTable from %s, but they are not MasterLooter", sender)
                end
            elseif command == C.Commands.LootTableAdd and self:UnitIsUnit(sender, self.masterLooter) then
                local oldLen = #self.lootTable
                for index, entry in pairs(unpack(data)) do
                    self.lootTable[index] = Models.ItemEntry:new():reconstitute(entry)
                end
                self:PrepareLootTable(self.lootTable)
                self:DoAutoPass(self.lootTable, oldLen)
                self:SendLootAck(self.lootTable, oldLen)
                for index, entry in ipairs(self.lootTable) do
                    if index > oldLen then
                        AddOn:GetModule("Loot"):AddSingleItem(entry)
                    end
                end
            elseif command == C.Commands.Candidates then
                self.candidates = unpack(data)
                Util.Tables.Map(self.candidates, function (entry) return Models.Candidate:new():reconstitute(entry) end)
                Logging:Debug("Received Candidates => %d / %s", Util.Tables.Count(self.candidates), Util.Objects.ToString(self.candidates, 2))
            elseif command == C.Commands.MasterLooterDb and not self.isMasterLooter then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self:OnMasterLooterDbReceived(unpack(data))
                else
                    Logging:Warn("Non-MasterLooter %s sent DB", sender)
                end
            elseif command == C.Commands.VersionCheck and not self:UnitIsUnit(sender, "player") then
                local v, mode = unpack(data)
                Logging:Trace("VersionCheck(%s, %s)", Util.Objects.ToString(v), Util.Objects.ToString(mode))
                
                local VC = self:VersionCheckModule()
                local r, version = Models.SemanticVersion.Create(v)
                if r then
                    VC:TrackVersion(
                            self:UnitName(sender),
                            version,
                            AddOn.Mode():reconstitute(mode)
                    )
                    if dist == "GUILD" then sender = C.guild end
                    self:SendCommand(sender, C.Commands.VersionCheckReply , self.playerName, self.playerClass, self.guildRank, self.version, self.mode)
        
                    if self.versionCheckComplete then return end
        
                    local verCheck = VC.CheckVersion(self.version, version)
                    if verCheck == C.VersionStatus.OutOfDate then
                        self:PrintOutOfDateVersionWarning(version)
                    end
                else
                    Logging:Warn("VersionCheck - Invalid version '%s'", Objects.ToString(v))
                end
            elseif command == C.Commands.VersionCheckReply then
                local name, _, _, v, mode = unpack(data)
                if not name then Logging:Warn("VersionCheckReply without name from %s", sender)  end
                local VC = self:VersionCheckModule()
                
                local r, version = Models.SemanticVersion.Create(v)
                if r then
                    VC:TrackVersion(
                            self:UnitName(sender),
                            version,
                            AddOn.Mode():reconstitute(mode)
                    )
        
                    if self.versionCheckComplete then return end
        
                    local verCheck = VC.CheckVersion(self.version, version)
                    if verCheck == C.VersionStatus.OutOfDate then
                        self:PrintOutOfDateVersionWarning(version)
                    end
                else
                    Logging:Warn("VersionCheckReply - Invalid version '%s'", Objects.ToString(v))
                end
            elseif command == C.Commands.ReRoll then
                AddOn:Print(format(L["player_requested_reroll"], self.Ambiguate(sender)))
                local table = unpack(data)
                Logging:Debug("ReRoll : %s", Util.Objects.ToString(table, 4))
                Util.Tables.Map(table, function (entry) return Models.ItemEntry:new():reconstitute(entry) end)
                self:PrepareLootTable(table)
                self:DoAutoPass(table)
                self:SendLootAck(table)
                AddOn:CallModule("Loot")
                AddOn:GetModule("Loot"):ReRoll(table)
            elseif command == C.Commands.PlayerInfoRequest then
                self:SendCommand(sender, C.Commands.PlayerInfo, self:GetPlayerInfo())
            elseif command == C.Commands.LootSessionEnd and self.enabled then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    self:Print(format(L["player_ended_session"], self.Ambiguate(self.masterLooter)))
                    self:LootModule():Disable()
                    -- not forcing close ATM
                    self:LootAllocateModule():EndSession(false)
                    self.lootTable = {}
                else
                    Logging:Warn("Non-MasterLooter %s sent end of session command", sender)
                end
            elseif command == C.Commands.LootAck and not self:UnitIsUnit(sender, "player") and self.enabled then
                if not self.lootTable or #self.lootTable == 0 then
                    Logging:Warn("Received a LootAck without having a loot table")
                    if Util.Objects.IsEmpty(self.masterLooter) then
                        return Logging:Warn("There is currently no assigned Master Looter")
                    end
                    if not self.reconnectPending then
                        self:SendCommand(self.masterLooter, C.Commands.Reconnect)
                        self.reconnectPending = true
                        self:ScheduleTimer("ResetReconnectRequest", 5)
                    end
                end
            elseif command == C.Commands.StandbyPing then
                if self:UnitIsUnit(sender, self.masterLooter) then
                    local standbyPlayer = unpack(data)
                    self:SendCommand(sender, C.Commands.StandbyPingAck, standbyPlayer)
                else
                    Logging:Warn("Non-MasterLooter %s sent standby ping command", sender)
                end
            elseif command == C.Commands.LootHistoryAdd then
                local winner, table = unpack(data)
                -- Logging:Debug("%s, %s", tostring(winner), Objects.ToString(table))
                local entry = Models.History.Loot():reconstitute(table)
                local _, _, _, _, _, itemTypeId, itemSubTypeId = GetItemInfoInstant(entry.item)
                entry.itemTypeId = itemTypeId
                entry.itemSubTypeId = itemSubTypeId
                local LH = self:LootHistoryModule()
                LH:AddEntry(winner, entry)
                if LH:IsEnabled() then
                   LH:BuildData()
                end
            elseif command == C.Commands.TrafficHistoryAdd then
                local table = unpack(data)
                local entry = Models.History.Traffic():reconstitute(table)
                local TH = self:TrafficHistoryModule()
                TH:AddEntry(entry)
                if TH:IsEnabled() then
                    TH:BuildData()
                end
            elseif command == C.Commands.SyncSYN then
                AddOn:SyncModule():SyncSYNReceived(unpack(data))
            elseif command == C.Commands.SyncACK then
                AddOn:SyncModule():SyncACKReceived(unpack(data))
            elseif command == C.Commands.SyncNACK then
                AddOn:SyncModule():SyncNACKReceived(unpack(data))
            elseif command == C.Commands.Sync then
                AddOn:SyncModule():SyncDataReceived(unpack(data))
            end
        end
    end
end