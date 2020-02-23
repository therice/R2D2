local _, namespace = ...
local G = _G

local AceGUI = LibStub("AceGUI-3.0")
local UI = namespace:NewModule("UI", "AceEvent-3.0")
local logging = namespace.components.Logging

namespace.components.UI = UI

local Strings = namespace.components.Util.Strings
local Objects = namespace.components.Util.Objects
local Numbers = namespace.components.Util.Numbers


function UI:OnInitialize()
    logging:Debug("OnInitialize(%s)", self:GetName())
end

function UI:OnEnable()
    logging:Debug("OnEnable(%s)", self:GetName())
end

--[[
 Enable chain-calling for UI elements

 E.G.

  Create("X").SetFoo("x").SetBar("y")...

 in lieu of

  local x = Crate("X)
  x:SetFoo("x")
  x:.SetBar("y")
  ...

--]]

UI.Chain = { widget = nil, key = nil}

local ChainFn = function (...)
    local chain, key, widget = UI.Chain, rawget(UI.Chain, "key"), rawget(UI.Chain, "widget")
    -- key is the function to invoke
    if key == "AddTo" then
        local parent, beforeWidget = ...
        if parent.type == "Dropdown-Pullout" then
            parent:AddItem(widget)
        elseif not parent.children or beforeWidget == false then
            (widget.frame or widget):SetParent(parent.frame or parent)
        else
            parent:AddChild(widget, beforeWidget)
        end
    else
        if key == "Toggle" then
            key = (...) and "Show" or "Hide"
        end

        local obj = widget[key] and widget
                or widget.frame and widget.frame[key] and widget.frame
                or widget.image and widget.image[key] and widget.image
                or widget.label and widget.label[key] and widget.label
                or widget.content and widget.content[key] and widget.content
        obj[key](obj, ...)

        -- Fix Label's stupid image anchoring
        if Objects.In(obj.type, "Label", "InteractiveLabel") and Objects.In(key, "SetText", "SetFont", "SetFontObject", "SetImage") then
            local strWidth, imgWidth = obj.label:GetStringWidth(), obj.imageshown and obj.image:GetWidth() or 0
            local width = Numbers.Round(strWidth + imgWidth + (min(strWidth, imgWidth) > 0 and 4 or 0), 1)
            obj:SetWidth(width)
        end
    end
    return chain
end

setmetatable(UI.Chain, {
    __index = function (chain, key)
        chain.key = Strings.Capitalize(key)
        return ChainFn
    end,
    __call = function (chain, index)
        local widget = rawget(chain, "widget")
        if index ~= nil then return widget[index] else return widget
        end
    end
})

setmetatable(UI, {
    __call = function (_, widget, ...)
        UI.Chain.widget = type(widget) == "string" and AceGUI:Create(widget, ...) or widget
        UI.Chain.key = nil
        return UI.Chain
    end
})