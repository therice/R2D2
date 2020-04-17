local _, AddOn = ...
local Points = AddOn:NewModule("Points", "AceHook-3.0", "AceEvent-3.0")
local Logging = AddOn.components.Logging
local L = AddOn.components.Locale
local UI = AddOn.components.UI
local ST = AddOn.Libs.ScrollingTable
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local GuildStorage = AddOn.Libs.GuildStorage
local Dialog = AddOn.Libs.Dialog
local Models = AddOn.components.Models
local Traffic = Models.History.Traffic
local Objects = Util.Objects
local Strings = Util.Strings
local Class = AddOn.Libs.Class

local ROW_HEIGHT, NUM_ROWS, MIN_UPDATE_INTERVAL = 20, 25, 5
local MenuFrame, FilterMenu
-- points : data table (guild member's and associated points), represented as PointEntry
-- pendingUpdate : has the data table been mutated since last displayed/refreshed
local points, pendingUpdate = {}, false

function Points:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    local C = AddOn.Constants
    -- https://www.wowace.com/projects/lib-st/pages/create-st
    -- these are the columns in the scrolling table for displaying standings
    self.scrollCols = {
        -- 1 Class
        {
            name         = "",
            width        = 20,
        },
        -- 2 Name
        {
            name         = _G.NAME,
            width        = 120,
            defaultsort  = ST.SORT_ASC,
            sortnext     = 1,
        },
        -- 3 Rank
        {
            name         = _G.RANK,
            width        = 120,
            defaultsort  = ST.SORT_ASC,
            sortnext     = 2,
            comparesort = function(table, rowa, rowb, sortbycol)
                return UI.Sort(
                        table, rowa, rowb, sortbycol,
                        function(row)
                            return row.entry.rankIndex
                        end
                )
            end
        },
        -- 4 EP
        {
            name         = L["ep_abbrev"],
            width        = 60,
            defaultsort  = ST.SORT_DSC,
            sortnext     = 5,
        },
        -- 5 GP
        {
            name         = L["gp_abbrev"],
            width        = 60,
            defaultsort  = ST.SORT_DSC,
            sortnext     = 3,
        },
        -- 6 PR
        {
            name         = L["pr_abbrev"],
            width        = 60,
            sort         = ST.SORT_DSC,
            sortnext     = 4,
        },
    }
    MenuFrame = MSA_DropDownMenu_Create(C.DropDowns.PointsRightClick, UIParent)
    FilterMenu = MSA_DropDownMenu_Create(C.DropDowns.PointsFilter, UIParent)
    MSA_DropDownMenu_Initialize(MenuFrame, self.RightClickMenu, "MENU")
    MSA_DropDownMenu_Initialize(FilterMenu, self.FilterMenu)
    -- register callbacks with LibGuildStorage for events in which we are interested
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildOfficerNoteChanged, "MemberModified")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.GuildMemberDeleted, "MemberDeleted")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.StateChanged, "DataChanged")
    GuildStorage.RegisterCallback(self, GuildStorage.Events.Initialized, "DataChanged")
end

function Points:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self.adjustFrame = self:GetAdjustFrame()
    self:BuildData()
    self.updateHandler = AddOn.CreateUpdateHandler(function() Points:Update() end, MIN_UPDATE_INTERVAL)
    self:Show()
end

function Points:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
end

function Points:EnableOnStartup()
    return false
end

function Points.Get(name)
    if points[name] then return points[name]:Get() end
end

function AddEntry(name, entry)
    points[name] = entry
    pendingUpdate = true
end

function RemoveEntry(name)
    points[name] = nil
    pendingUpdate = true
end

function GetEntry(name)
    return Points.GetEntry(name)
end

function Points.GetEntry(name)
    return points[name]
end

-- todo : need to handle addition and removal of members to scrolling table
-- this is currently only invoked as part of officer's note changing, nothing else
function Points:MemberModified(event, name, note)
    -- don't need to remove, it overwrites
    AddEntry(name, Models.PointEntry:FromGuildMember(GuildStorage:GetMember(name)))
    -- Logging:Debug("MemberModified(%s) : '%s'", name, note)
end

function Points:MemberDeleted(event, name)
    RemoveEntry(name)
    -- Logging:Debug("MemberDeleted(%s)", name)
end

-- todo : maybe it's better to just fire from individual events
function Points:DataChanged(event, state)
    -- Logging:Debug("DataChanged(%s) : %s, %s", event, tostring(state), tostring(pendingUpdate))
    -- will get this once everything settles
    -- individual events will have collected the appropriate point entries
    if event == GuildStorage.Events.Initialized then
        -- no-op for now
    elseif event == GuildStorage.Events.StateChanged then
        if state == GuildStorage.States.Current then
            self:Update()
        end
    end
