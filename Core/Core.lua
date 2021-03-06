local _, AddOn = ...

local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local L = AddOn.components.Locale
local Dialog = AddOn.Libs.Dialog
local UI = AddOn.components.UI
local Models = AddOn.components.Models

-- track whether initial login rather than reload or zone change
local handledEnteringWorld = false

function AddOn:CallModule(module)
    Logging:Debug("CallModule(%s)", module)
    if not self.enabled then return end
    self:EnableModule(module)
end

function AddOn:IsModuleEnabled(module)
    Logging:Debug("IsModuleEnabled(%s)", module)
    local m = self:GetModule(module)
    return m and m:IsEnabled()
end

function AddOn:YieldModule(module)
    Logging:Debug("YieldModule(%s)", module)
    self:DisableModule(module)
end

function AddOn:ToggleModule(module)
    Logging:Debug("ToggleModule(%s)", module)
    if self:IsModuleEnabled(module) then
        self:YieldModule(module)
    else
        self:CallModule(module)
    end
end

function AddOn:MasterLooterModule()
    return self:GetModule("MasterLooter")
end

function AddOn:GearPointsModule()
    return self:GetModule("GearPoints")
end

function AddOn:GearPointsCustomModule()
    return self:GetModule("GearPointsCustom")
end

function AddOn:EffortPointsModule()
    return self:GetModule("EffortPoints")
end

function AddOn:PointsModule()
    return self:GetModule("Points")
end

function AddOn:LootModule()
    return self:GetModule("Loot")
end

function AddOn:LootSessionModule()
    return self:GetModule("LootSession")
end

function AddOn:VersionCheckModule()
    return self:GetModule("VersionCheck")
end

function AddOn:LootAllocateModule()
    return self:GetModule("LootAllocate")
end

function AddOn:StandbyModule()
    return self:GetModule("Standby")
end

function AddOn:LootHistoryModule()
    return self:GetModule("LootHistory")
end

function AddOn:TrafficHistoryModule()
    return self:GetModule("TrafficHistory")
end

function AddOn:SyncModule()
    return self:GetModule("Sync")
end

function AddOn:ModuleSettings(name)
    return AddOn.db.profile.modules[name]
end

function AddOn:GetMasterLooter()
    Logging:Debug("GetMasterLooter()")
    local lootMethod, mlPartyId, mlRaidId = GetLootMethod()
    self.lootMethod = lootMethod
    Logging:Debug("GetMasterLooter() : Loot Method is '%s'", self.lootMethod)
    
    -- always the player when testing alone
    if GetNumGroupMembers() == 0 and (self:TestModeEnabled() or self:DevModeEnabled()) then
        self:ScheduleTimer("Timer", 5, AddOn.Constants.Commands.MasterLooterDbCheck)
        return true, self.playerName
    end

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
    
        Logging:Debug("GetMasterLooter() : ML is '%s'", tostring(name))
        return IsMasterLooter(), name
    end
    
    Logging:Warn("GetMasterLooter() : Unsupported loot method '%s'", tostring(self.lootMethod))
    return false, nil
end

