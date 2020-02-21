local name, namespace = ...
local G = _G

local AceGUI = LibStub("AceGUI-3.0")
local UI = namespace:NewModule("UI", "AceEvent-3.0")
local logging = namespace.components.Logging

namespace.components.UI = UI

local Strings = namespace.components.Util.Strings
local Objects = namespace.components.Util.Objects
local Numbers = namespace.components.Util.Numbers


function UI:OnInitialize()
    logging:Trace("OnInitialize(%s)", self:GetName())
end

function UI:OnEnable()
    logging:Trace("OnEnable(%s)", self:GetName())
end

-- Enable chain-calling
UI.C = {f = nil, k = nil}
local Fn = function (...)
    local c, k, f = UI.C, rawget(UI.C, "k"), rawget(UI.C, "f")
    if k == "AddTo" then
        local parent, beforeWidget = ...
        if parent.type == "Dropdown-Pullout" then
            parent:AddItem(f)
        elseif not parent.children or beforeWidget == false then
            (f.frame or f):SetParent(parent.frame or parent)
        else
            parent:AddChild(f, beforeWidget)
        end
    else
        if k == "Toggle" then
            k = (...) and "Show" or "Hide"
        end

        local obj = f[k] and f
                or f.frame and f.frame[k] and f.frame
                or f.image and f.image[k] and f.image
                or f.label and f.label[k] and f.label
                or f.content and f.content[k] and f.content
        obj[k](obj, ...)

        -- Fix Label's stupid image anchoring
        if Objects.In(obj.type, "Label", "InteractiveLabel") and Objects.In(k, "SetText", "SetFont", "SetFontObject", "SetImage") then
            local strWidth, imgWidth = obj.label:GetStringWidth(), obj.imageshown and obj.image:GetWidth() or 0
            local width = Numbers.Round(strWidth + imgWidth + (min(strWidth, imgWidth) > 0 and 4 or 0), 1)
            obj:SetWidth(width)
        end
    end
    return c
end
setmetatable(UI.C, {
    __index = function (c, k)
        c.k = Strings.Capitalize(k)
        return Fn
    end,
    __call = function (c, i)
        local f = rawget(c, "f")
        if i ~= nil then return f[i] else return f end
    end
})
setmetatable(UI, {
    __call = function (_, f, ...)
        UI.C.f = type(f) == "string" and AceGUI:Create(f, ...) or f
        UI.C.k = nil
        return UI.C
    end
})