local _, AddOn = ...
local Logging   = AddOn.Libs.Logging
local L         = AddOn.components.Locale
local Util      = AddOn.Libs.Util
local UI        = AddOn.components.UI
local Class     = AddOn.Libs.Class
local Models    = AddOn.components.Models

--@param module the module name (for determining settings associated with more info)
--@param f the frame to which to add widgets
--@param fn the function to call to populate the frame
function AddOn.EmbedMoreInfoWidgets(module, f, fn)
    local moreInfo = AddOn:MoreInfoEnabled(module)
    
    -- more info button
    local miButton = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    miButton:SetSize(25, 25)
    miButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -20)
    --Logging:Debug("EmbedMoreInfoWidgets(%s)", tostring(moreInfo))
    
    if moreInfo then
        miButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        miButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    else
        miButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        miButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    end
    miButton:SetScript("OnClick", function(button)
        moreInfo = not moreInfo
        AddOn.db.profile.modules[module].moreInfo = moreInfo
        if moreInfo then
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        else -- hide it
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        end
        
        if Util.IsFunction(fn) then
            Logging:Debug("EmbedMoreInfoWidgets() : Invoking custom function")
            fn(module, f)
        else
            AddOn.UpdateMoreInfo(module, f)
        end
    end)
    miButton:SetScript("OnEnter", function() UI:CreateTooltip(L["click_more_info"]) end)
    miButton:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.moreInfoBtn = miButton
    
    f.moreInfo = CreateFrame( "GameTooltip", "R2D2_" .. module .. "_MoreInfo", nil, "GameTooltipTemplate" )
    f.content:SetScript("OnSizeChanged", function()
        f.moreInfo:SetScale(f:GetScale() * 0.6)
    end)
end

function AddOn.UpdateMoreInfo(module, f, row, data, classSupplier, gpSupplier)
    local moreInfo, lootStats = AddOn:MoreInfoSettings(module)
    
    local name
    if data and row then
        name = data[row].name
    else
        local selection = f.st:GetSelection()
        name = selection and f.st:GetRow(selection).name or nil
    end
    
    -- Logging:Debug("UpdateMoreInfo(%s, %s)", tostring(name), tostring(moreInfo))
    
    -- if there is a GP display value, update it to reflect candidates response
    if f.gp and gpSupplier and Util.Objects.IsFunction(gpSupplier) then
        local gpText = gpSupplier(name)
        f.gp:SetText("GP: " .. (gpText and gpText or "UNKNOWN"))
    end
    
    if not moreInfo or not name then
        return f.moreInfo:Hide()
    end
    
    local color = AddOn.GetClassColor(classSupplier and classSupplier(name) or "")
    -- Logging:Debug("UpdateMoreInfo : %s", Util.Objects.ToString(color))
    local tip = f.moreInfo
    -- Logging:Debug("MoreInfo = %s", tostring(tip))
    tip:SetOwner(f, "ANCHOR_RIGHT")
    tip:AddLine(AddOn.Ambiguate(name), color.r, color.g, color.b)
    
    if lootStats and lootStats:Get(name) then
        -- Logging:Debug("UpdateMoreInfo(%s) : Adding Loot Stats", tostring(name))
        local charEntry = lootStats:Get(name)
        local charStats = charEntry:GetTotals()
        
        local r, g, b
        tip:AddLine(L["latest_items_won"])
        for _, v in pairs(charEntry.awards) do
            if v[3] then r, g, b = unpack(v[3], 1, 3) end
            tip:AddDoubleLine(v[1], v[2], r or 1, g or 1, b or 1, r or 1, g or 1, b or 1)
        end
        tip:AddLine(" ")
        tip:AddLine(_G.TOTAL)
        for k, v in pairs(charStats.responses) do
            if v[3] then r,g,b = unpack(v[3],1,3) end
            tip:AddDoubleLine(v[1], v[2], r or 1,g or 1,b or 1, r or 1,g or 1,b or 1)
        end
        tip:AddDoubleLine(L["Number of raids received loot from:"], charStats.raids.count, 1, 1, 1, 1, 1, 1)
        tip:AddDoubleLine(L["Total items received:"], charStats.count, 0, 1, 1, 0, 1, 1)
    else
        --Logging:Debug("UpdateMoreInfo(%s) : No Loot Stats entries", tostring(name))
        tip:AddLine(L["no_entries_in_loot_history"])
    end
    
    tip:Show()
    tip:SetAnchorType("ANCHOR_RIGHT", 0, -tip:GetHeight())
