local _, AddOn = ...

local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local ItemUtil  = AddOn.Libs.ItemUtil
local L         = AddOn.components.Locale

-- keep track of whether we need to re-request data due to a reload
local relogged = true

function AddOn:CallModule(module)
    self:EnableModule(module)
end

function AddOn:MasterLooterModule()
    return self:GetModule("MasterLooter")
end

function AddOn:GetMasterLooter()
    Logging:Trace("GetMasterLooter()")
    local MasterLooterDbCheck = AddOn.Constants.Commands.MasterLooterDbCheck

    -- always the player when testing alone
    if GetNumGroupMembers() == 0 and self.testMode then
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
    return false, nil;
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

    -- Someone else has become ML
    if not self.isMasterLooter and self.masterLooter then
        return
    end

    -- todo : prompt for using master looter (as needed)
    if self.isMasterLooter then
        self:StartHandleLoot()
    elseif self.isMasterLooter and false then -- as if using master looter
       --  LibDialog:Spawn("R2D2_CONFIRM_USAGE")
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


-- Fetches a response of a given type, based on the group leader's settings if possible
-- @param type The type of response. Defaults to "default".
-- @param name The name of the response.
-- @see MasterLooter.db.responses
-- @return A table from db.responses containing the response info
function AddOn:GetResponse(type, name)
    Logging:Trace('GetResponse(%s, %s)', type, name)
    Logging:Trace('GetResponse() - mlDb = %s', Util.Objects.ToString(self.mlDb, 5))

    type = type and type or "default"
    -- this is the MasterLooter profile db, for use in fallback cases
    -- it's not guaranteed to be consistent with the master looter in situations where
    -- master looter's db has not been received
    local ML = self:MasterLooterModule()

    -- todo : button slots?

    if  Util.Objects.Equals(type, "default") or not self:GetMasterLooterDbValue('responses', type) then
        if self:GetMasterLooterDbValue('responses.default') then
            return self:GetMasterLooterDbValue('responses.default')[name]
        elseif ML:GetDbValue('responses.default') then
            return ML:GetDbValue('responses.default')[name]
        else
            Logging:Warn("No default responses entry for response %s", tostring(name))
            return ML:GetDefaultDbValue('profile.responses.default.DEFAULT')
        end
    -- must be supplied by master looter's db
    else
        if next(self.mlDb) then
            local response = self:GetMasterLooterDbValue('responses', type)
            if response and response[name] then
                return response[name]
            else
                if self:GetMasterLooterDbValue('responses.default') then
                    return self:GetMasterLooterDbValue('responses.default')[name]
                elseif ML:GetDbValue('responses.default') then
                    return ML:GetDbValue('responses.default')[name]
                else
                    self:Warn("Unknown response - type %s / name %s", tostring(type), tostring(name))
                    return ML:GetDbValue('responses.default.DEFAULT')
                end
            end
        else
            Logging:Warn("No MasterLooterDb - type %s / name %s", tostring(type), tostring(name))
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
                -- Logging:Trace("PrepareLootTable() : %s - %s", tostring(session), Util.Objects.ToString(entry))
                -- Logging:Trace("PrepareLootTable() : Entry getmetatable => %s", Util.Objects.ToString(getmetatable(entry)))
                entry:Validate(session)
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

function AddOn:DoAutoPass(table, skip)
    for sess, entry in ipairs(table) do
        local session = entry.session or sess
        Logging:Trace("DoAutoPass(%s) : %s", session, Util.Objects.ToString(entry))
        if session > (skip or 0) then
            -- todo : add configuration setting for auto pass to parameterize this
            if not entry.boe then
                if not ItemUtil:ClassCanUse(self.playerClass, entry.classes, entry.equipLoc, entry.typeId, entry.subTypeId) then
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

function AddOn:ResetReconnectRequest()
    Logging:Debug("ResetReconnectRequest")
    self.reconnectPending = false
end

function AddOn:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)
    local C = AddOn.Constants.Commands
    local E = AddOn.Constants.Events
    if event == E.PlayerEnteringWorld then
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
    end
end

function AddOn:LootOpened(...)

end

function AddOn:LootClosed()

end

function AddOn:EnterCombat()

end

function AddOn:LeaveCombat()

end