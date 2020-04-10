local _, AddOn = ...
local Logging   = AddOn.Libs.Logging
local L         = AddOn.components.Locale
local Util      = AddOn.Libs.Util
local UI        = AddOn.components.UI
local Class     = AddOn.Libs.Class

--@param module the module name (for determining settings associated with more info)
--@param f the frame to which to add widgets
function AddOn.EmbedMoreInfoWidgets(module, f)
    local moreInfo = AddOn:MoreInfoSettings(module)
    
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
        AddOn.UpdateMoreInfo(module, f)
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
    
    -- if there is a GP display value, update it to reflect candidates response
    if f.gp and gpSupplier and Util.Objects.IsFunction(gpSupplier) then
        local gpText = gpSupplier(name)
        f.gp:SetText("GP: " .. (gpText and gpText or "UNKNOWN"))
    end
    
    if not moreInfo or not name then
        return f.moreInfo:Hide()
    end
    
    local color = AddOn.GetClassColor(classSupplier and classSupplier(name) or "")
    local tip = f.moreInfo
    tip:SetOwner(f, "ANCHOR_RIGHT")
    tip:AddLine(AddOn.Ambiguate(name), color.r, color.g, color.b)
    
    if lootStats and lootStats:Get(name) then
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