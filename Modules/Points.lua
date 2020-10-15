local _, AddOn = ...
local Points = AddOn:NewModule("Points", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")
local Logging = AddOn.components.Logging
local L = AddOn.components.Locale
local UI = AddOn.components.UI
local ST = AddOn.Libs.ScrollingTable
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local GuildStorage = AddOn.Libs.GuildStorage
local Dialog = AddOn.Libs.Dialog
local Models = AddOn.components.Models
local Award = Models.Award
local Objects = Util.Objects
local Strings = Util.Strings
local Class = AddOn.Libs.Class
local Date = Models.Date
local DateFormat = Models.DateFormat

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
    self.updateHandler = AddOn.CreateUpdateHandler(function() Points:Update() end, MIN_UPDATE_INTERVAL)
end

function Points:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    self.frame = self:GetFrame()
    self.adjustFrame = self:GetAdjustFrame()
    self.decayFrame = self:GetDecayFrame()
    self:BuildData()
    self.updateHandler:Start()
    self:Show()
end

function Points:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:Hide()
    self.updateHandler:Stop()
end

function Points:EnableOnStartup()
    return false
end

function Points.Get(name)
    if points[name] then return points[name]:Get() end
end

local function AddEntry(name, entry)
    points[name] = entry
    pendingUpdate = true
end

local function RemoveEntry(name)
    points[name] = nil
    pendingUpdate = true
end

local function GetEntry(name)
    return Points.GetEntry(name)
end

function Points.GetEntry(name)
    return points[name]
end

-- todo : need to handle addition and removal of members to scrolling table
-- this is currently only invoked as part of officer's note changing, nothing else
function Points:MemberModified(event, name, note)
    -- don't need to remove, it overwrites
    -- name with be character-realm
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

function Points:RevertAdjust(entry)
    if entry.subjectType ~= Award.SubjectType.Character then
        error("Unsupported subject type for reverting an award : " .. Award.TypeIdToSubject[entry.subjectType])
    end
    
    if not Objects.In(entry.actionType, Award.ActionType.Add, Award.ActionType.Subtract) then
        error("Unsupported resource type for reverting an award : " .. Award.TypeIdToAction[entry.actionType])
    end
    
    local award = Award(entry)
    if award.actionType == Award.ActionType.Add then
        award.actionType = Award.ActionType.Subtract
    elseif award.actionType == Award.ActionType.Subtract then
        award.actionType = Award.ActionType.Add
    end
    
    -- nil out item, this is a revert so no associated loot history record
    award.item = nil
    award.description = "Revert '" .. entry.description .. "'"
    
    Points:Adjust(award)
end

function Points:Adjust(award)
    
    if not GuildStorage:IsStateCurrent() then
        Logging:Debug("Adjust() : GuildStorage state is not current, scheduling for near future and returning")
        return self:ScheduleTimer("Adjust", 1, award)
    else
        Logging:Trace("Adjust() : GuildStorage state is current, proceeding")
    end
    
    -- local function for forming operation on target
    local function apply(target, action, type, amount)
        -- if a subtract operation flip sign on amount (they are always in positive values)
        if action == Award.ActionType.Subtract then amount = -amount end
        -- if a reset, set flat value based upon resource type
        if action == Award.ActionType.Reset then
            amount = type == Award.ResourceType.Gp and AddOn:GearPointsModule().db.profile.gp_min or 0
        end
        
        local function add(to, amt) return to + amt end
        local function reset(_, _) return amount end
        local function decay(amt, by)
            -- Logging:Debug("%d - math.floor(%d * %s) = %d", amt, amt, tostring(by), (amt - math.floor(amt * by)))
            return Util.Numbers.Round(amt - (amt * by))
        end
        
        local oper =
                action == Award.ActionType.Add and add or
                action == Award.ActionType.Subtract and add or
                action == Award.ActionType.Reset and reset or
                action == Award.ActionType.Decay and decay or
                nil -- intentional to find missing cases
            
        local function ep(amt) target.ep = oper(target.ep, amt) end
        local function gp(amt) target.gp = oper(target.gp, amt) end
        local targetFn =
                type == Award.ResourceType.Ep and ep or
                type == Award.ResourceType.Gp and gp or
                nil -- intentional to find missing cases
        
        targetFn(amount)
    end
    
    -- todo : if we want to record history entries after point adjustment then needs to be refactored to grab 'before' quantity
    -- todo : could pass in the actual update to be performed before sending
    
    -- if the award is for GP and there is an associated item that was awarded, create it first
    local lhEntry
    if award.resourceType == Award.ResourceType.Gp and award.item then
        lhEntry = AddOn:LootHistoryModule():CreateFromAward(award)
    end
    
    -- just one traffic history entry per award, regardless of number of subjects
    -- to which it applied
    AddOn:TrafficHistoryModule():CreateFromAward(award, lhEntry)
    
    -- subject is a tuple of (name, class)
    for _, subject in pairs(award.subjects) do
        local target = GetEntry(subject[1])
        if target then
            -- Logging:Debug("Adjust() : Processing %s", Objects.ToString(target:toTable()))
            apply(target, award.actionType, award.resourceType, award.resourceQuantity)
            -- don't apply to actual officer notes in test mode
            -- it will also fail if we cannot edit officer notes
            if (not AddOn:TestModeEnabled() and AddOn:PersistenceModeEnabled()) and CanEditOfficerNote() then
                -- todo : we probably need to see if this is successful, otherwise could be lost
                GuildStorage:SetOfficeNote(target.name, target:ToNote())
            else
                Logging:Debug("Points:Adjust() : Skipping adjustment of EPGP for '%s'", target.name)
            end
        else
            Logging:Warn("Could not locate %s for applying %s. Possibly not in guild?",  Objects.ToString(subject), Objects.ToString(award:toTable()))
        end
    end

    -- announce what was done
    local check, _ = pcall(function() AddOn:SendAnnouncement(award:ToAnnouncement(), AddOn.Constants.group) end)
    if not check then Logging:Warn("Award() : Unable to announce adjustment") end

    -- we just adjusted something for someone, so rebuild the data if needed
    if self.frame and self.frame:IsVisible() then
        self:BuildData()
    end
end

function Points:Hide()
    if self.frame then
        self.frame.moreInfo:Hide()
        self.frame:Hide()
    end
    
    self:HideAdjust()
end

function Points:HideAdjust()
    if self.adjustFrame then
        self.adjustFrame:Hide()
        self.adjustFrame.errorTooltip:Hide()
        self.adjustFrame.subjectTooltip:Hide()
    end
end

function Points:Show()
    if self.frame then
        self.frame:Show()
    
        if AddOn:DevModeEnabled() or CanEditOfficerNote() then
            self.frame.decay:Show()
        else
            self.frame.decay:Hide()
        end
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

function Points:Update(forceUpdate)
    -- Logging:Debug("Update(%s)", tostring(forceUpdate or false))
    -- if module isn't enabled, no need to perform update
    if not self:IsEnabled() then return end
    if not self.frame then return end
    -- execute the update if forced or pending update combined with state of update handler
    local performUpdate = forceUpdate or (pendingUpdate and (self.updateHandler and self.updateHandler:Eligible()))
    if not performUpdate then return end
    -- Logging:Debug("Update(%s) - Performing update", tostring(forceUpdate or false))
    self.frame.st:SortData()
    self.updateHandler:ResetInterval()
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
    f.close = close
    
    -- filter
    local filter = UI:CreateButton(_G.FILTER, f.content)
    filter:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    filter:SetScript("OnClick", function(self) MSA_ToggleDropDownMenu(1, nil, FilterMenu, self, 0, 0) end )
    filter:SetScript("OnEnter", function() UI:CreateTooltip(L["deselect_responses"]) end)
    filter:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.filter = filter
    
    -- decay
    local decay = UI:CreateButton(L["decay"], f.content)
    decay:SetPoint("RIGHT", f.filter, "LEFT", -10, 0)
    decay:SetScript("OnClick", function() self:UpdateDecayFrame() end)
    f.decay = decay
    
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
    
    f.subjectType = Award.SubjectType.Character
    
    local resourceType =
        UI('Dropdown')
            .SetPoint("CENTER", f.name, "BOTTOM", 0, -35)
            .SetParent(f)()
    local resources = {}
    for k, v in pairs(Award.TypeIdToResource) do
        resources[k] = v:upper()
    end
    resourceType:SetList(resources)
    f.resourceType = resourceType
    
    local atLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    atLabel:SetPoint("TOPLEFT", f.rtLabel, "TOPLEFT", 0, -45)
    atLabel:SetText(L["action_type"])
    f.atLabel = atLabel
    
    local actionType =
        UI('Dropdown')
            .SetPoint("TOPLEFT", f.resourceType.frame, "BOTTOMLEFT", 0, -20)
            .SetParent(f)()
    local actions = {}
    for k, v in pairs(Award.TypeIdToAction) do
        actions[k] = v
    end
    actionType:SetList(actions)
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
                        f.subjectTooltip:Hide()
                        f:Hide()
                    end)
    f.close = close
    
    local adjust = UI:CreateButton(L["adjust"], f.content)
    adjust:SetPoint("RIGHT", f.close, "LEFT", -25)
    adjust:SetScript("OnClick",
                     function()
                        local award, validationErrors = f.Validate()
                        if Util.Tables.Count(validationErrors) ~= 0 then
                            UI.UpdateErrorTooltip(f, validationErrors)
                        else
                            f.errorTooltip:Hide()
                            Dialog:Spawn(AddOn.Constants.Popups.ConfirmAdjustPoints, award)
                        end
                    end
    )
    f.adjust = adjust
    
    UI.EmbedErrorTooltip("Points", f)
    UI.EmbedSubjectTooltip("Points", f)
    
    function f.Validate()
        local validationErrors = {}
        local award = Award()
        
        local subject = f.name:GetText()
        if Util.Strings.IsEmpty(subject) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["name"]))
        else
            local subjectType = tonumber(f.subjectType)
            if subjectType== Award.SubjectType.Character then
                award:SetSubjects(subjectType, subject)
            else
                if f.subjects and Util.Tables.Count(f.subjects) ~= 0 then
                    local subjects =
                        Util(f.subjects):Map(
                                function(subject)
                                    return AddOn:UnitName(subject[1])
                                end
                        ):Copy()()
                    -- Logging:Debug("Validate() : %s", Util.Objects.ToString(subjects))
                    award:SetSubjects(subjectType, unpack(subjects))
                else
                    award:SetSubjects(subjectType)
                end
            end
        end
        
        local actionType = f.actionType:GetValue()
        if Util.Objects.IsEmpty(actionType) or not Util.Objects.IsNumber(actionType) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["action_type"]))
        else
            award:SetAction(tonumber(actionType))
        end
    
        local setResource = true
        local resourceType = f.resourceType:GetValue()
        if Util.Objects.IsEmpty(resourceType) or not Util.Objects.IsNumber(resourceType) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["resource_type"]))
            setResource = false
        end
        
        local quantity = f.quantity:GetText()
        if Util.Objects.IsEmpty(quantity) or not Util.Strings.IsNumber(quantity) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["quantity"]))
            setResource = false
        end
    
        if setResource then award:SetResource(tonumber(resourceType), tonumber(quantity)) end
        
        local description = f.desc:GetText()
        if Util.Strings.IsEmpty(description) then
            Util.Tables.Push(validationErrors, format(L["x_unspecified_or_incorrect_type"], L["description"]))
        else
            award.description = description
        end
        
        return award, validationErrors
    end
    
    self.adjustFrame = f
    return self.adjustFrame
