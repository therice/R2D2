local _, AddOn = ...
local LootHistory = AddOn:NewModule("LootHistory", "AceEvent-3.0", "AceTimer-3.0")
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local L = AddOn.components.Locale
local Models = AddOn.components.Models
local CDB = Models.CompressedDb
local UI = AddOn.components.UI
local Tables = Util.Tables
local Objects = Util.Objects
local Strings = Util.Strings
local ST = AddOn.Libs.ScrollingTable

LootHistory.options = {
    name = L['loot_history'],
    desc = L['loot_history_desc'],
    ignore_enable_disable = true,
    args = {
        openHistory = {
            order = 5,
            name = L['open_loot_history'],
            desc = L['open_loot_history_desc'],
            type = "execute",
            func = function()
                AddOn:CallModule("LootHistory")
            end,
        },
    },
}

LootHistory.defaults = {
    profile = {
        enabled = true,
    }
}

local ROW_HEIGHT, NUM_ROWS = 20, 15
local MenuFrame, FilterMenu, selectedDate, selectedName, selectedInstance, moreInfo
local stats = {stale = true, value = nil}

function LootHistory:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    self.scrollCols = {
        -- 1 class icon
        {
            name = "",
            width = ROW_HEIGHT,
            sortnext = 2
        },
        -- 2 player name
        {
            name = _G.NAME,
            width = 100,
            sortnext = 3,
            defaultsort = 1,
        },
        -- 3 timestamp
        {
            name = L['date'],
            width = 125,
            sort = 2,
            defaultsort = 2,
        },
        -- instance
        {
            name = L['instance'],
            width = 125,
            sort = 2,
            defaultsort = 2,
        },
        -- 5 item icon
        {
            name = "",
            width = ROW_HEIGHT,
        },
        -- 6 item string
        {
            name = L['item'],
            width = 250,
            comparesort = self.ItemSort,
            defaultsort = 1,
            sortnext = 2
        },
        -- 7 response
        {
            name = L['reason'],
            width = 220,
            comparesort = self.ResponseSort,
            defaultsort = 1,
            sortnext = 2
        },
        -- 8 delete icon
        {
            name = "",
            width = ROW_HEIGHT
        },
    }
    self.db = AddOn.Libs.AceDB:New('R2D2_LootDB', LootHistory.defaults)
    self.history = CDB(self.db.factionrealm)
    
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.LootHistoryRightClick, UIParent)
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.LootHistoryFilter, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
    self.moreInfo = CreateFrame( "GameTooltip", "R2D2_" .. self:GetName() .. "_MoreInfo", nil, "GameTooltipTemplate" )
end

function LootHistory:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    moreInfo = AddOn:MoreInfoEnabled(self:GetName())
    self.frame = self:GetFrame()
    self:BuildData()
    self:Show()
end

function LootHistory:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
    moreInfo = false
end

function LootHistory:EnableOnStartup()
    return false
end

function LootHistory:GetHistory()
    Logging:Trace("GetHistory()")
    return self.history
end

function LootHistory:Show()
    self.frame:Show()
end

--- Hide the LootHistory frame.
function LootHistory:Hide()
    if self.moreInfo then self.moreInfo:Hide() end
    if self.frame then self.frame:Hide() end
end

