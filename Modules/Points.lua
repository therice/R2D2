local _, AddOn = ...
local Points        = AddOn:NewModule("Points", "AceHook-3.0", "AceEvent-3.0")
local Logging       = AddOn.components.Logging
local L             = AddOn.components.Locale
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util
local ItemUtil      = AddOn.Libs.ItemUtil
local GuildStorage  = AddOn.Libs.GuildStorage
local Models        = AddOn.components.Models

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 25, 10
local DefaultScrollTableData = {}
local Sort, Get
local FilterMenu
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
            DoCellUpdate = Points.SetCellClass,
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
            DoCellUpdate = Points.SetCellName,
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
            DoCellUpdate = Points.SetCellRank,
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
            DoCellUpdate = Points.SetCellEp,
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
            DoCellUpdate = Points.SetCellGp,
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
            DoCellUpdate = Points.SetCellPr,
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
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.AllocateFilter, UIParent)
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
end

function Points:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self.updateHandler = AddOn:CreateUpdateHandler(function() Points:Update() end, MIN_UPDATE_INTERVAL)
    -- register callbacks with LibGuildStorage for events in which we are interested
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildNoteChanged, "MemberModified")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildMemberDeleted, "MemberDeleted")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.StateChanged, "DataChanged")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.Initialized, "DataChanged")
end

function Points:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:SetParent(nil)
    self.frame = nil
    self.updateHandler:Dispose()
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

-- @return ep, gp, pr
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
    Remove(name)
    Add(name, Models.PointEntry:FromGuildMember(GuildStorage:GetMember(name)))
    Logging:Trace("MemberModified(%s) : '%s'", name, note)
    -- todo : maintain standings?
end

function Points:MemberDeleted(event, name)
    Remove(name)
    Logging:Trace("MemberDeleted(%s)", name)
    -- todo : maintain standings?
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
    
    -- todo : not sure if refresh() is needed
    self.frame.st:Refresh()
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
                                      --MenuFrame.name = data[realrow].name
                                      -- MSA_ToggleDropDownMenu(1, nil, MenuFrame, cellFrame, 0, 0);
                                  -- update more info
                                  elseif button == "LeftButton" and row then
                                      AddOn:UpdateMoreInfo(self:GetName(), f, realrow, data,
                                                           function(name) return Get(name).class end
                                      )
                                      --if IsAltKeyDown() then
                                      --    local name = data[realrow].name
                                      --    Dialog:Spawn(AddOn.Constants.Popups.ConfirmAward,
                                      --                 self:GetAwardPopupData(session, name))
                                      --end
                                  end
                                  -- Return false to have the default OnClick handler take care of left clicks
                                  return false
                              end,
                          })
        -- show moreInfo on mouseover
        st:RegisterEvents({
                              ["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
                                  if row then
                                      AddOn:UpdateMoreInfo(self:GetName(), f, realrow, data,
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
                                  AddOn:UpdateMoreInfo(self:GetName(), f)
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
    AddOn:EmbedMoreInfoWidgets(self:GetName(), f)
    
    -- filter
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -20)
    filter:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    filter:SetScript("OnEnter", function() UI:CreateTooltip(L["deselect_responses"]) end)
    filter:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.filter = filter
    
    return f
end

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
        
        local data = Util(ItemUtil.ClassDisplayNameToId):Keys()
                -- todo : make this a reuable function
                :Filter(
                    function(class)
                        if AddOn.playerFaction == 'Alliance' then
                            return class ~= "Shaman"
                        elseif AddOn.playerFaction == 'Horde' then
                            return class ~= "Paladin"
                        end
                        return true
                    end
                ):Sort():Copy()()
        
        info = MSA_DropDownMenu_CreateInfo()
        for _, class in pairs(data) do
            info.text = class
            info.colorCode = "|cff" .. AddOn:GetClassColorRGB(class)
            info.keepShownOnClick = true
            info.func = function()
                ModuleFilters[class] = not ModuleFilters[class]
                Points:Update(true)
            end
            info.checked = ModuleFilters[class]
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
    if member and member.class then
        local classDisplayName = ItemUtil.ClassIdToDisplayName[ItemUtil.ClassTagNameToId[member.class]]
        local display = true
        if Util.Tables.ContainsKey(ModuleFilters, classDisplayName) then
            display = ModuleFilters[classDisplayName]
        end
        
        -- Logging:Debug("%s %s %s %s", name, classDisplayName, tostring(display), tostring(ModuleFilters[classDisplayName]))
        return display
    end
end

function Points.SetCellClass(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    AddOn.SetCellClassIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, Get(name).class)
    data[realrow].cols[column].value = Get(name).class or ""
    -- Logging:Debug("Set row=%s col=%s to %s", tostring(realrow), tostring(column),  Get(name).class or "")
end

function Points.SetCellName(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    local name = data[realrow].name
    local c = AddOn:GetClassColor(Get(name).class)
    cellFrame.text:SetText(AddOn.Ambiguate(name))
    cellFrame.text:SetTextColor(c.r, c.g, c.b, c.a)
    data[realrow].cols[column].value = name or ""
    -- Logging:Debug("Set row=%s col=%s to %s", tostring(realrow), tostring(column), name or "")
    -- Logging:Debug("Cols %s", Util.Objects.ToString(rowFrame, 3))
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
