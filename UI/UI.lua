local _, AddOn = ...

local UI = {
    ConfigOptions = {

    }
}

AddOn.components.UI = UI

local AceGUI    = AddOn.Libs.AceGUI
local Util      = AddOn.Libs.Util
local Strings   = Util.Strings
local Objects   = Util.Objects
local Numbers   = Util.Numbers
local Logging   = AddOn.components.Logging
local COpts     = UI.ConfigOptions


local function Extra(options, extra)
    for k,v in pairs(extra or {}) do
        options[k] = v
    end
    return options
end

function COpts.Header(name, width, order, extra)
    header = {
        order = order or 0,
        type = 'header',
        name = name,
        width = width or nil
    }

    return Extra(header, extra)
end

function COpts.Description(descr, fontSize, order, extra)
    description = {
        order = order or 0,
        type = 'description',
        name = descr,
        fontSize = fontSize or 'medium',
    }
    return Extra(description, extra)
end

function COpts.Input(name, order, extra)
    input = {
        order = order or 1,
        type = 'input',
        name = name,
    }
    return Extra(input, extra)
end

function COpts.Range(name, order, min, max, step, extra)
    range = {
        order = order or 1,
        type = 'range',
        name = name,
        min = min,
        max = max,
        step = step or 0.5
    }

    return Extra(range, extra)
end

function COpts.Execute(name, order, descr, fn, extra)
    execute = {
        order = order or 1,
        type = 'execute',
        name = name,
        desc = descr,
        func = fn
    }

    return Extra(execute, extra)
end


function COpts.Select(name, order, descr, values, get, set, extra)
    sel = {
        order = order or 1,
        type = 'select',
        name = name,
        desc = descr,
        values = values,
        get = get,
        set = set,
    }

    return Extra(sel, extra)
end

function COpts.Toggle(name, order, descr, extra)
    toggle = {
        order = order or 1,
        type = 'toggle',
        name = name,
        desc = descr,
    }

    return Extra(toggle, extra)
end


function UI.CreateGameTooltip(name, parent)
    local itemTooltip = CreateFrame("GameTooltip", name.."_ItemTooltip", parent, "GameTooltipTemplate")
    itemTooltip:SetClampedToScreen(false)
    itemTooltip:SetScale(parent and parent:GetScale()*.95 or 1) -- Don't use parent scale
    return itemTooltip
end

--[[
 Enable chain-calling for UI elements

 E.G.

  Create("X").SetFoo("x").SetBar("y")...

 in lieu of

  local x = Crate("X)
  x:SetFoo("x")
  x:SetBar("y")
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
        Logging:Debug("ChainFn() : Object = %s, Key = %s", type(obj), key)

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
        chain.key = Strings.UcFirst(key)
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