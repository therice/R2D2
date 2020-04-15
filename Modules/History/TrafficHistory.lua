local _, AddOn = ...
local TrafficHistory= AddOn:NewModule("TrafficHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging       = AddOn.Libs.Logging
local Util          = AddOn.Libs.Util
local Objects       = Util.Objects
local Tables        = Util.Tables
local Strings       = Util.Strings
local UI            = AddOn.components.UI
local L             = AddOn.components.Locale
local Models        = AddOn.components.Models
local Traffic       = Models.History.Traffic
local ST            = AddOn.Libs.ScrollingTable

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

local ROW_HEIGHT, NUM_ROWS = 20, 15
local SubjectTypesForDisplay, ActionTypesForDisplay, ResourceTypesForDisplay = {}, {}, {}
local selectedDate, selectedName, selectedAction, selectedResource

function TrafficHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    self.db = AddOn.Libs.AceDB:New('R2D2_TrafficDB', TrafficHistory.defaults)
    self.scrollCols = {
        -- actor
        {
            name = L["actor"],
            width = 100,
        },
        -- class icon
        {
            name = "",
            width = ROW_HEIGHT,
        },
        -- subject (e.g. player name)
        {
            name = L["subject"],
            width = 100,
        },
        -- timestamp
        {
            name = L['date'],
            width = 125,
            sort = 2,
            defaultsort = 2,
        },
        -- action
        {
            name = L["action"],
            width = 50,
        },
        -- type
        {
            name = L["resource"],
            width = 50,
        },
        -- type
        {
            name = L["amount"],
            width = 50,
        },
        -- before
        {
            name = L["before"],
            width = 50,
        },
        -- after
        {
            name = L["after"],
            width = 50,
        },
        -- description
        {
            name = L["description"],
            width = 250,
        },
    }
    
    for key, value in pairs(Traffic.SubjectType) do
        if value ~= Traffic.SubjectType.Character then
            SubjectTypesForDisplay[key] = {
                {DoCellUpdate =  UI.ScrollingTableDoCellUpdate(TrafficHistory.SetSubjectIcon), args = { value }},
                {value = key, name = key, DoCellUpdate =  UI.ScrollingTableDoCellUpdate(TrafficHistory.SetSubject), args = { value }}
            }
        end
    end
    
    for key, value in pairs(Traffic.ActionType) do
        Tables.Push(
            ActionTypesForDisplay,
            {
                { value = key, name = key, DoCellUpdate = UI.ScrollingTableDoCellUpdate(TrafficHistory.SetAction), args = { value }}
            }
        )
    end
    
    for key, value in pairs(Traffic.ResourceType) do
        Tables.Push(
                ResourceTypesForDisplay,
                {
                    { value = key, name = key, DoCellUpdate = UI.ScrollingTableDoCellUpdate(TrafficHistory.SetResource), args = { value }}
                }
        )
    end
end

function TrafficHistory:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self:BuildData()
    self:Show()
end

function TrafficHistory:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
    if self.frame then self.frame:SetParent(nil) end
    self.frame = nil
end

function TrafficHistory:EnableOnStartup()
    return false
end

function TrafficHistory:GetHistory()
    return self.db.factionrealm
end

function TrafficHistory:AddEntry(entry)
    tinsert(self:GetHistory(), entry:toTable())
end

function TrafficHistory:Show()
    self.frame:Show()
end

function TrafficHistory:Hide()
    if self.frame then self.frame:Hide() end
end

function TrafficHistory:BuildData()
    self.frame.rows = {}
    
    local tsData, nameData = {}, {}
    for row, entryTable in pairs(self:GetHistory()) do
        local entry = Models.History.Traffic():reconstitute(entryTable)
        
        self.frame.rows[row] = {
            date = entry.timestamp,
            num = row,
            entry = entry,
            cols = {
                -- individual who performed action
                {value = AddOn.Ambiguate(entry.actor), color = AddOn.GetClassColor(entry.actorClass)},
                -- the icon of the class who received the item
                {DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellSubjectIcon)},
                {value = entry.subjectType, DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellSubject)},
                {value = entry:FormattedTimestamp() or ""},
                {value = entry.actionType, DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellAction)},
                {value = entry.resourceType, DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellResource)},
                {value = entry.resourceQuantity},
                {value = entry.resourceBefore},
                {DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellResourceAfter)},
                {value = entry.description},
            }
        }
    
        -- keep a copy of all the timestamps that map to date
        -- could probably calculate later
        local fmtDate = entry:FormattedDate()
        if not Tables.ContainsKey(tsData, fmtDate) then
            tsData[fmtDate] = {entry:FormattedDate(), timestamps = {}}
        end
        Tables.Push(tsData[fmtDate].timestamps, entry.timestamp)
        
        -- Add all the individual character's to name data
        if entry.subjectType == Traffic.SubjectType.Character then
            local subject = entry.subjects[1]
            if not Tables.ContainsKey(nameData, subject[1]) then
                local subjectName = subject[1]
                local subjectClass = subject[2]

                nameData[subjectName] = {
                    { DoCellUpdate = AddOn.SetCellClassIcon, args = { subjectClass } },
                    { value = AddOn.Ambiguate(subjectName), color = AddOn.GetClassColor(subjectClass), name = subjectName},
                }
            end
        end
    end
    
    Tables.CopyInto(nameData, SubjectTypesForDisplay)
    
    self.frame.st:SetData(self.frame.rows)
    self.frame.date:SetData(Tables.Values(tsData), true)
    self.frame.name:SetData(Tables.Values(nameData), true)
    self.frame.action:SetData(ActionTypesForDisplay, true)
    self.frame.resource:SetData(ResourceTypesForDisplay, true)
