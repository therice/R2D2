local _, AddOn = ...

local Logging      = AddOn.components.Logging
local Util         = AddOn.Libs.Util
local ItemUtil     = AddOn.Libs.ItemUtil
local L            = AddOn.components.Locale
local Dialog       = AddOn.Libs.Dialog

-- keep track of whether we need to re-request data due to a reload
local relogged = true

function AddOn:CallModule(module)
    self:EnableModule(module)
end

function AddOn:MasterLooterModule()
    return self:GetModule("MasterLooter")
end

function AddOn:GearPointsModule()
    return self:GetModule("GearPoints")
end

function AddOn:PointsModule()
    return self:GetModule("Points")
end

function AddOn:LootAllocateModule()
    return self:GetModule("LootAllocate")
end

function AddOn:LootHistoryModule()
    return self:GetModule("LootHistory")
end

function AddOn:GetMasterLooter()
    Logging:Trace("GetMasterLooter()")
    local MasterLooterDbCheck = AddOn.Constants.Commands.MasterLooterDbCheck

    -- always the player when testing alone
    if GetNumGroupMembers() == 0 and (self:TestModeEnabled() or self:DevModeEnabled()) then
        self:ScheduleTimer("Timer", 5, MasterLooterDbCheck)
        return true, self.playerName
    end

    local lootMethod, mlPartyId, mlRaidId = GetLootMethod()
    if lootMethod == "master" then
        local name
        -- Someone in raid
        if mlRaidId then
            name = self:UnitName("raid" .. mlRaidId)
        -- Player in party
        elseif mlPartyId == 0 then
            name = self.playerName
        -- Someone in party
        elseif mlPartyId then
            name = self:UnitName("party" .. mlPartyId)
        end

        -- Check to see if we have received mldb within 15 secs, otherwise request it
        self:ScheduleTimer("Timer", 15, MasterLooterDbCheck)
        return IsMasterLooter(), name
    end
    return false, nil
end

function AddOn:NewMasterLooterCheck()
    Logging:Debug("NewMasterLooterCheck()")
    
    local oldMl = self.masterLooter
    self.isMasterLooter, self.masterLooter = self:GetMasterLooter()
    if Util.Strings.IsSet(self.masterLooter) and strfind(self.masterLooter, "Unknown") then
        Logging:Warn("NewMasterLooterCheck() : Unknown Master Looter")
        self:ScheduleTimer("NewMasterLooterCheck", 2)
        return
    end
    
    -- We were ML, but no longer, so disable master looter module
    if self:UnitIsUnit(oldMl, "player") and not self.isMasterLooter then
        self:MasterLooterModule():Disable()
    end
    
    if self:UnitIsUnit(oldMl, self.masterLooter) then
        Logging:Debug("NewMasterLooterCheck() : No Master Looter change")
        return
    end
    
    if self.db.profile.usage.never then return end
    if self.masterLooter == nil then return end
    
    -- Someone else has become ML
    if not self.isMasterLooter and self.masterLooter then
        return
    end
    
    if not IsInRaid() and self.db.profile.onlyUseInRaids then return end
    
    -- we are ml and shouldn't as for usage
    if self.isMasterLooter and self.db.profile.usage.ml then
        self:StartHandleLoot()
    -- ask if using master looter
    elseif self.isMasterLooter and self.db.profile.usage.ask_ml then
        return Dialog:Spawn(AddOn.Constants.Popups.ConfirmUsage)
    end
end


function AddOn:OnRaidEnter()
    if not IsInRaid() and self.db.profile.onlyUseInRaids then return end
    if not self.masterLooter and UnitIsGroupLeader("player") then
        if self.db.profile.usage.leader then
            self.isMasterLooter, self.masterLooter = true, self.playerName
            self:StartHandleLoot()
        elseif self.db.profile.usage.ask_leader then
            return Dialog:Spawn(AddOn.Constants.Popups.ConfirmUsage)
        end
    end
end


function AddOn:StartHandleLoot()
    Logging:Debug("StartHandleLoot()")
    local C = AddOn.Constants
    local lootMethod = GetLootMethod()
    if lootMethod ~= "master" and GetNumGroupMembers() > 0 then
        self:Print(L["changing_loot_method_to_ml"])
        SetLootMethod("master", self.Ambiguate(self.playerName))
    end
    -- todo : probably want this to be a configuration param, not just 'epic
    SetLootThreshold(4)
    self:Print(format(L["player_handles_looting"], self.playerName))
    self.handleLoot = true
    self:SendCommand(C.group, C.Commands.HandleLootStart)
    self:CallModule("MasterLooter")
    self:MasterLooterModule():NewMasterLooter(self.masterLooter)
end

