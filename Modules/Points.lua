local _, AddOn = ...
local Points        = AddOn:NewModule("Points", "AceHook-3.0", "AceEvent-3.0")
local Logging       = AddOn.components.Logging
local L             = AddOn.components.Locale
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util
local ItemUtil      = AddOn.Libs.ItemUtil
local GuildStorage  = AddOn.Libs.GuildStorage
local Dialog        = AddOn.Libs.Dialog
local Models        = AddOn.components.Models
local Traffic       = Models.History.Traffic

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 25, 10
local DefaultScrollTableData = {}
local Sort, Get
local MenuFrame, FilterMenu
local points = {}

function Points:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    -- https://www.wowace.com/projects/lib-st/pages/create-st
    -- these are the columns in the scrolling table for displaying standings
    DefaultScrollTableData = {
        -- 1 Class
        {
            name         = "",
            DoCellUpdate = UI.ScrollingTableDoCellUpdate(Points.SetCellClass),
            colName      = "class",
            width        = 20,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return Get(row.name).class
                            end
                )
            end,
        },
        -- 2 Name
        {
            name         = _G.NAME,
            DoCellUpdate =  UI.ScrollingTableDoCellUpdate(Points.SetCellName),
            colName      = "name",
            width        = 120,
            defaultsort  = ST.SORT_ASC,
            sortnext     = 1,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return AddOn.Ambiguate(row.name)
                            end
                )
            end,
        },
        -- 3 Rank
        {
            name         = _G.RANK,
            DoCellUpdate = UI.ScrollingTableDoCellUpdate(Points.SetCellRank),
            colName      = "name",
            width        = 120,
            defaultsort  = ST.SORT_ASC,
            sortnext     = 2,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return Get(row.name).rankIndex
                            end
                )
            end,
        },
        -- 4 EP
        {
            name         = L["ep_abbrev"],
            DoCellUpdate = UI.ScrollingTableDoCellUpdate(Points.SetCellEp),
            colName      = "ep",
            width        = 60,
            defaultsort  = ST.SORT_DSC,
            sortnext     = 5,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return Get(row.name).ep
                            end
                )
            end,
        },
        -- 5 GP
        {
            name         = L["gp_abbrev"],
            DoCellUpdate = UI.ScrollingTableDoCellUpdate(Points.SetCellGp),
            colName      = "gp",
            width        = 60,
            defaultsort  = ST.SORT_DSC,
            sortnext     = 3,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return Get(row.name).gp
                            end
                )
            end,
        },
        -- 6 PR
        {
            name         = L["pr_abbrev"],
            DoCellUpdate = UI.ScrollingTableDoCellUpdate(Points.SetCellPr),
            colName      = "pr",
            width        = 60,
            sort         = ST.SORT_DSC,
            sortnext     = 4,
            comparesort  = function(table, rowa, rowb, sortbycol)
                return Sort(table, rowa, rowb, sortbycol,
                            function(row)
                                return Get(row.name):GetPR()
                            end
                )
            end,
        },
    }
    self.scrollCols = { unpack(DefaultScrollTableData) }
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.AllocateRightClick, UIParent)
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.AllocateFilter, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
end

function Points:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self.adjustFrame = self:GetAdjustFrame()
    self.updateHandler = AddOn.CreateUpdateHandler(function() Points:Update() end, MIN_UPDATE_INTERVAL)
    -- register callbacks with LibGuildStorage for events in which we are interested
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildOfficerNoteChanged, "MemberModified")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildMemberDeleted, "MemberDeleted")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.StateChanged, "DataChanged")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.Initialized, "DataChanged")
end

function Points:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:SetParent(nil)
    self.frame = nil
    self.adjustFrame:SetParent(nil)
    self.adjustFrame = nul
    self.updateHandler:Dispose()
end


function Points.Get(name)
    if points[name] then return points[name]:Get() end
end

function Add(name, entry)
    points[name] = entry
end

function Remove(name)
    points[name] = nil
end

function Get(name)
    return points[name]
end

-- todo : need to handle addition and removal of members to scrolling table

function Points:MemberModified(event, name, note)
    -- don't need to remove, it overwrites
    Add(name, Models.PointEntry:FromGuildMember(GuildStorage:GetMember(name)))
    Logging:Trace("MemberModified(%s) : '%s'", name, note)
end

function Points:MemberDeleted(event, name)
    Remove(name)
    Logging:Trace("MemberDeleted(%s)", name)