end

function Points:UpdateAdjustFrame(subjectType, name, resource, subjects)
    if not self.adjustFrame then return end
    
    local c
    if subjectType == Award.SubjectType.Character then
        c = AddOn.GetClassColor(GetEntry(name).class)
    else
        c = AddOn.GetSubjectTypeColor(subjectType)
    end
    
    if subjectType ~= Award.SubjectType.Character and subjects then
        name = name .. "(" .. Util.Tables.Count(subjects) .. ")"
        self.adjustFrame.subjects = subjects
        UI.UpdateSubjectTooltip(
            self.adjustFrame,
            Util(subjects)
                :Sort(function (a, b) return a[1] < b[1] end)
                :Map(function(e) return { AddOn.Ambiguate(e[1]), e[2] } end)
                :Copy()()
        )
    else
        self.adjustFrame.subjectTooltip:Hide()
        self.adjustFrame.subjects = nil
    end
    
    self.adjustFrame.subjectType = subjectType
    
    self.adjustFrame.name:SetText(name)
    self.adjustFrame.name:SetTextColor(c.r, c.g, c.b, c.a)
    
    self.adjustFrame.resourceType:SetValue(resource)
    self.adjustFrame.resourceType:SetText(Award.TypeIdToResource[resource]:upper())
    
    self.adjustFrame.actionType:SetValue(nil)
    self.adjustFrame.actionType:SetText(nil)
    
    self.adjustFrame.quantity:SetText('')
    self.adjustFrame.desc:SetText('')
    
    if not self.adjustFrame:IsVisible() then self.adjustFrame:Show() end