function AddOn:NewMasterLooterCheck()
    Logging:Debug("NewMasterLooterCheck()")
    
    local oldMl = self.masterLooter
    local oldLm = self.lootMethod
    
    self.isMasterLooter, self.masterLooter = self:GetMasterLooter()
    self.lootMethod = GetLootMethod()
    
    if Util.Strings.IsSet(self.masterLooter) and (Util.Strings.Equal(self.masterLooter, "Unknown") or Util.Strings.Equal(Ambiguate(self.masterLooter, "short"):lower(), _G.UNKNOWNOBJECT:lower())) then
        Logging:Warn("NewMasterLooterCheck() : Unknown Master Looter")
        return self:ScheduleTimer("NewMasterLooterCheck", 1)
    end
    
    -- We were ML, but no longer, so disable master looter module
    if self:UnitIsUnit(oldMl, "player") and not self.isMasterLooter then
        self:StopHandleLoot()
    end
    
    if self:UnitIsUnit(oldMl, self.masterLooter) and Util.Strings.Equal(oldLm, self.lootMethod) then
        Logging:Debug("NewMasterLooterCheck() : No Master Looter change")
        return
    end
    
    -- if self.db.profile.usage.never then return end
    if self:MasterLooterModule():DbValue('usage.never') then return end
    
    if Util.Objects.IsEmpty(self.masterLooter) then return end
    
    -- request ML DB if not received within 15 seconds
    self:ScheduleTimer("Timer", 15,  AddOn.Constants.Commands.MasterLooterDbCheck)
    
    -- Someone else has become ML
    if not self.isMasterLooter and Util.Strings.IsSet(self.masterLooter) then return end
    
    -- if not IsInRaid() and self.db.profile.onlyUseInRaids then return end
    if not IsInRaid() and self:MasterLooterModule():DbValue('onlyUseInRaids') then return end
    
    -- already handling loot, just bail
    if self.handleLoot then return end
    
    local _, type = IsInInstance()
    if type == "arena" or type == "pvp" then return end
    
    Logging:Debug("NewMasterLooterCheck() : isMasterLooter=%s", tostring(self.isMasterLooter))
    
    -- we are ml and shouldn't as for usage
    --  self.db.profile.usage.ml
    if self.isMasterLooter and self:MasterLooterModule():DbValue('usage.ml') then
        self:StartHandleLoot()
    -- ask if using master looter
    -- self.db.profile.usage.ask_ml
    elseif self.isMasterLooter and self:MasterLooterModule():DbValue('usage.ask_ml') then
        return Dialog:Spawn(AddOn.Constants.Popups.ConfirmUsage)
    end
end


function AddOn:OnRaidEnter()
    Logging:Debug("OnRaidEnter()")
    --if not IsInRaid() and self.db.profile.onlyUseInRaids then return end
    if not IsInRaid() and self:MasterLooterModule():DbValue('onlyUseInRaids') then return end
    if Util.Objects.IsEmpty(self.masterLooter) and UnitIsGroupLeader("player") then
        -- self.db.profile.usage.leader
        if self:MasterLooterModule():DbValue('usage.leader') then
            self.isMasterLooter, self.masterLooter = true, self.playerName
            self:StartHandleLoot()
        -- self.db.profile.usage.ask_leader
        elseif self:MasterLooterModule():DbValue('usage.ask_leader') then
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
    
    -- change loot threshold as needed for auto awards
    local ML = self:MasterLooterModule()
    local lootThreshold = GetLootThreshold()
    local autoAwardLowerThreshold = ML.db.profile.autoAwardLowerThreshold
    if ML.db.profile.autoAward and lootThreshold ~= 2 and lootThreshold > autoAwardLowerThreshold then
        self:Print(L["changing_loot_threshold_auto_awards"])
        SetLootThreshold(autoAwardLowerThreshold >= 2 and autoAwardLowerThreshold or 2)
    end
    
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
    Logging:Debug("OnMasterLooterDbReceived() : %s", Util.Objects.ToString(mlDb, 4))
    local ML = self:MasterLooterModule()

    self.mlDb = mlDb
    for type, _ in pairs(mlDb.responses) do
        if not ML:DefaultDbValue('profile.responses', type) then
            setmetatable(self.mlDb.responses[type], {__index = ML:DefaultDbValue('profile.responses.default')})
        end
    end

    if not self.mlDb.responses.default then self.mlDb.responses.default = {} end
    setmetatable(self.mlDb.responses.default, {__index = ML:DefaultDbValue('profile.responses.default')})

    if not self.mlDb.buttons.default then self.mlDb.buttons.default = {} end
    setmetatable(self.mlDb.buttons.default, { __index = ML:DefaultDbValue('profile.buttons.default')})
    
    if not self.mlDb.raids then self.mlDb.raids = {} end
    -- could add metatable for getting from EP module here, but not adding now
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
        return mlDbValue and Util.Tables.ContainsKey(mlDbValue, attr) and mlDbValue[attr] or nil
    end
    
    local function DbValue(path, attr)
        local dbValue = ML:DbValue(path)
        return dbValue and Util.Tables.ContainsKey(dbValue, attr) and dbValue[attr] or nil
    end
    
    local ResponseValue = Util.Functions.Dispatch(MasterLooterDbValue, DbValue)
    
    -- todo : sort out checks for name
    if Util.Objects.Equals(type, "default") or not self:GetMasterLooterDbValue('responses', type) then
        local response = ResponseValue('responses.default', name)
        if response then
            return response
        else
            Logging:Warn("No default responses entry for response '%s'", tostring(name))
            return ML:DefaultDbValue('profile.responses.default.DEFAULT')
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
                    return ML:DefaultDbValue('profile.responses.default.DEFAULT')
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
        local buttons = ML:DbValue('buttons', type)
        return buttons and buttons.numButtons or 0
    end
    -- todo : button slots?
    if Util.Objects.Equals(type, "default") or not self:GetMasterLooterDbValue('buttons', type) then
        return self:GetMasterLooterDbValue('buttons.default') and
                self:GetMasterLooterDbValue('buttons.default.numButtons') or
                ML:DbValue('buttons.default.numButtons') or 0
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
        if Util.Strings.IsSet(self.masterLooter) then
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
    self.reconnectPending = false
    Logging:Debug("ResetReconnectRequest")