function LootHistory:BuildData()
    local data = {}
    
    local c_pairs = CDB.static.pairs
    
    for name, entries in c_pairs(self:GetHistory()) do
        for index, entryTable in pairs(entries) do
            local entry = Models.History.Loot():reconstitute(entryTable)
            local ts = entry.timestamp
            
            if not Tables.ContainsKey(data, ts) then
                data[ts] = {}
            end

            if not Tables.ContainsKey(data[ts], name) then
                data[ts][name] = {}
            end

            if not Tables.ContainsKey(data[ts][name], index) then
                data[ts][name][index] = {}
            end
            
            data[ts][name][index] = entry
        end
    end
    
    -- Logging.Debug("%s", Objects.ToString(data, 3))
    
    table.sort(data)
    self.frame.rows = {}
    local tsData, instanceData, row = {}, {}, 1
    for ts, names in pairs(data) do
        -- Logging:Debug("pairs(data) -> %d = %d", ts, Tables.Count(names))
        for name, entries in pairs(names) do
            -- Logging:Debug("pairs(name) - > %s = %d", name, Tables.Count(entries))
            for index, entry in pairs(entries) do
                -- Logging:Debug("pairs(entries) -> %s = %s", tostring(index), type(entry))
                
                if Objects.IsTable(entry) then
                    --[[
                    Logging:Debug("pairs(entries) -> %s = %s",
                                  tostring(index),
                                  Objects.ToString(entry:toTable())
                    )
                    --]]
                    
                    -- probably only need entry here, but ...
                    self.frame.rows[row] = {
                        date = ts,
                        num = index,
                        entry = entry,
                        cols = {
                            { value = entry.class, DoCellUpdate = AddOn.SetCellClassIcon, args = { entry.class } },
                            { value = AddOn.Ambiguate(name), color = AddOn.GetClassColor(entry.class) },
                            { value = entry:FormattedTimestamp() or "",  comparesort = UI.SortByTimestamp},
                            { value = entry.instance},
                            { DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellGear)},
                            { value = entry.item },
                            { DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellResponse)},
                            { DoCellUpdate = UI.ScrollingTableDoCellUpdate(self.SetCellDelete)},
                        }
                    }
                    
                    -- keep a copy of all the timestamps that map to date
                    -- could probably calculate later
                    local fmtDate = entry:FormattedDate()
                    if not Tables.ContainsKey(tsData, fmtDate) then
                        tsData[fmtDate] = {entry:FormattedDate(), timestamps = {}}
                    end
                    Tables.Push(tsData[fmtDate].timestamps, entry.timestamp)
    
                    if not Tables.ContainsKey(instanceData, entry.instance) then
                        instanceData[entry.instance] = {entry.instance}
                    end
                    
                    row = row + 1
                end
            end
        end
    end
    
    local function NameClassEntry(name, class)
        return {
            { DoCellUpdate = AddOn.SetCellClassIcon, args = { class } },
            { value = AddOn.Ambiguate(name), color = AddOn.GetClassColor(class), name = name},
        }
    end
    
    local nameData = Util(self.frame.rows):Copy()
                    :Group(function(row) return row.entry.owner end)
                    :Map(
                        function(rows)
                            local first = Tables.First(rows).entry
                            return NameClassEntry(first.owner, first.class)
                        end
                    )()
    
    for name, entry in pairs(AddOn.candidates) do
        if not Tables.ContainsKey(nameData, name) then
            nameData[name] = NameClassEntry(name, entry.class)
        end
    end
    
    nameData = Tables.Values(nameData)
    
    -- Logging:Debug("%s", Objects.ToString(nameData, 6))
    -- Logging:Debug("%s", Objects.ToString(nameData, 5))
    
    self.frame.st:SetData(self.frame.rows)
    self.frame.date:SetData(Tables.Values(tsData), true)
    self.frame.instance:SetData(Tables.Values(instanceData), true)
    self.frame.name:SetData(nameData, true)
    
end