end

function TrafficHistory.SetCellSubjectIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local entry = data[realrow].entry
    local subjectType = entry.subjectType
    
    -- single character, so will be only one entry in subjects
    if subjectType == Traffic.SubjectType.Character then
        local subjectEntry, subjectClass = entry.subjects[1], nil
        if subjectEntry and Tables.Count(subjectEntry) == 2 then
            subjectClass = subjectEntry[2]
        end
        AddOn.SetCellClassIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, subjectClass)
    else
        SetSubjectIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, subjectType)
    end
end

function TrafficHistory.SetSubjectIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, subjectType)
    local subjectType = subjectType or data[realrow][column].args[1]
    -- https://wow.gamepedia.com/API_Texture_SetTexCoord
    if subjectType == Traffic.SubjectType.Guild then
        frame:SetNormalTexture(134157)
        frame:GetNormalTexture():SetTexCoord(0,1,0,1)
    elseif subjectType == Traffic.SubjectType.Raid then
        frame:SetNormalTexture(134156)
        frame:GetNormalTexture():SetTexCoord(0,1,0,1)
    end
end

function TrafficHistory.SetCellSubject(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local entry = data[realrow].entry
    local subjectType = entry.subjectType
    -- single character, so will be only one entry in subjects
    if subjectType == Traffic.SubjectType.Character then
        frame.text:SetText(AddOn.Ambiguate(entry.subjects[1][1]))
        frame.text:SetTextColor(AddOn.GetClassColor(entry.subjects[1][2]):GetRGB())
    else
        TrafficHistory.SetSubject(rowFrame, frame, data, cols, row, realrow, column, fShow, table, subjectType)
    end
end

function TrafficHistory.SetSubject(rowFrame, frame, data, cols, row, realrow, column, fShow, table, subjectType)
    local subjectType = subjectType or data[realrow][column].args[1]
    if subjectType == Traffic.SubjectType.Guild then
        frame.text:SetText(_G.GUILD)
        frame.text:SetTextColor(GetItemQualityColor(2))
    elseif subjectType == Traffic.SubjectType.Raid then
        frame.text:SetText(_G.GROUP)
        frame.text:SetTextColor(GetItemQualityColor(5))
    end
end

function TrafficHistory.SetCellAction(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    TrafficHistory.SetAction(rowFrame, frame, data, cols, row, realrow, column, fShow, table, data[realrow].entry.actionType)
end

function TrafficHistory.SetAction(rowFrame, frame, data, cols, row, realrow, column, fShow, table, actionType)
    local actionType = actionType or data[realrow][column].args[1]
    
    frame.text:SetText(Traffic.TypeIdToAction[actionType])
    if actionType == Traffic.ActionType.Add then
        frame.text:SetTextColor(0, 1, 0.59, 1)
    elseif actionType == Traffic.ActionType.Subtract then
        frame.text:SetTextColor(0.96, 0.55, 0.73, 1)
    elseif actionType == Traffic.ActionType.Reset then
        frame.text:SetTextColor(1, 0.96, 0.41, 1)
    end
end

function TrafficHistory.SetCellResource(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    TrafficHistory.SetResource(rowFrame, frame, data, cols, row, realrow, column, fShow, table, data[realrow].entry.resourceType)
end

function TrafficHistory.SetResource(rowFrame, frame, data, cols, row, realrow, column, fShow, table, resourceType)
    local resourceType = resourceType or data[realrow][column].args[1]
    frame.text:SetText(Traffic.TypeIdToResource[resourceType]:upper())
    if resourceType == Traffic.ResourceType.Ep then
        frame.text:SetTextColor(GetItemQualityColor(6))
    elseif resourceType == Traffic.ResourceType.Gp then
        frame.text:SetTextColor(GetItemQualityColor(5))
    end
end

function TrafficHistory.SetCellResourceAfter(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local entry = data[realrow].entry
    local value = entry.resourceBefore
    if entry.actionType == Traffic.ActionType.Add then
        value = value + entry.resourceQuantity
    elseif entry.actionType == Traffic.ActionType.Subtract then
        value = value - entry.resourceQuantity
    elseif entry.actionType == Traffic.ActionType.Reset then
        value = 0 -- this is probably wrong and needs to be the min value
    end
    
    data[realrow].cols[column].value = value
    frame.text:SetText(value)
end

local function IsFiltering()
    local moduleSettings = AddOn:ModuleSettings(TrafficHistory:GetName())
    for _,v in pairs(moduleSettings.filters) do
        if not v then return true end
    end
    for _,v in pairs(moduleSettings.filters.class) do
        if v then return true end
    end
end

function TrafficHistory:Update()
    self.frame.st:SortData()
    if IsFiltering() then
        self.frame.filter.Text:SetTextColor(0.86,0.5,0.22) -- #db8238
    else
        self.frame.filter.Text:SetTextColor(_G.NORMAL_FONT_COLOR:GetRGB()) --#ffd100
    end
end

function TrafficHistory:GetFrame()
    if self.frame then return end
    local f = UI:CreateFrame("R2D2_TrafficHistory", "TrafficHistory",  L["r2d2_traffic_history_frame"], 250, 480)
    local st = ST:CreateST(self.scrollCols, NUM_ROWS, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    st.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    st:SetFilter(self.FilterFunc)
    st:EnableSelection(true)
    f.st = st
    
    f.date = ST:CreateST(
            {
                {
                    name = L["date"],
                    width = 70,
                    sort = 2,
                }
            },
            5, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content
    )
    f.date.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -20)
    f.date:EnableSelection(true)
    f.date:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if button == "LeftButton" and row then
                                      local timestamps = data[realrow].timestamps
                                      if not Tables.Equals(selectedDate, timestamps) then
                                          selectedDate = timestamps
                                      else
                                          selectedDate = nil
                                      end
                                      
                                      -- Logging:Debug("%s", Objects.ToString(selectedDate))
                                      
                                      self:Update()
                                  end
                                  return false
                              end
                          })
    
    f.name = ST:CreateST(
            {
                {
                    name = "",
                    width = ROW_HEIGHT
                },
                {
                    name = _G.NAME,
                    width = 100,
                    sort = 1
                }
            },
            5, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    f.name.frame:SetPoint("TOPLEFT", f.date.frame, "TOPRIGHT", 20, 0)
    f.name:EnableSelection(true)
    f.name:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if button == "LeftButton" and row then
                                      local rowName = data[realrow][column].name
                                      selectedName = selectedName ~= rowName and rowName or nil
                                      -- Logging:Debug("%s", tostring(selectedName))
                                      self:Update()
                                  end
                                  return false
                              end
                          })
    
    f.action = ST:CreateST(
            {
                {
                    name = L["action"],
                    width = 50,
                    sort = 1
                }
            },
            5, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    f.action.frame:SetPoint("TOPLEFT", f.name.frame, "TOPRIGHT", 20, 0)
    f.action:EnableSelection(true)
    f.action:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if button == "LeftButton" and row then
                                      local rowName = data[realrow][column].name
                                      selectedAction = selectedAction ~= rowName and rowName or nil
                                      -- Logging:Debug("%s", tostring(selectedAction))
                                      self:Update()
                                  end
                                  return false
                              end
                          })
    
    f.resource = ST:CreateST(
            {
                {
                    name = L["resource"],
                    width = 50,
                    sort = 1
                }
            },
            5, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    f.resource.frame:SetPoint("TOPLEFT", f.action.frame, "TOPRIGHT", 20, 0)
    f.resource:EnableSelection(true)
    f.resource:RegisterEvents({
                                ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                    if button == "LeftButton" and row then
                                        local rowName = data[realrow][column].name
                                        selectedResource = selectedResource ~= rowName and rowName or nil
                                        -- Logging:Debug("%s", tostring(selectedResource))
                                        self:Update()
                                    end
                                    return false
                                end
                            })
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -100)
    close:SetScript("OnClick", function() self:Disable() end)
    f.closeBtn = close
    
    
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("RIGHT", f.closeBtn, "LEFT", -10, 0)
    f.filter = filter
    f.filter:SetSize(125,25)
    
    
    local clear = UI:CreateButton(L["clear_selection"], f.content)
    clear:SetPoint("RIGHT", f.filter, "LEFT", -10, 0)
    clear:SetScript("OnClick", function()
        selectedDate, selectedName, selectedAction, selectedResource = nil, nil, nil, nil
        self.frame.date:ClearSelection()
        self.frame.name:ClearSelection()
        self.frame.action:ClearSelection()
        self.frame.resource:ClearSelection()
        self:Update()
    end)
    clear:SetWidth(125)
    f.clearSelectionBtn = clear
    
    f:SetWidth(st.frame:GetWidth() + 20)
    return f