end

function AddOn:MoreInfoEnabled(module)
    local moduleSettings = AddOn.db.profile.modules[module]
    return moduleSettings and moduleSettings.moreInfo or false
end

--@return tuple of (boolean, table) with 1st index being whether moreInfo is shown and 2nd being instance of LootStatistics
function AddOn:MoreInfoSettings(module)
    return AddOn:MoreInfoEnabled(module), self:LootHistoryModule():GetStatistics()
end

function AddOn:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)
    local C = AddOn.Constants.Commands
    local E = AddOn.Constants.Events
    if Util.Objects.In(event, E.PartyLootMethodChanged, E.PartyLeaderChanged, E.GroupLeft) then
        if event == E.GroupLeft then self:StandbyModule():ResetRoster() end
        self:NewMasterLooterCheck()
    elseif event == E.RaidInstanceWelcome then
        self:ScheduleTimer("OnRaidEnter", 2)
    -- this event is triggered when the player logs in, /reloads the UI, or zones between map instances
    -- basically whenever the loading screen appears.
    elseif event == E.PlayerEnteringWorld then
        self:NewMasterLooterCheck()
        -- if we have not yet handled the initial entering world event
        if not handledEnteringWorld then
            -- not relevant for master looter or if no master looter set
            if not self.isMasterLooter and Util.Strings.IsSet(self.masterLooter) and not handledEnteringWorld then
                Logging:Debug("Player '%s' entering world", tostring(self.playerName))
                self:ScheduleTimer("SendCommand", 2, self.masterLooter, C.Reconnect)
                self:SendCommand(self.masterLooter, C.PlayerInfo, self:GetPlayerInfo())
            end
            
            self:UpdatePlayersData()
            handledEnteringWorld = true
        end
    elseif event == E.EncounterStart then
        -- https://wow.gamepedia.com/ENCOUNTER_START
        -- ENCOUNTER_START: encounterID, "encounterName", difficultyID, groupSize
        self.encounter = Models.Encounter(...)
        wipe(self.lootStatus)
        self:UpdatePlayersData()
    elseif event == E.EncounterEnd then
        -- https://wow.gamepedia.com/ENCOUNTER_END
        -- ENCOUNTER_END: encounterID, "encounterName", difficultyID, groupSize, success
        self.encounter = Models.Encounter(...)
        Logging:Debug("EncounterEnd() : %s", Util.Objects.ToString(self.encounter:toTable()))
        -- if master looter, need to check for EP
        -- also, make sure we're actually handling loot - otherwise could award EP when not intended
        if AddOn.isMasterLooter and AddOn.handleLoot then
            self:EffortPointsModule():OnEncounterEnd(self.encounter)
        end
    -- Fired when loot is removed from a corpse
    elseif event == E.LootSlotCleared then
        local slot = ...
        local loot = self.lootSlotInfo[slot]
        if loot and not loot.isLooted then
            local link =  loot.link
            local quality = loot.quality
            Logging:Debug("LootSlotCleared : slot=%s, link=%s, quality=%s", tostring(slot), tostring(link), tostring(quality))
            -- no-op for now
            if quality and quality >= GetLootThreshold() and IsInInstance() then end
            loot.isLooted = true
            
            if self.isMasterLooter then
                self:MasterLooterModule():OnLootSlotCleared(slot, link)
            end
        end
    -- Fired when you a corpse is looted, regardless of whether loot frame is shown
    elseif event == E.LootReady then
        wipe(self.lootSlotInfo)
        if not IsInInstance() then return end
        if GetNumLootItems() <= 0 then return end
        self.lootOpen = true
        for i = 1, GetNumLootItems() do
            if LootSlotHasItem(i) then
                Logging:Debug("LootReady(): Adding Loot Slot %d", i)
                if not self:AddLootSlotInfo(i, ...) then
                    Logging:Debug("LootReady() : Uncached items in loot, retrying again...")
                    return self:ScheduleTimer("OnEvent", 0, "LOOT_READY")
                end
            end
        end
    else
        Logging:Debug("OnEvent(%s) : Unhandled event", event)
    end
