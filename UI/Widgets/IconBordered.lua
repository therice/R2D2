local _, AddOn = ...

local name = "IconBordered"
local Widget = {}

function Widget:New(parent, name, texture)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(40,40)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    b:GetHighlightTexture():SetBlendMode("ADD")
    b:SetNormalTexture(texture or "Interface\\InventoryItems\\WoWUnknownItem01")
    b:GetNormalTexture():SetDrawLayer("BACKGROUND")
    b:SetBackdrop({
        bgFile = "",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 18,
    })
    b:SetScript("OnLeave", AddOn.components.UI.HideTooltip)
    b:EnableMouse(true)
    b:RegisterForClicks("AnyUp")
    b.SetBorderColor = self.SetBorderColor
    b.Desaturate = self.Desaturate
    return b
end

function Widget:SetBorderColor(color)
    if color == "green" then
        self:SetBackdropBorderColor(0,1,0,1)
        self:GetNormalTexture():SetVertexColor(0.8,0.8,0.8)
    elseif color == "yellow" then
        self:SetBackdropBorderColor(1,1,0,1)
        self:GetNormalTexture():SetVertexColor(1,1,1)
    elseif color == "grey" or color == "gray" then
        self:SetBackdropBorderColor(0.75,0.75,0.75,1)
        self:GetNormalTexture():SetVertexColor(1,1,1)
    elseif color == "red" then
        self:SetBackdropBorderColor(1,0,0,1)
        self:GetNormalTexture():SetVertexColor(1,1,1)
    elseif color == "purple" then
        self:SetBackdropBorderColor(0.65,0.4,1,1)
        self:GetNormalTexture():SetVertexColor(1,1,1)
    -- Default to white
    else
        self:SetBackdropBorderColor(1,1,1,1)
        self:GetNormalTexture():SetVertexColor(0.5,0.5,0.5)
    end
end

function Widget:Desaturate()
    return self:GetNormalTexture():SetDesaturated(true)
end

AddOn.components.UI:RegisterElement(Widget, name)