end

function Points:Adjust(data)
    Logging:Debug("%s", Objects.ToString(data))
    local entry = AddOn:TrafficHistoryModule():CreateEntry(
            data.actionType,
            data.subjectType,
            data.subject,
            data.resourceType,
            data.quantity,
            data.description
    )
    Logging:Debug("%s", Objects.ToString(entry:toTable()))
end

function Points:Hide()
    if self.frame then
        self.frame.moreInfo:Hide()
        self.frame:Hide()
    end
    
    if self.adjustFrame then
        self.adjustFrame:Hide()
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

function Points:BuildData()
    self.frame.rows = {}
    local row = 1
    for name, entry in pairs(points) do
        if Objects.IsTable(entry) then
            self.frame.rows[row] = {
                name = name,
                entry = entry,
                num = row,
                cols = {
                    {value = entry.class, DoCellUpdate = AddOn.SetCellClassIcon, args = {entry.classTag}},
                    {value = AddOn.Ambiguate(name), color = AddOn.GetClassColor(entry.class)},
                    {value = entry.rank},
                    {value = entry.ep},
                    {value = entry.gp},
                    {value = entry:GetPR()},
                }
            }
            row = row +1
        end
    end
    
    self.frame.st:SetData(self.frame.rows)
    pendingUpdate = false
end

-- todo : fix this stupid functoin
function Points:Update(forceUpdate)
    Logging:Debug("Update(%s)", tostring(forceUpdate or false))
    -- if module isn't enabled, no need to perform update
    if not self:IsEnabled() then return end
    if not self.frame then return end
    -- execute the udpate if forced or pending update combined with state of update handler
    local performUpdate = forceUpdate or (pendingUpdate and (self.updateHandler and self.updateHandler:Eligible() or true))
    if not performUpdate then return end
    -- Logging:Debug("Update(%s) - Performing update", tostring(forceUpdate or false))
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
                                                           function(_) return data[realrow].entry.class end
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
                                                           function(_) return data[realrow].entry.class end
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
                                                       function(name)
                                                           local entry = GetEntry(name)
                                                           return entry and entry.class or ""
                                                       end
                                  )
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
    
    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("RIGHT", f.moreInfoBtn, "LEFT", -10, 0)
    close:SetScript("OnClick", function() self:Disable() end)
    f.closeBtn = close
    
    -- filter
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("RIGHT", f.closeBtn, "LEFT", -10, 0)
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
    
    local name = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("CENTER", f.content, "TOP", 0, -30)
    name:SetText("...")
    f.name = name
    
    local rtLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rtLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 15, -45)
    rtLabel:SetText(L["resource_type"])
    f.rtLabel = rtLabel
    
    f.subjectType = Traffic.SubjectType.Character
    
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
    
    local adjust = UI:CreateButton(L["adjust"], f.content)
    adjust:SetPoint("RIGHT", f.close, "LEFT", -25)
    adjust:SetScript("OnClick",
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
    f.adjust = adjust
    
    UI.EmbedErrorTooltip("Points", f)
    
    function f.Validate()
        local validationErrors = {}
        local data = {}
        
        local subject = f.name:GetText()
        if Util.Strings.IsEmpty(subject) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["name"]))
        else
            Util.Tables.Insert(data, 'subjectType', f.subjectType)
            if f.subjectType == Traffic.SubjectType.Character then
                Util.Tables.Insert(data, 'subject', subject)
            else
                -- don't include the subject to on creation they will be discovered
                -- Util.Tables.Insert(data, 'subject', {})
                Util.Tables.Insert(data, 'subjectOrigin', subject)
            end
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

function Points:UpdateAdjustFrame(subjectType, name, resource)
    if not self.adjustFrame then return end
    
    local c
    
    if subjectType == Traffic.SubjectType.Character then
        c = AddOn.GetClassColor(GetEntry(name).class)
    else
        c = AddOn.GetSubjectTypeColor(subjectType)
    end
    
    
    self.adjustFrame.subjectType = subjectType
    
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
    
    local decoratedText
    if data.subjectType == Traffic.SubjectType.Character then
        local c = AddOn.GetClassColor(GetEntry(data.subject).class)
        decoratedText = UI.ColoredDecorator(c.r, c.g, c.b):decorate(data.subject)
    else
        decoratedText = UI.ColoredDecorator(AddOn.GetSubjectTypeColor(data.subjectType)):decorate("the " .. data.subjectOrigin)
    end
    
    -- Are you certain you want to %s %d %s %s %s?
    frame.text:SetText(
            format(L["confirm_adjust_player_points"],
                   Traffic.TypeIdToAction[data.actionType]:lower(),
                   data.quantity,
                   Traffic.TypeIdToResource[data.resourceType]:upper(),
                   data.actionType == Traffic.ActionType.Add and "to" or "from",
                   decoratedText
            )
    )
