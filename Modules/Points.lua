local _, AddOn = ...
local Points        = AddOn:NewModule("Points", "AceHook-3.0", "AceEvent-3.0")
local Logging       = AddOn.components.Logging
local L             = AddOn.components.Locale
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util
local GuildStorage  = AddOn.Libs.GuildStorage
local Models        = AddOn.components.Models

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 25, 0.2
local DefaultScrollTableData = {}
local MemberModified, MemberDeleted, DataChanged, Sort, Get
local FilterMenu
local points, updatePending, updateIntervalRemaining, updateFrame = {}, false, 0, CreateFrame("FRAME")

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
    updateFrame:Show()
    updatePending = false
    updateIntervalRemaining = 0
    -- register callbacks with LibGuildStorage for events in which we are interested
    GuildStorage:RegisterCallback(GuildStorage.Events.GuildNoteChanged, MemberModified)
    GuildStorage:RegisterCallback(GuildStorage.Events.GuildMemberDeleted, MemberDeleted)
    GuildStorage:RegisterCallback(GuildStorage.Events.StateChanged, DataChanged)
end

function Points:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:SetParent(nil)
    self.frame = nil
    updateFrame:Hide()
    updatePending = false
    updateIntervalRemaining = 0
end

function Points:Hide()
    if self.frame then
        self.frame.moreInfo:Hide()
        self.frame:Hide()
    end
end

function Points:Show()
    if self.frame then
        
        --for i in ipairs(self.frame.st.cols) do
        --    self.frame.st.cols[i].sort = nil
        --end
        --self.frame.st.cols[1].sort = 5
        --
        -- FauxScrollFrame_OnVerticalScroll(self.frame.st.scrollframe, 0, self.frame.st.rowHeight, function() self.frame.st:Refresh() end)
        --Points:Update(true)
        --self.frame.st:SortData()
        Points:BuildScrollingTable()
        --self.frame.st:Refresh()
        self.frame.st:SortData()
        --self.frame.st:SortData()
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

function MemberModified(callback, name, note)
    Remove(name)
    Add(name, Models.PointEntry:FromGuildMember(GuildStorage:GetMember(name)))
    Logging:Trace("MemberModified(%s) : %s ", name, Util.Objects.ToString(points[name], 1))
    -- todo : maintain standings?
end

function MemberDeleted(callback, name)
    Remove(name)
    Logging:Trace("MemberDeleted(%s)", name)
    -- todo : maintain standings?
end

-- todo : maybe it's better to just fire from individual events
function DataChanged(callback, state)
    -- will get this once everything settles
    -- individual events will have collected the appropraite point entries
    if state == GuildStorage.States.Current then
    
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
    
    --Logging:Debug('%s', Util.Objects.ToString(rows, 4))
    self.frame.st:SetData(rows)
end

--function Points:Update(forceUpdate)
--    updatePending = false
--    if not forceUpdate and updateIntervalRemaining > 0 then
--        updatePending = true
--        return
--    end
--
--    if not self.frame then return end
--
--    updateIntervalRemaining = MIN_UPDATE_INTERVAL
--    self.frame.st:SortData()
--    self.frame.st:SortData()
--
--end
--
--updateFrame:SetScript("OnUpdate", function(self, elapsed)
--    if updateIntervalRemaining > elapsed then
--        updateIntervalRemaining = updateIntervalRemaining - elapsed
--    else
--        updateIntervalRemaining = 0
--    end
--    if updatePending and updateIntervalRemaining <= 0 then
--        Points:Update()
--    end
--end)

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
                                      AddOn:UpdateMoreInfo(self:GetName(), f, realrow, data)
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
                                  if row then AddOn:UpdateMoreInfo(self:GetName(), f, realrow, data) end
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
        
        st:EnableSelection(true)
        f.st = st
        f:SetWidth(f.st.frame:GetWidth() + 20)
    end
    f.UpdateScrollingTable()
    
    -- more info widgets
    AddOn:EmbedMoreInfoWidgets(self:GetName(), f)
    
    return f
end

function Points.FilterMenu(menu, level)

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