function AddOn:StopHandleLoot()
    Logging:Debug("StopHandleLoot()")
    local C = AddOn.Constants
    self.handleLoot = false
    self:MasterLooterModule():Disable()
    self:SendCommand(C.group, C.Commands.HandleLootStop)
end

function AddOn:GetMasterLooterDbValue(...)
    local path = Util.Strings.Join('.', ...)
    return Util.Tables.Get(self.mlDb, path)
end

function AddOn:OnMasterLooterDbReceived(mlDb)
    Logging:Debug("OnMasterLooterDbReceived()")
    local ML = self:MasterLooterModule()

    self.mlDb = mlDb
    for type, _ in pairs(mlDb.responses) do
        if not ML:GetDefaultDbValue('profile.responses', type) then
            setmetatable(self.mlDb.responses[type], {__index = ML:GetDefaultDbValue('profile.responses.default')})
        end
    end

    if not self.mlDb.responses.default then self.mlDb.responses.default = {} end
    setmetatable(self.mlDb.responses.default, {__index = ML:GetDefaultDbValue('profile.responses.default')})

    if not self.mlDb.buttons.default then self.mlDb.buttons.default = {} end
    setmetatable(self.mlDb.buttons.default, { __index = ML:GetDefaultDbValue('profile.buttons.default')})
end

function AddOn:GetLootSlotInfo(slot)
    return self.lootSlotInfo[slot]
end

-- Fetches a response of a given type, based on the group leader's settings if possible
-- @param type The type of response. Defaults to "default".
-- @param name The name of the response.
-- @see MasterLooter.db.responses
-- @return A table from db.responses containing the response info
function AddOn:GetResponse(type, name)
    Logging:Trace('GetResponse(%s, %s)', tostring(type or 'nil'), tostring(name or 'nil'))
    --Logging:Trace('GetResponse() - mlDb = %s', Util.Objects.ToString(self.mlDb, 5))

    type = type and type or "default"
    
    -- this is the MasterLooter profile db, for use in fallback cases
    -- it's not guaranteed to be consistent with the master looter in situations where
    -- master looter's db has not been received
    local ML = self:MasterLooterModule()

    local function MasterLooterDbValue(path, attr)
        local mlDbValue = self:GetMasterLooterDbValue(path)
        return Util.Tables.ContainsKey(mlDbValue, attr) and mlDbValue[attr] or nil
    end
    
    local function DbValue(path, attr)
        local dbValue = ML:GetDbValue(path)
        return Util.Tables.ContainsKey(dbValue, attr) and dbValue[attr] or nil
    end
    
    local ResponseValue = Util.Functions.Dispatch(MasterLooterDbValue, DbValue)
    
    -- todo : sort out checks for name
    if Util.Objects.Equals(type, "default") or not self:GetMasterLooterDbValue('responses', type) then
        local response = ResponseValue('responses.default', name)
        if response then
            return response
        else
            Logging:Warn("No default responses entry for response '%s'", tostring(name))
            return ML:GetDefaultDbValue('profile.responses.default.DEFAULT')
        end
    -- must be supplied by master looter's db
    else
        if next(self.mlDb) then
            local mlDbResponse = self:GetMasterLooterDbValue('responses', type)
            if mlDbResponse and not Util.Objects.IsEmpty(mlDbResponse[name]) then
                return mlDbResponse[name]
            else
                local response = ResponseValue('responses.default', name)
                if response then
                    return response
                else
                    Logging:Warn("Unknown response - type '%s' / name '%s'", tostring(type), tostring(name))
                    return ML:GetDefaultDbValue('profile.responses.default.DEFAULT')
                end
            end
        else
            Logging:Warn("No MasterLooterDb - type '%s' / name '%s'", tostring(type), tostring(name))
        end
    end

    return {}
end

function AddOn:GetResponseColor(type, name)
    return unpack(self:GetResponse(type, name).color)
end

function AddOn:GetNumButtons(type)
    type = type and type or "default"
    local ML = self:MasterLooterModule()

    -- if no master looter db, just use the defaults
    if not next(self.mlDb) then
        local buttons = ML:GetDbValue('buttons', type)
        return buttons and buttons.numButtons or 0
    end
    -- todo : button slots?
    if Util.Objects.Equals(type, "default") or not self:GetMasterLooterDbValue('buttons', type) then
        return self:GetMasterLooterDbValue('buttons.default') and
                self:GetMasterLooterDbValue('buttons.default.numButtons') or
                ML:GetDbValue('buttons.default.numButtons') or 0
    else
        if self:GetMasterLooterDbValue('buttons', type) then
            return #self.mlDb.buttons[type]
        else
            Logging:Warn("No MasterLooterDb Buttons entry for %s", tostring(type))
        end
    end
end