function LootHistory.SetCellGear(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local item = data[realrow].entry.item
    if item then
        local texture = select(5, GetItemInfoInstant(item))
        frame:SetNormalTexture(texture)
        frame:SetScript("OnEnter", function() UI:CreateHypertip(item) end)
        frame:SetScript("OnLeave", function() UI:HideTooltip() end)
        frame:SetScript("OnClick", function()
            if IsModifiedClick() then
                HandleModifiedItemClick(item)
            end
        end)
        frame:Show()
    else
        frame:Hide()
    end
end

function LootHistory.SetCellResponse(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local entry = data[realrow].entry
    frame.text:SetText(entry.response)
    
    if entry.color and Objects.IsTable(entry.color) then
        frame.text:SetTextColor(unpack(entry.color))
    elseif entry.responseId and entry.responseId > 0 then
        frame.text:SetTextColor(unpack(AddOn:GetResponse('default', entry.responseId).color))
    else
        frame.text:SetTextColor(1,1,1,1)
    end
end

function LootHistory.SetCellDelete(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    
    if not frame.created then
        frame:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        frame:SetScript("OnEnter", function()
            UI:CreateTooltip(L['double_click_to_delete_this_entry'])
        end)
        frame:SetScript("OnLeave", function() UI:HideTooltip() end)
        frame.created = true
    end
    
    frame:SetScript("OnClick", function()
        local name, num = data[realrow].entry.owner, data[realrow].num
        if frame.lastClick and GetTime() - frame.lastClick <= 0.5 then
            frame.lastClick = nil
            Logging:Debug("LootHistory : Deleting %s, %s", tostring(name), tostring(num))
            local history = LootHistory:GetHistory()
            
            history:del(name, num)
            tremove(data, realrow)
    
            for _, v in pairs(data) do
                if v.name == name then
                    if v.num >= num then
                        v.num = v.num - 1
                    end
                end
            end
    
            table:SortData()
            
            local charHistory = history:get(name)
            if #charHistory == 0 then
                Logging:Debug("Last LootHistory entry deleted, removing %s", name)
                history:del(name)
            end
        else
            frame.lastClick = GetTime()
        end
    end)
end

function LootHistory.ItemSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                   function(row)
                       return ItemUtil:ItemLinkToItemName(row.cols[5].value)
                   end
    )
end


function LootHistory.ResponseSort(table, rowa, rowb, sortbycol)
    return UI.Sort(table, rowa, rowb, sortbycol,
                   function(row)
                       local responseId = row.entry.responseId
                       return AddOn:GetResponse(nil, responseId).sort or 500
                   end
    )
end

local function IsFiltering()
    local moduleSettings = AddOn:ModuleSettings(LootHistory:GetName())
    for _,v in pairs(moduleSettings.filters) do
        if not v then return true end
    end
    for _,v in pairs(moduleSettings.filters.class) do
        if v then return true end
    end
end

function LootHistory:Update()
    self.frame.st:SortData()
    if IsFiltering() then
        self.frame.filter.Text:SetTextColor(0.86,0.5,0.22) -- #db8238
    else
        self.frame.filter.Text:SetTextColor(_G.NORMAL_FONT_COLOR:GetRGB()) --#ffd100
    end
end

function LootHistory:GetFrame()
    if self.frame then return self.frame end
    local f = UI:CreateFrame("R2D2_LootHistory", "LootHistory",  L["r2d2_loot_history_frame"], 250, 480)
    local st = ST:CreateST(self.scrollCols, NUM_ROWS, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
    st.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    st:SetFilter(self.FilterFunc)
    st:EnableSelection(true)
    st:RegisterEvents({
                          ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                              if row or realrow then
                                  if button == "LeftButton" then
                                      self:UpdateMoreInfo(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  elseif button == "RightButton" then
                                      MenuFrame.datatable = data[realrow]
                                      MSA_ToggleDropDownMenu(1,nil,MenuFrame,cellFrame,0,0)
                                  end
                              end
                              return false
                          end
                      })
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
                                      --Logging:Debug("%s", Objects.ToString(timestamps))
                                      if not Tables.Equals(selectedDate, timestamps) then
                                          selectedDate = timestamps
                                      else
                                          selectedDate = nil
                                      end
                                      self:Update()
                                  end
                                  return false
                              end
                          })
    
    f.instance = ST:CreateST(
            {
                {
                    name = L["instance"],
                    width = 100,
                    sort = 2,
                }
            },
            5, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content
    )
    f.instance.frame:SetPoint("TOPLEFT", f.date.frame, "TOPRIGHT", 20, 0)
    f.instance:EnableSelection(true)
    f.instance:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if button == "LeftButton" and row then
                                      local instanceName = data[realrow][column]
                                      selectedInstance = selectedInstance ~= instanceName and instanceName or nil
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
    f.name.frame:SetPoint("TOPLEFT", f.instance.frame, "TOPRIGHT", 20, 0)
    f.name:EnableSelection(true)
    f.name:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if button == "LeftButton" and row then
                                      local rowName = data[realrow][column].name
                                      selectedName = selectedName ~= rowName and rowName or nil
                                      self:Update()
                                  end
                                  return false
                              end
                          })
    
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -100)
    close:SetScript("OnClick", function() self:Disable() end)
    f.closeBtn = close
    
    local moreInfoBtn = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    moreInfoBtn:SetSize(25, 25)
    moreInfoBtn:SetPoint("BOTTOMRIGHT", f.closeBtn , "TOPRIGHT", 0, 10)
    moreInfoBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    moreInfoBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    moreInfoBtn:SetScript("OnClick", function(button)
        moreInfo = not moreInfo
        AddOn:ModuleSettings(LootHistory:GetName()).moreInfo = moreInfo
        self.frame.st:ClearSelection()
        self:UpdateMoreInfo()
        if moreInfo then -- show the more info frame
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
            self.moreInfo:Show()
        else -- hide it
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
            self.moreInfo:Hide()
        end
    end)
    moreInfoBtn:SetScript("OnEnter", function() UI:CreateTooltip(L["click_more_info"]) end)
    moreInfoBtn:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.moreInfoBtn = moreInfoBtn
    
    f.content:SetScript("OnSizeChanged", function()
        self.moreInfo:SetScale(f:GetScale() * 0.6)
    end)
    
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("RIGHT", f.closeBtn, "LEFT", -10, 0)
    filter:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    f.filter = filter
    MSA_DropDownMenu_Initialize(filter, self.FilterMenu)
    f.filter:SetSize(125,25)
    
    local clear = UI:CreateButton(L["clear_selection"], f.content)
    clear:SetPoint("RIGHT", f.filter, "LEFT", -10, 0)
    clear:SetScript("OnClick", function()
        selectedDate, selectedInstance, selectedName = nil, nil, nil
        self.frame.date:ClearSelection()
        self.frame.instance:ClearSelection()
        self.frame.name:ClearSelection()
        self:Update()
    end)
    clear:SetWidth(125)
    f.clearSelectionBtn = clear
    
    
    f:SetWidth(st.frame:GetWidth() + 20)
    return f
