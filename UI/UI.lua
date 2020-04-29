local _, AddOn = ...
local AceGUI = AddOn.Libs.AceGUI
local Util = AddOn.Libs.Util
local Window = AddOn.Libs.Window
local Strings = Util.Strings
local Objects = Util.Objects
local Numbers = Util.Numbers
local Logging = AddOn.components.Logging

local L = AddOn.components.Locale
local Class = AddOn.Libs.Class
local ST = AddOn.Libs.ScrollingTable

local UI = {
    ConfigOptions = {}
}

AddOn.components.UI = UI

local COpts = UI.ConfigOptions

-- AceConfig Options
local function Extra(options, extra)
    for k,v in pairs(extra or {}) do
        options[k] = v
    end
    return options
end

function COpts.Header(name, width, order, extra)
    local header = {
        order = order or 0,
        type = 'header',
        name = name,
        width = width or nil
    }

    return Extra(header, extra)
end

function COpts.Description(descr, fontSize, order, extra)
    local description = {
        order = order or 0,
        type = 'description',
        name = descr,
        fontSize = fontSize or 'medium',
    }
    return Extra(description, extra)
end

function COpts.Input(name, order, extra)
    local input = {
        order = order or 1,
        type = 'input',
        name = name,
    }
    return Extra(input, extra)
end