end

-- todo : maybe it's better to just fire from individual events
function Points:DataChanged(event, state)
    Logging:Trace("DataChanged(%s) : %s", event, tostring(state))
    -- will get this once everything settles
    -- individual events will have collected the appropriate point entries
    if event == GuildStorage.Events.Initialized then
        Points:BuildScrollingTable()
    elseif event == GuildStorage.Events.StateChanged then
        if state == GuildStorage.States.Current then
            self:Update()
        end
    end
end

function Points:Hide()
    if self.frame then
        self.frame.moreInfo:Hide()
        self.frame:Hide()
    end
end

function Points:Show()
    if self.frame then
        self.frame:Show()
    end
end

function Points:Toggle()
    if self.frame then
        if self.frame:IsVisible() then
            self:Hide()
        else
            self:Show()
        end
    end
end

function Points:BuildScrollingTable()
    local rows = {}
    local i = 1
    for name in pairs(points) do
        local data = {}
        
        for num, col in ipairs(self.scrollCols) do
            data[num] = {value = "", colName = col.colName}
        end
        
        rows[i] = {
            name = name,
            cols = data,
        }
        i = i + 1
    end
    
    self.frame.st:SetData(rows)
end

function Points:Update(forceUpdate)
    Logging:Trace("Update(%s)", tostring(forceUpdate or false))
    if not forceUpdate and not self.updateHandler:Eligible() then return end
    if not self.frame then return end
    Logging:Trace("Update(%s) - Performing update", tostring(forceUpdate or false))
    
    -- todo : need to fix this, as the constant callbacks are resulting in "jumping" rows
    -- self.frame.st:Refresh()
    self.frame.st:SortData()
    self.updateHandler:RefreshInterval()
end

function Points:GetFrame()
    if self.frame then return self.frame end
    
    local f =  UI:CreateFrame("R2D2_Standings", "Points", L["r2d2_standings_frame"], 350, 600)
    function f.UpdateScrollingTable()
        if f.st then
            f.st:Hide()
            f.st = nil
        end
        local st = ST:CreateST(self.scrollCols, NUM_ROWS, ROW_HEIGHT, { ["r"] = 1.0, ["g"] = 0.9, ["b"] = 0.0, ["a"] = 0.5 }, f.content)
        st.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
        st:RegisterEvents({
                              ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  -- show the menu
                                  if button == "RightButton" and row then
                                      MenuFrame.name = data[realrow].name
                                      MSA_ToggleDropDownMenu(1, nil, MenuFrame, cellFrame, 0, 0);
                                  -- update more info
                                  elseif button == "LeftButton" and row then
                                      AddOn.UpdateMoreInfo(self:GetName(), f, realrow, data,
                                                           function(name) return Get(name).class end
                                      )
                                  end
                                  -- Return false to have the default OnClick handler take care of left clicks
                                  return false
                              end,
                          })
        -- show moreInfo on mouseover
        st:RegisterEvents({
                              ["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if row then
                                      AddOn.UpdateMoreInfo(self:GetName(), f, realrow, data,
                                                           function(name) return Get(name).class end
                                      )
                                  end
                                  -- Return false to have the default OnEnter handler take care mouseover
                                  return false
                              end
                          })
        -- return to the actual selected player when we remove the mouse
        st:RegisterEvents({
                              ["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  AddOn.UpdateMoreInfo(self:GetName(), f, nil, nil,
                                                       function(name) return Get(name).class end)
                                  return false
                              end
                          })
    
        st:SetFilter(Points.FilterFunc)
        st:EnableSelection(true)
        f.st = st
        f:SetWidth(f.st.frame:GetWidth() + 20)
    end
    f.UpdateScrollingTable()
    
    -- more info widgets
    AddOn.EmbedMoreInfoWidgets(self:GetName(), f)
    
    -- filter
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -20)
    filter:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    filter:SetScript("OnEnter", function() UI:CreateTooltip(L["deselect_responses"]) end)
    filter:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.filter = filter
    
    return f
end

