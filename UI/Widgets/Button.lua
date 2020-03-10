local _, AddOn = ...

local name = "Button"
local Widget = {}

function Widget:New(parent, name)
	local b = CreateFrame("Button", parent:GetName()..name, parent, "UIPanelButtonTemplate")
	b:SetText("")
	b:SetSize(100,25)
	return b
end

AddOn.components.UI:RegisterElement(Widget, name)