end

-- bet we can use AceBucket for this
local UpdateHandler = Class('UpdateHandler')

function UpdateHandler:initialize(callback, updateInterval)
    self.pending = false
    self.elapsed = 0.0
    self.interval = updateInterval
    self.frame = CreateFrame("FRAME")
    self.callback = callback
end

function UpdateHandler:OnUpdate(elapsed)
    self.elapsed = self.elapsed + elapsed
    
    -- Logging:Debug("OnUpdate(%.2f) : elapsed=%.2f, interval=%.2f, pending=%s", elapsed, self.elapsed, self.interval, tostring(self.pending))
    if self.pending and self.elapsed > self.interval then
        self.callback()
        self.elapsed = 0
    end
end

function UpdateHandler:Dispose()
    self.frame:Hide()
end

function UpdateHandler:RefreshInterval()
    self.elapsed = 0
end

function UpdateHandler:Eligible()
    local eligible = self.elapsed > self.interval
    if not eligible then self.pending = true end
    return eligible
end

function AddOn.CreateUpdateHandler(callback, updateInterval)
    local entry = UpdateHandler(callback, updateInterval)
    entry.frame:SetScript("OnUpdate", function(self, elapsed) entry:OnUpdate(elapsed) end)
    entry.frame:Show()
    return entry
end

function AddOn.SetCellClassIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, class)
    local celldata = data and (data[realrow].cols and data[realrow].cols[column] or data[realrow][column])
    class = celldata and celldata.args and celldata.args[1] or class
    
    --Logging:Debug("SetCellClassIcon(%s)", tostring(class))
    
    if class then
        local coords = CLASS_ICON_TCOORDS[class]
        if coords then
            frame:SetNormalTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            frame:GetNormalTexture():SetTexCoord(unpack(coords))
        else
            frame:SetNormalTexture("Interface/ICONS/INV_Sigil_Thorim.png")
        end
    else
        frame:SetNormalTexture("Interface/ICONS/INV_Sigil_Thorim.png")
    end
end

AddOn.Constants.Colors.SubjectTypes = {
    [Models.Award.SubjectType.Character] = _G.ITEM_QUALITY_COLORS[1].color,
    [Models.Award.SubjectType.Guild]     = _G.ITEM_QUALITY_COLORS[2].color,
    [Models.Award.SubjectType.Raid]      = _G.ITEM_QUALITY_COLORS[5].color,
    [Models.Award.SubjectType.Standby]   = _G.ITEM_QUALITY_COLORS[3].color,
}

function AddOn.GetSubjectTypeColor(subjectType)
    if Util.Objects.IsString(subjectType) then subjectType = Models.Award.SubjectType[subjectType] end
    return AddOn.Constants.Colors.SubjectTypes[subjectType]
end

AddOn.Constants.Colors.ActionTypes = {
    [Models.Award.ActionType.Add]      = CreateColor(0, 1, 0.59, 1),
    [Models.Award.ActionType.Subtract] = CreateColor(0.96, 0.55, 0.73, 1),
    [Models.Award.ActionType.Reset]    = CreateColor(1, 0.96, 0.41, 1),
}

function AddOn.GetActionTypeColor(actionTYpe)
    if Util.Objects.IsString(actionTYpe) then actionTYpe = Models.Award.ActionType[actionTYpe] end
    return AddOn.Constants.Colors.ActionTypes[actionTYpe]
end

AddOn.Constants.Colors.ResourceTypes = {
    [Models.Award.ResourceType.Ep] = _G.ITEM_QUALITY_COLORS[6].color,
    [Models.Award.ResourceType.Gp] = _G.ITEM_QUALITY_COLORS[5].color,
}

function AddOn.GetResourceTypeColor(resourceType)
    if Util.Objects.IsString(resourceType) then resourceType = Models.Award.ResourceType[resourceType] end
    return AddOn.Constants.Colors.ResourceTypes[resourceType]
end