function Points:GetAdjustFrame()
    if self.adjustFrame then return self.adjustFrame end
    
    local f = UI:CreateFrame("R2D2_Adjust_Points", "AdjustPoints", L["r2d2_adjust_points_frame"], 150, 275)
    f:SetWidth(225)
    f:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -150)
    f.title:SetPoint("CENTER", f, "TOP", 0 ,-5)
    
    local name = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("CENTER", f.content, "TOP", 0, -30)
    name:SetText("...")
    f.name = name
    
    local rtLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rtLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 15, -45)
    rtLabel:SetText(L["resource_type"])
    f.rtLabel = rtLabel
    
    local resourceType =
        UI('Dropdown')
            .SetPoint("CENTER", f.name, "BOTTOM", 0, -35)
            .SetParent(f)()
    local values = {}
    for k, v in pairs(Traffic.TypeIdToResource) do
        values[k] = v:upper()
    end
    resourceType:SetList(values)
    f.resourceType = resourceType
    
    local atLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    atLabel:SetPoint("TOPLEFT", f.rtLabel, "TOPLEFT", 0, -45)
    atLabel:SetText(L["action_type"])
    f.atLabel = atLabel
    
    local actionType =
        UI('Dropdown')
            .SetPoint("TOPLEFT", f.resourceType.frame, "BOTTOMLEFT", 0, -20)
            .SetParent(f)()
    values = {}
    for k, v in pairs(Traffic.TypeIdToAction) do
        values[k] = v
    end
    actionType:SetList(values)
    f.actionType = actionType
    
    local qtyLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyLabel:SetPoint("TOPLEFT", f.atLabel, "TOPLEFT", 0, -45)
    qtyLabel:SetText(L["quantity"])
    f.qtyLabel = qtyLabel
    
    local quantity = UI:New("EditBox", f.content)
    quantity:SetHeight(25)
    quantity:SetWidth(100)
    quantity:SetPoint("TOPLEFT", f.actionType.frame , "BOTTOMLEFT", 3, -23)
    quantity:SetPoint("TOPRIGHT", f.actionType.frame , "TOPRIGHT", -6, 0)
    quantity:SetNumeric(true)
    quantity:SetScript("OnTabPressed",
                       function()
                           if IsShiftKeyDown() then
                           else
                               f.desc:SetFocus()
                           end
                       end
    )
    f.quantity = quantity
    
    local descLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", f.qtyLabel, "TOPLEFT", 0, -48)
    descLabel:SetText(L["description"])
    f.descLabel = descLabel

    local desc = UI:New("EditBox", f.content)
    desc:SetHeight(25)
    desc:SetWidth(100)
    desc:SetPoint("TOPLEFT", f.quantity, "BOTTOMLEFT", 0, -23)
    desc:SetPoint("TOPRIGHT", f.quantity, "TOPRIGHT",  0, 0)
    desc:SetScript("OnTabPressed", function()
        if IsShiftKeyDown() then
            f.quantity:SetFocus()
        else
        
        end
    end)
    f.desc = desc
    
    local close = UI:CreateButton(_G.CANCEL, f.content)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -13, 5)
    close:SetScript("OnClick",
                    function()
                        f.errorTooltip:Hide()
                        f:Hide()
                    end)
    f.close = close
    
    local apply = UI:CreateButton(L["adjust"], f.content)
    apply:SetPoint("RIGHT", f.close, "LEFT", -25)
    apply:SetScript("OnClick",
                    function()
                        local data, validationErrors = f.Validate()
                        if Util.Tables.Count(validationErrors) ~= 0 then
                            UI.UpdateErrorTooltip(f, validationErrors)
                        else
                            f.errorTooltip:Hide()
                            Dialog:Spawn(AddOn.Constants.Popups.ConfirmAdjustPoints, data)
                        end
                    end
    )
    f.clear = apply
    
    UI.EmbedErrorTooltip("Points", f)
    
    function f.Validate()
        local validationErrors = {}
        local data = {}
        
        local subject = f.name:GetText()
        if Util.Strings.IsEmpty(subject) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["name"]))
        else
            Util.Tables.Insert(data, 'subject', subject)
        end
        
        local actionType = f.actionType:GetValue()
        if Util.Objects.IsEmpty(actionType) or not Util.Objects.IsNumber(actionType) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["action_type"]))
        else
            Util.Tables.Insert(data, 'actionType', tonumber(actionType))
        end
    
        local resourceType = f.resourceType:GetValue()
        if Util.Objects.IsEmpty(resourceType) or not Util.Objects.IsNumber(resourceType) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["resource_type"]))
        else
            Util.Tables.Insert(data, 'resourceType', tonumber(resourceType))
        end
        
        local quantity = f.quantity:GetText()
        if Util.Objects.IsEmpty(quantity) or not Util.Strings.IsNumber(quantity) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["quantity"]))
        else
            Util.Tables.Insert(data, 'quantity', tonumber(quantity))
        end
        
        local description = f.desc:GetText()
        if Util.Strings.IsEmpty(description) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["description"]))
        else
            Util.Tables.Insert(data, 'description', description)
        end
        
        return data, validationErrors
    end
    
    self.adjustFrame = f
    return self.adjustFrame