end

function LootHistory:UpdateMoreInfo(rowFrame, cellFrame, data, cols, row, realrow, column, tabel, button, ...)
    if not data then return end
    local tip = self.moreInfo
    tip:SetOwner(self.frame, "ANCHOR_RIGHT")
    
    local entry = data[realrow].entry
    local color = AddOn.GetClassColor(entry.class)
    
    tip:AddLine(AddOn.Ambiguate(entry.owner), color.r, color.g, color.b)
    tip:AddLine("")
    tip:AddDoubleLine(L["date"] .. ":", entry:FormattedTimestamp() or _G.UNKNOWN, 1,1,1, 1,1,1)
    tip:AddDoubleLine(L["loot_won"] .. ":", entry.item or _G.UNKNOWN, 1,1,1, 1,1,1)
    tip:AddDoubleLine(L["dropped_by"] .. ":", entry.boss or _G.UNKNOWN, 1,1,1, 0.862745, 0.0784314, 0.235294)
    tip:AddDoubleLine(_G.FROM, entry.instance or _G.UNKNOWN, 1,1,1, 0.823529, 0.411765, 0.117647)
    if entry.note then
        tip:AddDoubleLine(_G.LABEL_NOTE .. ":", entry.note, 1,1,1, 1,1,1)
    end
    tip:AddLine(" ")
    tip:AddLine(L["total_awards"])
    
    local stats = self:GetStatistics():Get(entry.owner)
    stats:CalculateTotals()
    -- Logging:Debug("%s => %s", entry.owner, Objects.ToString(stats))
    
    table.sort(stats.totals.responses,
               function(a, b)
                   local responseId1, responseId2 = a[4], b[4]
                   return Objects.IsNumber(responseId1) and Objects.IsNumber(responseId2) and responseId1 < responseId2 or false
               end
    )
    for _, v in pairs(stats.totals.responses) do
        local r,g,b
        if v[3] then r,g,b = unpack(v[3],1,3) end
        tip:AddDoubleLine(v[1], v[2], r or 1, g or 1, b or 1, 1,1,1)
    end
    tip:AddDoubleLine(L["number_of_raids_from which_loot_was_received"] .. ":", stats.totals.raids.count, 1,1,1, 1,1,1)
    tip:AddDoubleLine(L["total_items_won"] .. ":", stats.totals.count, 1,1,1, 0,1,0)
    tip:AddLine(" ")
    
    tip:SetScale(self.frame:GetScale() * 0.65)
    if moreInfo then
        tip:Show()
    else
        tip:Hide()
    end
    tip:SetAnchorType("ANCHOR_RIGHT", 0, -tip:GetHeight())
    