end

function Points.AwardPopupOnClickYes(frame, data, callback, ...)
    Logging:Debug("AwardPopupOnClickYes() : %s, %s", Util.Objects.ToString(callback), Util.Objects.ToString(data, 3))
    Points:Adjust(data)
    if Points.adjustFrame then Points.adjustFrame:Hide() end
end

function Points.AwardPopupOnClickNo(frame, data)
    -- intentionally left blank
end


local AdjustLevel = Class('AdjustLevel')
local DynamicAdjustLevel = Class('DynamicAdjustLevel', AdjustLevel)
local StaticAdjustLevel = Class('StaticAdjustLevel', AdjustLevel)

---
--- Base Class for Adjust Menu Level
---
function AdjustLevel:initialize(category, text, subjectType)
    self.category = category
    self.text = text
    self.subjectType = subjectType
end

function AdjustLevel:SetText(text)
    self.text = text
end

function AdjustLevel:GetDisplayText()
    return self.txt
end

function AdjustLevel:ToMenuOption()
    return {
        value = function()
            return MSA_DROPDOWNMENU_MENU_VALUE .. "_" .. self.category
        end,
        text = function(name)
            self:SetText(name)
            return self:GetDisplayText()
        end,
        notCheckable = true,
        hasArrow = true,
    }
end

function AdjustLevel:ChildAction(type)
    Points:UpdateAdjustFrame(self.subjectType, self.text, type)
end

---
--- A Dynamic Adjust Menu Level
---
function DynamicAdjustLevel:initialize(category, subjectType)
    AdjustLevel.initialize(self, category, nil, subjectType)
end

function DynamicAdjustLevel:GetDisplayText()
    return AddOn:GetUnitClassColoredName(self.text)
end
---
--- A Static Adjust Menu Level
---
function StaticAdjustLevel:initialize(category, text, subjectType)
    AdjustLevel.initialize(self, category, text, subjectType)
end

function StaticAdjustLevel:GetDisplayText()
    return UI.ColoredDecorator(AddOn.GetSubjectTypeColor(self.subjectType)):decorate(self.text)
end
-- intentionally a no-op
function StaticAdjustLevel:SetText(text)  end

local SubjectAdjustLevel = DynamicAdjustLevel('SUBJECT', Traffic.SubjectType.Character)
local GuildAdjustLevel = StaticAdjustLevel('GUILD', _G.GUILD, Traffic.SubjectType.Guild)
local GroupAdjustLevel = StaticAdjustLevel('GROUP', _G.GROUP, Traffic.SubjectType.Raid)

local AdjustLevels = {
    [SubjectAdjustLevel.category] = SubjectAdjustLevel,
    [GuildAdjustLevel.category]   = GuildAdjustLevel,
    [GroupAdjustLevel.category]   = GroupAdjustLevel,
}

function GetAdjustLevel()
    local category = Strings.Split(MSA_DROPDOWNMENU_MENU_VALUE, "_")[2]
    return AdjustLevels[category]
end

Points.RightClickEntries = {
    -- level 1
    {
        -- 1 Adjust
        {
            text = "Adjust",
            notCheckable = true,
            hasArrow = true,
            value = "ADJUST"
        },
    },
    -- level 2
    {
        SubjectAdjustLevel:ToMenuOption(),
        GuildAdjustLevel:ToMenuOption(),
        GroupAdjustLevel:ToMenuOption(),
    },
    -- level 3
    {
         -- 1 EP
        {
            text = function()
                return UI.ColoredDecorator(AddOn.GetResourceTypeColor(Traffic.ResourceType.Ep)):decorate(L["ep_abbrev"])
            end,
            notCheckable = true,
            func = function(_)
                GetAdjustLevel():ChildAction(Traffic.ResourceType.Ep)
            end,
        },
        -- 2 GP
        {
            text = function()
                return UI.ColoredDecorator(AddOn.GetResourceTypeColor(Traffic.ResourceType.Gp)):decorate(L["gp_abbrev"])
            end,
            notCheckable = true,
            func = function(_)
                GetAdjustLevel():ChildAction(Traffic.ResourceType.Gp)
            end,
        },
        -- 3 Rescale
        -- 4 Decay
    }
}

Points.RightClickMenu = UI.RightClickMenu(
        function() return AddOn:DevModeEnabled() or CanEditOfficerNote() end,
        Points.RightClickEntries
)

function Points.FilterMenu(menu, level)
    local Module = AddOn.db.profile.modules[Points:GetName()]
    if level == 1 then
        if not Module.filters then Module.filters = {} end
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
    local member = GetEntry(name)
    
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