function COpts.Range(name, order, min, max, step, extra)
    local range = {
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
    local execute = {
        order = order or 1,
        type = 'execute',
        name = name,
        desc = descr,
        func = fn
    }

    return Extra(execute, extra)
end


function COpts.Select(name, order, descr, values, get, set, extra)
    local sel = {
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

function COpts.Toggle(name, order, descr, disabled, extra)
    local toggle = {
        order = order or 1,
        type = 'toggle',
        name = name,
        desc = descr,
        disabled = disabled,
    }

    return Extra(toggle, extra)
end

function UI.RightClickMenu(predicate, entries, callback)
    return function(menu, level)
        if not predicate() then return end
        if not menu or not level then return end
        
        local info = MSA_DropDownMenu_CreateInfo()
        local candidateName = menu.name
        local value = _G.MSA_DROPDOWNMENU_MENU_VALUE
        
        for _, entry in ipairs(entries[level]) do
            info = MSA_DropDownMenu_CreateInfo()
            if not entry.special then
                if not entry.onValue or entry.onValue == value or (Util.Objects.IsFunction(entry.onValue) and entry.onValue(candidateName)) then
                    if (entry.hidden and Util.Objects.IsFunction(entry.hidden) and not entry.hidden(candidateName)) or not entry.hidden then
                        for name, val in pairs(entry) do
                            if name == "func" then
                                info[name] = function() return val(candidateName) end
                            elseif Util.Objects.IsFunction(val) then
                                info[name] = val(candidateName)
                            else
                                info[name] = val
                            end
                        end
                        MSA_DropDownMenu_AddButton(info, level)
                    end
                end
            else
                if callback then callback(info, menu, level, entry, value) end
            end
        end
    end
end

-- wrapper around a Scrolling Table's DoCellUpdate which handles necessary post execution
-- stuff which could be missed if not handled on a case by case basis
function UI.ScrollingTableDoCellUpdate(fn)
    local function after(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
        local rowdata = table:GetRow(realrow)
        local celldata = table:GetCell(rowdata, column)
    
        local highlight
        if type(celldata) == "table" then
            highlight = celldata.highlight
        end
    
        if table.fSelect then
            if table.selected == realrow then
                table:SetHighLightColor(rowFrame, highlight or cols[column].highlight or rowdata.highlight or table:GetDefaultHighlight())
            else
                table:SetHighLightColor(rowFrame, table:GetDefaultHighlightBlank())
            end
        end
    end
    
    return function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
        fn(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
        after(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
    end
end

function UI.Sort(table, rowa, rowb, sortbycol, valueFn)
    local column = table.cols[sortbycol]
    local row1, row2 = table:GetRow(rowa), table:GetRow(rowb)
    local v1, v2 = valueFn(row1), valueFn(row2)
    
    if v1 == v2 then
        if column.sortnext then
            local nextcol = table.cols[column.sortnext]
            if nextcol and not(nextcol.sort) then
                if nextcol.comparesort then
                    return nextcol.comparesort(table, rowa, rowb, column.sortnext)
                else
                    return table:CompareSort(rowa, rowb, column.sortnext)
                end
            else
                return false
            end
        else
            return false
        end
    else
        local direction = column.sort or column.defaultsort or ST.SORT_DSC
        if direction == ST.SORT_ASC then
            return v1 < v2
        else
            return v1 > v2
        end
    end
end

function UI.RGBToHex(r,g,b)
    return string.format("%02x%02x%02x", math.floor(255*r), math.floor(255*g), math.floor(255*b))
end

function UI.RGBToHexPrefix(r, g, b)
    return "|cff" .. UI.RGBToHex(r, g, b)
end

local Decorator = Class('Decorator')
function Decorator:initialize() end
function Decorator:decorate(...) return Util.Strings.Join('', ...) end

local ColoredDecorator = Class('ColoredDecorator', Decorator)
AddOn.components.UI.ColoredDecorator = ColoredDecorator

function ColoredDecorator:initialize(r, g, b)
    Decorator.initialize(self)
    -- Logging:Debug("%s", Util.Objects.ToString(r))
    if Util.Objects.IsTable(r) then
        if r.GetRGB then
            self.hex = UI.RGBToHex(r:GetRGB())
        else
            self.hex = UI.RGBToHex(unpack(r))
        end
    else
        self.hex = UI.RGBToHex(r, g, b)
    end
end

function ColoredDecorator:decorate(...)
    return "|cff" .. self.hex .. ColoredDecorator.super:decorate(...) .. "|r"
end

-- UI native elements (no library/wrappers)
local frames = {}
local private = { elements = {}, num = {}, embeds = {}}
UI.private = private

function UI:New(type, parent, ...)
    return private:New(type, parent, nil, ...)
end

function UI:NewNamed(type, parent, name, ...)
    return private:New(type, parent, name, ...)
end

function UI:RegisterElement(object, etype)
    if type(object) ~= "table" then error("R2D2.UI:RegisterElement() - 'object' isn't a table.") end
    if type(etype) ~= "string" then error("R2D2.UI:RegisterElement() - 'type' isn't a string.") end
    private.elements[etype] = object
end

function private:New(type, parent, name, ...)
    if self.elements[type] then
        parent = parent or _G.UIParent
        if name then
            return self:Embed(self.elements[type]:New(parent, name, ...))
        else
            -- Create a name
            if not self.num[type] then self.num[type] = 0 end
            self.num[type] = self.num[type] + 1
            return self:Embed(self.elements[type]:New(parent, "R2D2_UI_"..type..self.num[type], ...))
        end
    else
        Logging:Warn("UI Error in New() : No such element", type, name)
        error(format("UI Error in New() : No such element %s %s", type, name))
    end
end

function private:Embed(object)
    for k,v in pairs(self.embeds) do
        object[k] = v
    end
    return object
end

private.embeds["SetMultipleScripts"] = function(object, scripts)
    for k,v in pairs(scripts) do
        object:SetScript(k,v)
    end
end

function UI.MinimizeFrames()
    for _, frame in ipairs(frames) do
        if frame:IsVisible() and not frame.combatMinimized then
            frame.combatMinimized = true
            frame:Minimize()
        end
    end
end

function UI.MaximizeFrames()
    for _, frame in ipairs(frames) do
        if frame.combatMinimized then
            frame.combatMinimized = false
            frame:Maximize()
        end
    end
end


--- Creates a standard frame with title, minimizing, positioning and scaling supported.
--		Adds Minimize(), Maximize() and IsMinimized() functions on the frame, and registers it for hide on combat.
--		SetWidth/SetHeight called on frame will also be called on frame.content.
--		Minimizing is done by double clicking the title. The returned frame and frame.title is NOT hidden.
-- Only frame.content is minimized, so put children there for minimize support
-- @paramsig name, module, title[, width, height]
-- @param name Global name of the frame.
-- @param module Name of the module (used for lib-window-1.1 config in DB).
-- @param title The title text.
-- @param width The width of the title frame, defaults to 250.
-- @param height Height of the frame, defaults to 325.
-- @return The frame object.
function UI:CreateFrame(name, module, title, width, height)
    local f = CreateFrame("Frame", name, UIParent)
    local storage = AddOn.db.profile.ui[module]

    f:Hide()
    f:SetFrameStrata("DIALOG")
    f:SetWidth(450)
    f:SetHeight(height or 325)
    f:SetScale(storage.scale or 1.1)
    Window:Embed(f)
    f:RegisterConfig(storage)
    f:RestorePosition()
    f:MakeDraggable()
    f:SetScript("OnMouseWheel", function(f,delta) if IsControlKeyDown() then Window.OnMouseWheel(f,delta) end end)

    local tf = CreateFrame("Frame", "R2D2_UI_"..module.."_Title", f)
    tf:SetToplevel(true)
    tf:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 8, edgeSize = 6,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    tf:SetBackdropColor(0, 0, 0, 1)
    tf:SetBackdropBorderColor(0, 0, 0, 1)
    tf:SetHeight(22)
    tf:EnableMouse()
    tf:SetMovable(true)
    tf:SetWidth(width or 250)
    --tf:SetWidth(250)
    tf:SetPoint("CENTER",f,"TOP",0,-1)
    tf:SetScript("OnMouseDown", function(self) self:GetParent():StartMoving() end)
    tf:SetScript("OnMouseUp", function(self)
        local frame = self:GetParent()
        frame:StopMovingOrSizing()
        if frame:GetScale() and frame:GetLeft() and frame:GetRight() and frame:GetTop() and frame:GetBottom() then
            frame:SavePosition()
        end
        if self.lastClick and GetTime() - self.lastClick <= 0.5 then
            self.lastClick = nil
            if frame.minimized then frame:Maximize() else frame:Minimize() end
        else
            self.lastClick = GetTime()
        end
    end)

    local text = tf:CreateFontString(nil,"OVERLAY","GameFontNormal")
    text:SetPoint("CENTER",tf,"CENTER")
    text:SetTextColor(1,1,1,1)
    text:SetText(title)
    tf.text = text
    f.title = tf
    f.title:SetPoint("CENTER", f, "TOP", 0,10)

    -- actual frame content
    local c = CreateFrame("Frame", "R2D2_UI_"..module.."_Content", f)
    c:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    c:EnableMouse(true)
    c:SetWidth(450)
    c:SetHeight(height or 325)
    c:SetBackdropColor(0, 0, 0, 1)
    c:SetBackdropBorderColor(0, 0, 0, 1)
    c:SetPoint("TOPLEFT")
    c:SetScript("OnMouseDown", function(self) self:GetParent():StartMoving() end)
    c:SetScript("OnMouseUp", function(self)
        local frame = self:GetParent()
        frame:StopMovingOrSizing()
        if frame:GetScale() and frame:GetLeft() and frame:GetRight() and frame:GetTop() and frame:GetBottom() then
            frame:SavePosition()
        end
    end)

    f.content = c
    f.minimized = false
    f.IsMinimized = function(frame) return frame.minimized end
    f.Minimize = function(frame)
        if not frame.minimized then
            frame.content:Hide()
            frame.minimized = true
        end
    end
    f.Maximize = function(frame)
        if frame.minimized then
            frame.content:Show()
            frame.minimized = false
        end
    end

    tinsert(frames, f)
    local old_setwidth = f.SetWidth
    f.SetWidth = function(self, width)
        old_setwidth(self, width)
        self.content:SetWidth(width)
    end
    local old_setheight = f.SetHeight
    f.SetHeight = function(self, height)
        old_setheight(self, height)
        self.content:SetHeight(height)
    end

    return f
end

function UI:CreateButton(text, parent)
    local b = UI:New("Button", parent)
    b:SetText(text)
    return b
end

function UI:CreateGameTooltip(module, parent)
    local itemTooltip = CreateFrame("GameTooltip", module.."_ItemTooltip", parent, "GameTooltipTemplate")
    itemTooltip:SetClampedToScreen(false)
    itemTooltip:SetScale(parent and parent:GetScale()*.95 or 1)
    return itemTooltip
end

--- Displays a tooltip anchored to the mouse.
-- @param ... string(s) lines to be added.
function UI:CreateTooltip(...)
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    for i = 1, select("#", ...) do
        GameTooltip:AddLine(select(i, ...),1,1,1)
    end
    GameTooltip:Show()
end

function UI:CreateHypertip(link)
    if Strings.IsEmpty(link) then return end
    -- this is to support shift click comparison on all tooltips
    local function tip()
        local tip = CreateFrame("GameTooltip", "R2D2_TooltipEventHandler", UIParent, "GameTooltipTemplate")
        tip:RegisterEvent("MODIFIER_STATE_CHANGED")
        tip:SetScript("OnEvent",
                function(this, event, arg)
                    if self.tooltip.sowing and event == "MODIFIER_STATE_CHANGED" and (arg == "LSHIFT" or arg == "RSHIFT") and self.tooltip.link then
                        self:CreateHypertip(self.tooltip.link)
                    end
                end
        )
        return tip
    end

    if not self.tooltip then self.tooltip = tip() end
    self.tooltip.showing = true
    self.tooltip.link = link
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
end

--- Hide the tooltip(s) created with :CreateTooltip() and :CreateHypertip()
function UI:HideTooltip()
    if self.tooltip then
        self.tooltip.showing = false
    end
    GameTooltip:Hide()
end

--- Used to decorate LibDialog Popups
function UI.DecoratePopup(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
                          bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                          edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                          tile     = true, tileSize = 8, edgeSize = 4,
                          insets   = { left = 2, right = 2, top = 2, bottom = 2 }
                      })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Embeds an error tooltip into a frame for use (as needed)
function UI.EmbedErrorTooltip(module, f)
    f.errorTooltip = CreateFrame( "GameTooltip", "R2D2_" .. module .. "_ErrorTooltip", nil, "GameTooltipTemplate" )
    f.content:SetScript("OnSizeChanged", function()
        f.errorTooltip:SetScale(f:GetScale() * 0.6)
    end)
end

function UI.UpdateErrorTooltip(f, errors)
    local tip = f.errorTooltip
    tip:SetOwner(f, "ANCHOR_LEFT")
    tip:AddLine(ColoredDecorator(0.77, 0.12, 0.23):decorate(L["errors"]))
    tip:AddLine(" ")
    local errorDeco = ColoredDecorator(1, 0.96, 0.41)
    for _, error in pairs(errors) do
        tip:AddLine(errorDeco:decorate(error))
    end
    tip:Show()
    tip:SetAnchorType("ANCHOR_LEFT", 0, -tip:GetHeight())
end

--[[
 Enable chain-calling for UI elements (for Ace3GUI)

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
        Logging:Trace("ChainFn() : Object = %s, Key = %s", type(obj), key)

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