function AddOn:GetButtons(type)
    type = type and type or "default"
    return self:GetMasterLooterDbValue('buttons', type) or self:GetMasterLooterDbValue('buttons.default')
end

-- does stuff, yeah... stuff
function AddOn:PrepareLootTable(lootTable)
    Util.Tables.Call(lootTable,
            function(entry, session)
                -- Logging:Trace("PrepareLootTable(PRE) : %s - %s", tostring(session), Util.Objects.ToString(entry))
                entry:Validate(session)
                -- Logging:Trace("PrepareLootTable(POST) : %s - %s", tostring(session), Util.Objects.ToString(entry))
            end,
            true -- index required (it's the session id)
    )
end


function AddOn:Timer(type, ...)
    Logging:Trace("Timer(%s)", type)
    local C = AddOn.Constants

    if type == C.Commands.MasterLooterDbCheck then
        if self.masterLooter then
            if not self.mlDb.buttons then
                self:SendCommand(self.masterLooter, C.Commands.MasterLooterDbRequest)
            end
        end
    end
end

-- @return boolean indicating if should auto-pass (cannot use)
function AddOn:AutoPassCheck(class, equipLoc, typeId, subTypeId, classes)
    -- Logging:Debug("AutoPassCheck(%s) : %s, %s, %s, %s", class, equipLoc, tostring(typeId), tostring(subTypeId), tostring(classes))
    return not ItemUtil:ClassCanUse(class, classes, equipLoc, typeId, subTypeId)
end

function AddOn:DoAutoPass(table, skip)
    for sess, entry in ipairs(table) do
        local session = entry.session or sess
        -- Logging:Trace("DoAutoPass(%s) : %s", session, Util.Objects.ToString(entry))
        if session > (skip or 0) then
            -- todo : add configuration setting for auto pass to parameterize this
            -- still obey no auto-pass if sent in through entry
            if not entry.noAutopass then
                if not entry.boe then
                    if self:AutoPassCheck(self.playerClass, entry.equipLoc, entry.typeId, entry.subTypeId, entry.classes) then
                        Logging:Trace("Auto-passing on %s", entry.link)
                        self:Print(format(L["auto_passed_on_item"], entry.link))
                        entry.autoPass = true
                    end
                else
                    Logging:Trace("Skipped auto-pass on %s as it's BOE", entry.link)
                end
            end
        end
    end
end

function AddOn:ResetReconnectRequest()
    Logging:Debug("ResetReconnectRequest")
    self.reconnectPending = false
end

--@return tuple of (boolean, table) with 1st index being whether moreInfo is shown and 2nd being instance of LootStatistics
function AddOn:MoreInfoSettings(module)
    local moduleSettings = AddOn.db.profile.modules[module]
    return moduleSettings and moduleSettings.moreInfo or false, self:LootHistoryModule():GetStatistics()
end


function AddOn:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)
    local C = AddOn.Constants.Commands
    local E = AddOn.Constants.Events
    if Util.Objects.In(event, E.PartyLootMethodChanged, E.PartyLeaderChanged, E.GroupLeft) then
        self:NewMasterLooterCheck()
    -- we may want to eliminate this entirely and rely upon hook into LibGuildStorage
    elseif event == E.GuildRosterUpdate then
        self.guildRank = self:GetPlayersGuildRank()
        if not self.pendingGuildEvent then
            self:UnregisterEvent(E.GuildRosterUpdate)
        end
    elseif event == E.RaidInstanceWelcome then
        self:ScheduleTimer("OnRaidEnter", 2)
    elseif event == E.PlayerEnteringWorld then
        self:NewMasterLooterCheck()
        self:ScheduleTimer(
                function()
                    local name, _, _, difficulty = GetInstanceInfo()
                    self.instanceName = name .. (Util.Strings.IsEmpty(difficulty) and "" or "-" .. difficulty)
                end,
                5
        )
        if relogged then
            if not self.isMasterLooter and Util.Strings.IsSet(self.masterLooter) then
                Logging:Debug("Player re-logged")
                self:ScheduleTimer("SendCommand", 2, self.masterLooter, C.Reconnect)
                self:SendCommand(self.masterLooter, C.PlayerInfo, self:GetPlayerInfo())
            end
        end
        self:UpdatePlayersData()
        relogged = false
    elseif event == E.EncounterStart then

    elseif event == E.EncounterEnd then
    
    elseif event == E.GuildRosterUpdate then

    elseif event == E.LootSlotCleared then

    elseif event == E.LootReady then
    
    else
        Logging:Debug("OnEvent(%s) : Unhandled event", event)
    end
end

function AddOn:LootOpened(...)
    self.lootOpen = true
end

function AddOn:LootClosed()
    self.lootOpen = false
end

function AddOn:EnterCombat()

end

function AddOn:LeaveCombat()
end