end

function LootHistory.FilterMenu(menu, level)
    local info, value = nil, _G.MSA_DROPDOWNMENU_MENU_VALUE
    local ModuleFilters = AddOn:ModuleSettings(LootHistory:GetName()).filters

    
    if level == 1 then
        -- Build the data table:
        local data = {
            ["STATUS"]      = true,
            ["PASS"]        = true,
            ["AUTOPASS"]    = true,
        }
        for i = 1, AddOn:GetNumButtons() do data[i] = i end
    
        info = MSA_DropDownMenu_CreateInfo()
        info.text = _G.FILTER
        info.isTitle = true
        info.notCheckable = true
        info.disabled = true
        MSA_DropDownMenu_AddButton(info, level)
        
        info = MSA_DropDownMenu_CreateInfo()
        info.text = _G.CLASS
        info.isTitle = false
        info.hasArrow = true
        info.notCheckable = true
        info.disabled = false
        info.value = "CLASS"
        MSA_DropDownMenu_AddButton(info, level)
        
        info = MSA_DropDownMenu_CreateInfo()
        info.text = L["Responses"]
        info.isTitle = true
        info.notCheckable = true
        info.disabled = true
        MSA_DropDownMenu_AddButton(info, level)
        
        info = MSA_DropDownMenu_CreateInfo()
        for k in ipairs(data) do
            info.text = AddOn:GetResponse("default",k).text
            info.colorCode = UI.RGBToHexPrefix(AddOn:GetResponseColor(nil,k))
            info.func = function()
                ModuleFilters[k] = not ModuleFilters[k]
                LootHistory:Update()
            end
            info.checked = ModuleFilters[k]
            MSA_DropDownMenu_AddButton(info, level)
        end
    
        for k in pairs(data) do
            if Util.Objects.IsString(k) then
                if k == "STATUS" then
                    info.text = L["status_texts"]
                    info.colorCode = "|cffde34e2"
                else
                    info.text = AddOn:GetResponse("",k).text
                    info.colorCode = UI.RGBToHexPrefix(AddOn:GetResponseColor(nil,k))
                end
                
                info.func = function()
                    ModuleFilters[k] = not ModuleFilters[k]
                    LootHistory:Update(true)
                end
                info.checked = ModuleFilters[k]
                MSA_DropDownMenu_AddButton(info, level)
            end
        end
    elseif level == 2 then
        if value == "CLASS" then
            -- these will be a table of sorted display class names
            local data = Util(ItemUtil.ClassDisplayNameToId):Keys()
                            :Filter(AddOn.FilterClassesByFactionFn):Sort():Copy()()
    
            
            for _, class in pairs(data) do
                info = MSA_DropDownMenu_CreateInfo()
                info.text = class
                info.colorCode = "|cff" .. AddOn.GetClassColorRGB(class)
                info.keepShownOnClick = true
                info.func = function()
                    ModuleFilters.class[class] = not ModuleFilters.class[class]
                    LootHistory:Update(true)
                end
                info.checked = ModuleFilters.class[class]
                MSA_DropDownMenu_AddButton(info, level)
            end
    
            info = MSA_DropDownMenu_CreateInfo()
            info.text = "Deselect All"
            info.notCheckable = true
            info.keepShownOnClick = true
            info.func = function()
                for _, k in pairs(data) do
                    ModuleFilters.class[k] = not ModuleFilters.class[k]
                    MSA_DropDownMenu_SetSelectedName(FilterMenu, ItemUtil.ClassIdToDisplayName[k], false)
                    LootHistory:Update()
                end
            end
            MSA_DropDownMenu_AddButton(info, level)
        end
    end
    
end

function LootHistory.RightClickMenu(menu, level)
    -- empty for now, don't think there's value here
end

local function SelectionFilter(name, instance, date)
    Logging:Trace("FilterByNameAndDate(%s, %s, %s) : %s, %s %s",
                  tostring(selectedName), tostring(selectedInstance), Objects.ToString(selectedDate),
                  tostring(name), tostring(instance), tostring(date))
    
    local display = true
    
    if Tables.IsSet(selectedDate) then
        display = Tables.ContainsValue(selectedDate, date)
    end
    
    if display and Strings.IsSet(selectedInstance) then
        display = Strings.Equal(selectedInstance, instance)
    end
    
    if display and Strings.IsSet(selectedName) then
        display = Strings.Equal(selectedName, name)
    end
    
    return display