end

local function SelectionFilter(entry)
    Logging:Debug("SelectionFilter() : %s", Objects.ToString(entry, 3))
    --Logging:Trace("FilterByNameAndDate() : %s, %s, %s, %s",
    --              tostring(name), tostring(date), tostring(action), tostring(resource))
    
    local display = true
    
    if Tables.IsSet(selectedDate) then
        display = Tables.ContainsValue(selectedDate, entry.timestamp)
    end
    
    if display and Strings.IsSet(selectedName) then
        local subjectType = entry.subjectType
        if subjectType == Traffic.SubjectType.Character then
            display = Strings.Equal(selectedName, entry.subjects[1][1])
        -- todo : other subjects
        end
    end
    --
    --if Tables.IsSet(selectedDate) then
    --    display = Tables.ContainsValue(selectedDate, date)
    --end
    --
    --if display and Strings.IsSet(selectedInstance) then
    --    display = Strings.Equal(selectedInstance, instance)
    --end
    --
    --if display and Strings.IsSet(selectedName) then
    --    display = Strings.Equal(selectedName, name)
    --end
    
    return display
end

function TrafficHistory.FilterFunc(table, row)
    local entry = row.entry
    Logging:Trace("Applying Selection Filter(s)")
    local selectionFilter = SelectionFilter(entry)
    
    ---- determine if module filters need respected
    --local moduleFilters = AddOn:ModuleSettings(LootHistory:GetName()).filters
    --if not moduleFilters then return selectionFilter end
    --
    --Logging:Trace("Applying Class Filter(s)")
    --local classFilter = ClassFilter(entry.class)
    --
    --Logging:Trace("Applying Response Filter(s)")
    --local responseFilter = ResponseFilter(entry.responseId, entry:IsAwardReason())
    
    return selectionFilter --and classFilter and responseFilter
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
    entry.actorClass = AddOn.playerClass
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
-- @param awardData the award popup data (see LootAllocate.GetAwardPopupData
-- @param desc the description for entry
function TrafficHistory:CreateFromLootHistory(actionType, subjectType, resourceType, lootHistoryEntry, awardData)
    local baseGp, awardGp = awardData.baseGp, awardData.awardGp
    
    local function BeforeSend(entry)
        entry.lootHistoryId = lootHistoryEntry.id
        -- copy over attributes to traffic entry which are relevant
        -- could ignore them and rely upon loot history for later retrieval, but there's no guarantee
        -- the loot and traffic histories are not pruned independently
        for _, attr in pairs(Tables.New('item', 'mapId', 'instance', 'boss', 'response', 'responseId', 'typeCode')) do
            -- Logging:Debug("CreateFromLootHistory(%s)", tostring(attr))
            entry[attr] = lootHistoryEntry[attr]
        end
        
        entry.baseGp = baseGp
        entry.awardScale = awardData.awardScale
        entry.ownerClass = awardData.class
    end
    
    return self:CreateEntry(
            actionType,
            subjectType,
            {lootHistoryEntry.owner},
            resourceType,
            awardGp and awardGp or baseGp,
            format(L["awarded_item_for_reason"], lootHistoryEntry.item, lootHistoryEntry:FormattedResponse()),
            BeforeSend
    )
end