end

function Points:UpdateAdjustFrame(name, resource)
    if not self.adjustFrame then return end
    
    local char = Get(name)
    local c = (AddOn.GetClassColor(char.class))
    
    --self.adjustFrame.name:SetText(AddOn.Ambiguate(name))
    self.adjustFrame.name:SetText(name)
    self.adjustFrame.name:SetTextColor(c.r, c.g, c.b, c.a)
    
    self.adjustFrame.resourceType:SetValue(resource)
    self.adjustFrame.resourceType:SetText(Traffic.TypeIdToResource[resource]:upper())
    
    self.adjustFrame.actionType:SetValue(nil)
    self.adjustFrame.actionType:SetText(nil)
    
    self.adjustFrame.quantity:SetText('')
    self.adjustFrame.desc:SetText('')
    
    if not self.adjustFrame:IsVisible() then self.adjustFrame:Show() end
end


function Points.AdjustPointsOnShow(frame, data)
    UI.DecoratePopup(frame)
    
    local char = Get(data.subject)
    local c = (AddOn.GetClassColor(char.class))
    local classDeco = UI.ColoredDecorator(c.r, c.g, c.b)
    -- Are you certain you want to %s %d %s %s %s?
    frame.text:SetText(
            format(L["confirm_adjust_player_points"],
                   Traffic.TypeIdToAction[data.actionType]:lower(),
                   data.quantity,
                   Traffic.TypeIdToResource[data.resourceType]:upper(),
                   data.actionType == Traffic.ActionType.Add and "to" or "from",
                   classDeco:decorate(data.subject)
            )
    )
end

Points.RightClickEntries = {
    -- level 1
    {
        -- 1 Title, player name
        {
            text = function(name) return AddOn.Ambiguate(name) end,
            isTitle = true,
            notCheckable = true,
            disabled = true,
        },
        -- 2 Spacer
        {
            text = "",
            notCheckable = true,
            disabled = true,
        },
        -- 3 Adjust EP
        {
            text = L["adjust_ep"],
            notCheckable = true,
            func = function(name)
                Points:UpdateAdjustFrame(name, Traffic.ResourceType.Ep)
            end,
        },
        -- 4 Adjust GP
        {
            text = L["adjust_gp"],
            notCheckable = true,
            func = function(name)
                Points:UpdateAdjustFrame(name, Traffic.ResourceType.Gp)
            end,
        },
    }
}

Points.RightClickMenu = UI.RightClickMenu(
        function() return AddOn:DevModeEnabled() or CanEditOfficerNote() end,
        Points.RightClickEntries
)

function Points.FilterMenu(menu, level)
    local Module = AddOn.db.profile.modules[Points:GetName()]
    if level == 1 then
        if not Module.filters then
            Module.filters = {}
        end
        local ModuleFilters = Module.filters
        
        local info = MSA_DropDownMenu_CreateInfo()
        info.text = _G.CLASS
        info.isTitle = true
        info.notCheckable = true
        info.disabled = true
        MSA_DropDownMenu_AddButton(info, level)
        
        -- these will be a table of sorted display class names
        local data = Util(ItemUtil.ClassDisplayNameToId):Keys()
                        :Filter(AddOn.FilterClassesByFactionFn):Sort():Copy()()
        
        info = MSA_DropDownMenu_CreateInfo()
        for _, class in pairs(data) do
            info.text = class
            info.colorCode = "|cff" .. AddOn.GetClassColorRGB(class)
            info.keepShownOnClick = true
            info.func = function()
                ModuleFilters.class[class] = not ModuleFilters.class[class]
                Points:Update(true)
            end
            info.checked = ModuleFilters.class[class]
            MSA_DropDownMenu_AddButton(info, level)
        end
    
        info = MSA_DropDownMenu_CreateInfo()
        info.text = L["member_of"]
        info.isTitle = true
        info.notCheckable = true
        info.disabled = true
        MSA_DropDownMenu_AddButton(info, level)
    
        info = MSA_DropDownMenu_CreateInfo()
        -- including GUILD doesn't make sense here, displayed rows are implicitly in the guild
        for _, what in pairs{_G.PARTY, _G.RAID} do
            info.text = what
            info.keepShownOnClick = true
            info.func = function()
                ModuleFilters.member_of[what] = not ModuleFilters.member_of[what]
                Points:Update(true)
            end
            info.checked = ModuleFilters.member_of[what]
            MSA_DropDownMenu_AddButton(info, level)
        end
    end