end

local function ClassFilter(class)
    class = ItemUtil:ClassTransitiveMapping(class)
    local ModuleFilters = AddOn:ModuleSettings(LootHistory:GetName()).filters
    Logging:Trace("ClassFilter(%s)", class)
    
    -- Logging:Debug("ClassFilter(%s) : %s, %s", class, tostring(useClassFilters), Objects.ToString(ModuleFilters))
    if ModuleFilters then return ModuleFilters.class[class] end
    return true
end

local function ResponseFilter(response, isAwardReason)
    Logging:Trace("ResponseFilter(%s, %s)", tostring(response), tostring(isAwardReason))
    local ModuleFilters = AddOn:ModuleSettings(LootHistory:GetName()).filters
    
    local display = true
    
    if Objects.In(response, "AUTOPASS", "PASS") or type(response) == "number" and not isAwardReason then
        
        display = ModuleFilters[response]
    else
        display = ModuleFilters["STATUS"]
    end
    
    return display
end

function LootHistory.FilterFunc(table, row)
    local entry = row.entry
    Logging:Trace("Applying Selection Filter(s)")
    local selectionFilter = SelectionFilter(entry.owner, entry.instance, entry.timestamp)
    
    -- determine if module filters need respected
    local moduleFilters = AddOn:ModuleSettings(LootHistory:GetName()).filters
    if not moduleFilters then return selectionFilter end
    
    Logging:Trace("Applying Class Filter(s)")
    local classFilter = ClassFilter(entry.class)
    
    Logging:Trace("Applying Response Filter(s)")
    local responseFilter = ResponseFilter(entry.responseId, entry:IsAwardReason())
    
    return selectionFilter and classFilter and responseFilter
end

function LootHistory:AddEntry(winner, entry)
    local history = self:GetHistory()
    local winnerHistory = history:get(winner)
    if winnerHistory then
        history:insert(entry:toTable(), winner)
    else
        history:put(winner, {entry:toTable()})
    end
    stats.stale = true
end

function LootHistory:CreateFromAward(award)
    -- if in test mode and not development mode, return
    if (AddOn:TestModeEnabled() and not AddOn:DevModeEnabled()) then return end
    if not award.item then error("Award has not associated item") end
    local C = AddOn.Constants
    
    --
    -- https://wow.gamepedia.com/API_GetInstanceInfo
    -- name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic,
    --  instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
    --
    local instanceName, _, _, _, _, _, _, instanceId, groupSize = GetInstanceInfo()
    
    local entry = Models.History.Loot()
    entry.item = award.item.link
    entry.owner = award.item.winner
    entry.class = award.item.class
    entry.instance = instanceName
    entry.mapId = instanceId
    entry.boss = AddOn.encounter.name
    entry.groupSize = groupSize
    entry.note = award.item.note
    entry.typeCode = award.item.typeCode
    local response = award.item:NormalizedResponse()
    entry.responseId = response.id
    entry.response = response.text
    entry.color = response.color
    entry:SetOrigin(award.item.reason and true or false)
    
    AddOn:SendMessage(C.Messages.LootHistorySend, entry, award)
    -- todo : support settings for sending and tracking history
    -- todo : send to guild or group? group for now
    AddOn:SendCommand(C.group, C.Commands.LootHistoryAdd, entry.owner, entry)
    return entry
end

function LootHistory:GetStatistics()
    Logging:Trace("GetStatistics()")
    local check, ret = pcall(
            function()
                if stats.stale or Objects.IsNil(stats.value) then
                    local s = Models.History.LootStatistics()
        
                    local c_pairs = CDB.static.pairs
                    for name, data in c_pairs(self:GetHistory()) do
                        for i = #data, 1, -1 do
                            s:ProcessEntry(name, data[i], i)
                        end
                    end
                    
                    stats.stale = false
                    stats.value = s
                end
                
                return stats.value
            end
    )
    
    if not check then
        Logging:Warn("Error processing Loot History")
        AddOn:Print("Error processing Loot History")
    else
        return ret
    end
end