end

-- Fired when a corpse is looted
function AddOn:LootOpened(...)
    Logging:Debug("LootOpened()")
    self.lootOpen = true
    if AddOn.isMasterLooter then
        for i =1, GetNumLootItems() do
            local loot = self.lootSlotInfo[i]
            if (not loot and LootSlotHasItem(i)) or (loot and not self:ItemIsItem(loot.link, GetLootSlotLink(i))) then
                Logging:Debug("LootOpened():  Re-building Loot Slot %d", i)
                if not self:AddLootSlotInfo(i, ...) then
                    local _, autoloot, attempt = ...
                    Logging:Warn("LootOpened() : Uncached item (%d) in loot, retrying again (attempt %d) ...", i, attempt or 0)
                    if not attempt then attempt = 1 else attempt = attempt + 1 end
                    return self:ScheduleTimer("LootOpened", attempt / 10, "LOOT_OPENED", autoloot, attempt)
                end
            end
        end
        
        self:MasterLooterModule():OnLootOpen()
    end
end

function AddOn:AddLootSlotInfo(i, ...)
    Logging:Debug("AddLootSlotInfo(%d)", i)
    
    local texture, name, quantity, currencyId, quality = GetLootSlotInfo(i)
    local guid = self:ExtractCreatureId(GetLootSourceInfo(i))
    
    if texture then
        local link = GetLootSlotLink(i)
        if currencyId then
            Logging:Debug("LootOpened() : ignoring %s as it's a currency", tostring(link))
        elseif not self:IsItemBlacklisted(link) then
            Logging:Debug("LootOpened() : adding %s (%s) from %s to Loot Slot Info", tostring(link), tostring(i), tostring(guid))
            -- todo : make the entry a a class
            self.lootSlotInfo[i] = {
                name     = name,
                link     = link,
                quantity = quantity,
                quality  = quality,
                guid     = guid,
                boss     = GetUnitName("target"),
                autoloot = select(1, ...),
            }
        end
        
        -- it was cached, so we did the needful
        return true
    end
    
    -- item not cached, no needful
    return false
end

-- Fired when a player ceases looting a corpse. Note that this will fire before the last
-- CHAT_MSG_LOOT event for that loot
function AddOn:LootClosed()
    Logging:Debug("LootClosed()")
    self.lootOpen = false
end

local UIOptionsOldCancel = InterfaceOptionsFrameCancel:GetScript("OnClick")

function AddOn:EnterCombat()
    InterfaceOptionsFrameCancel:SetScript("OnClick",
                                          function() InterfaceOptionsFrameOkay:Click() end)
    self.inCombat = true
    if not self.db.profile.minimizeInCombat then return end
    UI.MinimizeFrames()
end

function AddOn:LeaveCombat()
    InterfaceOptionsFrameCancel:SetScript("OnClick", UIOptionsOldCancel)
    self.inCombat = false
    if not self.db.profile.minimizeInCombat then return end
    UI.MaximizeFrames()
end

function AddOn:SendGuildVersionCheck()
    local C = AddOn.Constants
    self:SendCommand(C.guild, C.Commands.VersionCheck, self.version, self.mode)
end

function AddOn:PrintOutOfDateVersionWarning(newVersion, ourVersion)
    self:Print(format(L["version_out_of_date_msg"], tostring(ourVersion or self.version), tostring(newVersion)))
    self.versionCheckComplete = true
end