end

function Points.FilterFunc(table, row)
    local Module = AddOn.db.profile.modules[Points:GetName()]
    if not Module.filters then return true end
    
    local ModuleFilters = Module.filters
    local name = row.name
    local member = Get(name)
    
    -- Logging:Debug("FilterFunc : %s", Util.Objects.ToString(ModuleFilters))
    
    local include = true
    
    -- filtering based upon class
    if member and member.class then
        if Util.Tables.ContainsKey(ModuleFilters.class, member.class) then
            include = ModuleFilters.class[member.class]
        end
    end
    
    if include then
        for _, check in pairs({_G.PARTY, _G.RAID}) do
            local memberShortName = Ambiguate(name, "short")
            local playerCheck = not Util.Objects.IsNil(check == _G.PARTY and UnitInParty("player") or UnitInRaid("player"))
            local memberCheck = not Util.Objects.IsNil(check == _G.PARTY and UnitInParty(memberShortName) or UnitInRaid(memberShortName))
            -- Logging:Debug("%s : %s, %s", memberShortName, tostring(playerCheck), tostring(memberCheck))
            
            if playerCheck then
                include = memberCheck and ModuleFilters.member_of[check] or not ModuleFilters.member_of[check]
            else
                include = not memberCheck and not ModuleFilters.member_of[check] or ModuleFilters.member_of[check]
            end
            
            -- short-circuit if we found a false evaluation
            if not include then break end
        end
    end
    
    return include
end

function Points.SetCellClass(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    AddOn.SetCellClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, Get(name).classTag)
    data[realrow].cols[column].value = Get(name).class or ""
end

function Points.SetCellName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local c = AddOn.GetClassColor(Get(name).class)
    cellFrame.text:SetText(AddOn.Ambiguate(name))
    cellFrame.text:SetTextColor(c.r, c.g, c.b, c.a)
    data[realrow].cols[column].value = name or ""
end

function Points.SetCellRank(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local rank =  Get(name).rank
    cellFrame.text:SetText(rank)
    data[realrow].cols[column].value = rank or ""
end

function Points.SetCellEp(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local ep = Get(name).ep
    cellFrame.text:SetText(ep)
    data[realrow].cols[column].value = ep or 0
end

function Points.SetCellGp(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local gp = Get(name).gp
    cellFrame.text:SetText(gp)
    data[realrow].cols[column].value = gp or 0
end

function Points.SetCellPr(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local pr = Get(name):GetPR()
    cellFrame.text:SetText(pr)
    data[realrow].cols[column].value = pr or 0
end

function Points.AfterCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local rowdata = table:GetRow(realrow)
    local celldata = table:GetCell(rowdata, column)
    
    local highlight = nil
    if type(celldata) == "table" then
        highlight = celldata.highlight
    end
    
    if table.fSelect then
        if table.selected == realrow then
            table:SetHighLightColor(rowFrame, highlight or cols[column].highlight or rowdata.highlight or table:GetDefaultHighlight())
        else
            table:SetHighLightColor(rowFrame, table:GetDefaultHighlightBlank())
        end
    end
end

function Sort(table, rowa, rowb, sortbycol, valueFn)
    local column = table.cols[sortbycol]
    local row1, row2 = table:GetRow(rowa), table:GetRow(rowb)
    local v1, v2 = valueFn(row1), valueFn(row2)
    
    if v1 == v2 then
        if column.sortnext then
            local nextcol = table.cols[column.sortnext]
            if nextcol and not(nextcol.sort) then
                if nextcol.comparesort then
                    return nextcol.comparesort(table, rowa, rowb, column.sortnext)
                else
                    return table:CompareSort(rowa, rowb, column.sortnext)
                end
            else
                return false
            end
        else
            return false
        end
    else
        local direction = column.sort or column.defaultsort or ST.SORT_DSC
        if direction == ST.SORT_ASC then
            return v1 < v2
        else
            return v1 > v2
        end
    end
end
