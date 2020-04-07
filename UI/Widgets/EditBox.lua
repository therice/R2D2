local _, AddOn = ...

local name = "EditBox"
local Widget = {}


function Widget:New(parent, name)
    local eb = CreateFrame("EditBox",parent:GetName()..name, parent)
    Widget.Border(eb,0.24,0.25,0.3,1,1)
    eb.Background = eb:CreateTexture(nil,"BACKGROUND")
    eb.Background:SetColorTexture(0,0,0,.3)
    eb.Background:SetPoint("TOPLEFT")
    eb.Background:SetPoint("BOTTOMRIGHT")
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

function Widget.Border(self,cR,cG,cB,cA,size,offsetX,offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    self.BorderTop = self:CreateTexture(nil,"BACKGROUND")
    self.BorderTop:SetColorTexture(cR,cG,cB,cA)
    self.BorderTop:SetPoint("TOPLEFT",-size-offsetX,size+offsetY)
    self.BorderTop:SetPoint("BOTTOMRIGHT",self,"TOPRIGHT",size+offsetX,offsetY)
    
    self.BorderLeft = self:CreateTexture(nil,"BACKGROUND")
    self.BorderLeft:SetColorTexture(cR,cG,cB,cA)
    self.BorderLeft:SetPoint("TOPLEFT",-size-offsetX,offsetY)
    self.BorderLeft:SetPoint("BOTTOMRIGHT",self,"BOTTOMLEFT",-offsetX,-offsetY)
    
    self.BorderBottom = self:CreateTexture(nil,"BACKGROUND")
    self.BorderBottom:SetColorTexture(cR,cG,cB,cA)
    self.BorderBottom:SetPoint("BOTTOMLEFT",-size-offsetX,-size-offsetY)
    self.BorderBottom:SetPoint("TOPRIGHT",self,"BOTTOMRIGHT",size+offsetX,-offsetY)
    
    self.BorderRight = self:CreateTexture(nil,"BACKGROUND")
    self.BorderRight:SetColorTexture(cR,cG,cB,cA)
    self.BorderRight:SetPoint("BOTTOMRIGHT",size+offsetX,offsetY)
    self.BorderRight:SetPoint("TOPLEFT",self,"TOPRIGHT",offsetX,-offsetY)
end


AddOn.components.UI:RegisterElement(Widget, name)