end

function Points:UpdateAmendFrame(entry)
    Logging:Debug("Amend() : %s", Objects.ToString(entry:toTable()))
    if entry.subjectType == Award.SubjectType.Character then
        error("Unsupported subject type for amending an award : " .. Award.TypeIdToSubject[entry.subjectType])
    end
    
    if not Objects.In(entry.actionType, Award.ActionType.Add, Award.ActionType.Subtract) then
        error("Unsupported resource type for amending an award : " .. Award.TypeIdToAction[entry.actionType])
    end
    
    self:UpdateAdjustFrame(
            entry.subjectType,
            Award.TypeIdToSubject[entry.subjectType],
            entry.resourceType,
            entry.subjects
    )
    --
    -- I don't think we want to provide these values, as it infers it will be updated
    -- when in fact, it's an entirely new entry with no relation to one being amended
    -- other than the subjects
    --
    -- self.adjustFrame.actionType:SetValue(entry.actionType)
    -- self.adjustFrame.quantity:SetText(entry.resourceQuantity)
    self.adjustFrame.desc:SetText(format('Amend \'%s\'', entry.description))
end



function Points.AdjustPointsOnShow(frame, award)
    UI.DecoratePopup(frame)
    
    local decoratedText
    if award.subjectType == Award.SubjectType.Character then
        local subject = award.subjects[1]
        local c = AddOn.GetClassColor(subject[2])
        decoratedText = UI.ColoredDecorator(c.r, c.g, c.b):decorate(subject[1])
    else
        decoratedText = UI.ColoredDecorator(AddOn.GetSubjectTypeColor(award.subjectType)):decorate("the " .. award:GetSubjectOriginText())
    end
    
    -- Are you certain you want to %s %d %s %s %s?
    frame.text:SetText(
            format(L["confirm_adjust_player_points"],
                   Award.TypeIdToAction[award.actionType]:lower(),
                   award.resourceQuantity,
                   Award.TypeIdToResource[award.resourceType]:upper(),
                   award.actionType == Award.ActionType.Add and "to" or "from",
                   decoratedText
            )
    )
