local _, AddOn = ...
local Logging   = AddOn.Libs.Logging
local L         = AddOn.components.Locale
local Util      = AddOn.Libs.Util
local UI        = AddOn.components.UI

--@param module the module name (for determining settings associated with more info)
--@param f the frame to which to add widgets
function AddOn:EmbedMoreInfoWidgets(module, f)
    local moreInfo = AddOn:MoreInfoSettings(module)
    
    -- more info button
    local miButton = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    miButton:SetSize(25, 25)
    miButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -20)
    Logging:Debug("EmbedMoreInfoWidgets(%s)", tostring(moreInfo))
    
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
        self:UpdateMoreInfo(module, f)
    end)
    miButton:SetScript("OnEnter", function() UI:CreateTooltip(L["click_more_info"]) end)
    miButton:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.moreInfoBtn = miButton
    
    f.moreInfo = CreateFrame( "GameTooltip", "R2D2_" .. module .. "_MoreInfo", nil, "GameTooltipTemplate" )
    f.content:SetScript("OnSizeChanged", function()
        f.moreInfo:SetScale(f:GetScale() * 0.6)
    end)
end

function AddOn:UpdateMoreInfo(module, f, row, data, classFn)
    local moreInfo, moreInfoData = AddOn:MoreInfoSettings(module)
    
    local name
    if data and row then
        name = data[row].name
    else
        local selection = f.st:GetSelection()
        name = selection and f.st:GetRow(selection).name or nil
    end
    
    if not moreInfo or not name then
        return f.moreInfo:Hide()
    end
    
    
    local color = AddOn:GetClassColor(classFn and classFn(name) or "")
    local tip = f.moreInfo
    tip:SetOwner(f, "ANCHOR_RIGHT")
    tip:AddLine(AddOn.Ambiguate(name), color.r, color.g, color.b)
    
    if moreInfoData and moreInfoData[name] then
    
    else
        tip:AddLine(L["no_entries_in_loot_hisory"])
    end
    
    tip:Show()
    tip:SetAnchorType("ANCHOR_RIGHT", 0, -tip:GetHeight())
end