end

-- @param award instance of Award
function Points.AwardPopupOnClickYes(frame, award, ...)
    -- Logging:Debug("AwardPopupOnClickYes() : %s", Util.Objects.ToString(award:toTable(), 3))
    Points:Adjust(award)
    Points:HideAdjust()
end

function Points.AwardPopupOnClickNo(frame, award)
    -- intentionally left blank
end


function Points:GetDecayFrame()
    if self.decayFrame then return self.decayFrame end
    
    local f = UI:CreateFrame("R2D2_Decay_Points", "DecayPoints", L["r2d2_decay_points_frame"], 150, 275)
    f:SetWidth(225)
    f:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -150)

    local rtLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rtLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 15, -25)
    rtLabel:SetText(L["resource_type"])
    f.rtLabel = rtLabel
    
    local resourceType =
        UI('Dropdown')
            .SetPoint("TOPLEFT", f.rtLabel, "BOTTOMLEFT", 0, -5)
            .SetParent(f)()
    local values = { }
    values[0] = 'All'
    for k, v in pairs(Award.TypeIdToResource) do
        values[k] = v:upper()
    end
    
    resourceType:SetList(values)
    resourceType:SetValue(0) -- default to 'All'
    f.resourceType = resourceType
    
    local pctLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pctLabel:SetPoint("TOPLEFT", f.rtLabel, "TOPLEFT", 0, -50)
    pctLabel:SetText(L["percent"])
    f.pctLabel = pctLabel

    local pct =
        UI('Slider')
                .SetSliderValues(0, 1, 0.01)
                .SetIsPercent(true)
                .SetValue(.10)
                .SetPoint("TOPLEFT", f.pctLabel, "BOTTOMLEFT")
                .SetParent(f)()
    f.pct = pct

    local descLabel = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", f.pctLabel, "TOPLEFT", 0, -65)
    descLabel:SetText(L["description"])
    f.descLabel = descLabel

    local desc = UI:New("EditBox", f.content)
    desc:SetHeight(25)
    desc:SetWidth(200)
    desc:SetPoint("TOPLEFT", f.descLabel, "BOTTOMLEFT", 0, -15)
    f.desc = desc

    local close = UI:CreateButton(_G.CANCEL, f.content)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -13, 5)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close
    
    local decay = UI:CreateButton(L["decay"], f.content)
    decay:SetPoint("RIGHT", f.close, "LEFT", -25)
    decay:SetScript("OnClick",
                     function()
                         Dialog:Spawn(AddOn.Constants.Popups.ConfirmDecayPoints, {f.Validate()})
                     end
    )
    f.decay = decay
    
    function f.Validate()
        local resourceType = f.resourceType:GetValue()
        local pct = f.pct:GetValue()
        local description = f.desc:GetText()
        local resourceTypes = resourceType == 0 and Util(Award.TypeIdToResource):Keys():Copy()() or {resourceType}
        
        Logging:Debug("DecayFrame.Validate() : resourceType=%d, resourceTypes=%s, pct=%d, description=%s",
                      resourceType, Objects.ToString(resourceTypes), pct, description
        )
    
        local decayAwards = {}
        for _, type in pairs(resourceTypes) do
            Logging:Debug("DecayFrame.Validate() : processing resourceType=%d", type)
            local decay
            if #decayAwards == 0 then
                decay = Award()
                decay:SetSubjects(Award.SubjectType.Guild)
                decay:SetAction(Award.ActionType.Decay)
                decay.description = description
            else
                decay = Award():reconstitute(decayAwards[#decayAwards]:toTable())
            end
            
            decay:SetResource(type, pct)
            Util.Tables.Push(decayAwards, decay)
        end
    
        Logging:Debug("DecayFrame.Validate() : decay entries %s", Objects.ToString(decayAwards, 2))
        
        return Util.Tables.Unpack(decayAwards)
    end
    
    self.decayFrame = f
    return self.decayFrame
end

function Points:UpdateDecayFrame()
    if not self.decayFrame then return end
    
    local f = self.decayFrame
    f.desc:SetText(format(L["decay_on_d"], DateFormat.Short:format(Date())))
    
    if not self.decayFrame:IsVisible() then self.decayFrame:Show() end
end

function Points.DecayOnShow(frame, awards)
    UI.DecoratePopup(frame)
    
    -- just grab one, they will both be the same except
    -- one will be for EP and other for GP
    local award = awards[1]
    
    local decoratedText =
        UI.ColoredDecorator(
            AddOn.GetSubjectTypeColor(award.subjectType)
        ):decorate("the " .. award:GetSubjectOriginText())
    
    
    frame.text:SetText(
            format(L["confirm_decay"],
                   #awards == 1 and (award.resourceType == Award.ResourceType.Ep and L["ep_abbrev"] or L["gp_abbrev"]) or L["all_values"],
                   award.resourceQuantity * 100,
                   decoratedText
            )
    )
end

function Points.DecayOnClickYes(frame, awards, ...)
    Logging:Debug("DecayOnClickYes(%d)", #awards)
    
    if #awards == 0 then return end
    
    -- we do decay in multiple awards, one for EP and one for GP
    -- if we try to do them too quickly, the updates to player's officer note won't
    -- be written yet and could encounter a conflict
    --
    -- therefore, this function will manage that via performing adjustment
    -- and waiting for callbacks to determine that all have been completed before
    -- moving to next award
    local function adjust(awards, index)
        Logging:Trace("adjust() : %d / %d", #awards, index)
        
        -- we make no checks on index vs award count in callback, so check here
        if index <= #awards then
            local award = awards[index]
            Logging:Debug("adjust() : Processing %s", Objects.ToString(award.resourceType))
            
            local updated, expected = 0, Util.Tables.Count(award.subjects)
            -- register callback with GuildStorage for notification when the officer note has been written
            -- keep track of updates and then when it matches the expected count, de-register callback
            -- and move on to next award
            GuildStorage.RegisterCallback(
                    Points,
                    GuildStorage.Events.GuildOfficerNoteWritten,
                    function(event, state)
                        updated = updated + 1
                        Logging:Debug("%s : %d/%d", tostring(event), tostring(updated), tostring(expected))
                        if updated == expected then
                            Logging:Trace("Unregistering GuildStorage.Events.GuildOfficerNoteWritten and moving to award %d", index + 1)
                            GuildStorage.UnregisterCallback(Points, GuildStorage.Events.GuildOfficerNoteWritten)
                            adjust(awards, index + 1)
                        end
                    end
            )
            
            Points:Adjust(award)
        else
            if Points.decayFrame then Points.decayFrame:Hide() end
        end
    end
    
    adjust(awards, 1)
end

function Points.DecayOnClickNo(frame, awards)
    -- intentional no-op
end

function Points.RevertOnShow(frame, entry)
    UI.DecoratePopup(frame)
    
    local decoratedText
    
    if entry.subjectType == Award.SubjectType.Character then
        local subject = entry.subjects[1]
        local c = AddOn.GetClassColor(subject[2])
        decoratedText = UI.ColoredDecorator(c.r, c.g, c.b):decorate(subject[1])
    end
    
    frame.text:SetText(
            format(L["confirm_revert"],
                   Award.TypeIdToAction[entry.actionType]:lower(),
                   entry.resourceQuantity,
                   Award.TypeIdToResource[entry.resourceType]:upper(),
                   entry.actionType == Award.ActionType.Add and "to" or "from",
                   decoratedText
            )
    )
end

function Points.RevertOnClickYes(frame, entry, ...)
    Points:RevertAdjust(entry)
end

function Points.RevertOnClickNo(frame, entry)
    -- intentional no-op
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

local SubjectAdjustLevel = DynamicAdjustLevel('SUBJECT', Award.SubjectType.Character)
local GuildAdjustLevel = StaticAdjustLevel('GUILD', _G.GUILD, Award.SubjectType.Guild)
local GroupAdjustLevel = StaticAdjustLevel('GROUP', _G.GROUP, Award.SubjectType.Raid)

local AdjustLevels = {
    [SubjectAdjustLevel.category] = SubjectAdjustLevel,
    [GuildAdjustLevel.category]   = GuildAdjustLevel,
    [GroupAdjustLevel.category]   = GroupAdjustLevel,
}

local function GetAdjustLevel()
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
                return UI.ColoredDecorator(AddOn.GetResourceTypeColor(Award.ResourceType.Ep)):decorate(L["ep_abbrev"])
            end,
            notCheckable = true,
            func = function(_)
                GetAdjustLevel():ChildAction(Award.ResourceType.Ep)
            end,
        },
        -- 2 GP
        {
            text = function()
                return UI.ColoredDecorator(AddOn.GetResourceTypeColor(Award.ResourceType.Gp)):decorate(L["gp_abbrev"])
            end,
            notCheckable = true,
            func = function(_)
                GetAdjustLevel():ChildAction(Award.ResourceType.Gp)
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
        local classes = Util(ItemUtil.ClassDisplayNameToId):Keys()
                            :Filter(AddOn.FilterClassesByFactionFn):Sort():Copy()()
        
        info = MSA_DropDownMenu_CreateInfo()
        for _, class in pairs(classes) do
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
    
        info = MSA_DropDownMenu_CreateInfo()
        info.text = L["ep_abbrev"]
        info.isTitle = true
        info.notCheckable = true
        info.disabled = true
        MSA_DropDownMenu_AddButton(info, level)
    
        info = MSA_DropDownMenu_CreateInfo()
        info.text = L["greater_than_min"]
        info.func = function()
            ModuleFilters.minimums['ep'] = not ModuleFilters.minimums['ep']
            Points:Update(true)
        end
        info.checked = ModuleFilters.minimums['ep']
        MSA_DropDownMenu_AddButton(info, level)
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
    
    if include then
        if Util.Tables.ContainsKey(ModuleFilters.minimums, 'ep') and ModuleFilters.minimums['ep'] then
            include = member.ep >= AddOn:EffortPointsModule().db.profile.ep_min
        end
    end
    
    return include
end