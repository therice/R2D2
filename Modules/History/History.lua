local _, AddOn = ...
local Util = AddOn.Libs.Util
local Logging = AddOn.components.Logging
local L = AddOn.components.Locale
local UI = AddOn.components.UI
local Date = AddOn.components.Models.Date

local History = {}
AddOn.components.History = History

local FrameTypes = {
    BulkDelete  =   "bulk_delete",
    Export      =   "export",
    Import      =   "import",
}

-- if the keys change, update the translations
local ProcessTypes = {
    AgeOlder    =   1,
    AgeYounger  =   2,
    All         =   3,
    Filtered    =   4,
    Selection   =   5,
}
local TypeIdToProcess = tInvert(ProcessTypes)

History.ProcessTypes = ProcessTypes
History.TypeIdToProcess = TypeIdToProcess


local uh, queue = CreateFrame("FRAME", "History_UpdateHandler_Frame"), {}
uh.elapsed = 0.0
uh.interval = 1
uh.processing = false
uh:SetScript(
        'OnUpdate',
        function(self, elapsed)
            Logging:Trace("History.UpdateHandler.OnUpdate(%.2f) : elapsed=%.2f, interval=%.2f, processing=%s", elapsed, self.elapsed, self.interval, tostring(self.processing))

            self.elapsed = self.elapsed + elapsed
            -- we don't use the high precision approach as this isn't meant to be executed
            -- frequently
            --[[
            while (self.elapsed > self.interval) do
                -- code to execute
                self.elapsed = self.elapsed - self.interval
            end
            --]]

            if not self.processing and self.elapsed > self.interval then
                local f = Util.Tables.Pop(queue)
                if f then
                    self.processing = true
                    local check, _ = pcall(function() return f() end)
                    if not check then
                        Logging:Warn("History.UpdateHandler.OnUpdate() : function call failed")
                    end
                    self.processing = false
                end

                -- setting this after last execution, means that interval is only with respect
                -- to last execution finishing or being attempted
                self.elapsed = 0.0

                if Util.Tables.IsEmpty(queue) then
                    Logging:Trace("History.UpdateHandler.OnUpdate(): nothing more to process, hiding")
                    self:Hide()
                end
            end
        end
)
uh:Hide()

local function EnqueueOperation(f)
    Util.Tables.Push(queue, f)
    if not uh:IsShown() then
        uh:Show()
    end
end

local frames = {}
--@param module the module name
--@param f the frame to which to add buttons
function History.EmbedActionButtons(module, f)
    local delete = UI:CreateButton(L['bulk_delete'], f.content)
    if f.close then
        delete:SetPoint("TOPRIGHT", f.close, "TOPRIGHT", 0, 35)
    else
        delete:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -65)
    end
    delete:SetScript("OnClick", function() History.BulkDeleteFrame(module, f):Show() end)
    f.delete = delete

    local export = UI:CreateButton(L['export'], f.content)
    export:SetPoint("RIGHT", f.delete, "LEFT", -10, 0)
    export:SetScript("OnClick", function() History.ExportFrame(module, f):Show() end)
    f.export = export

    local import = UI:CreateButton(L['import'], f.content)
    import:SetPoint("RIGHT", f.export, "LEFT", -10, 0)
    import:SetScript("OnClick", function() History.ImportFrame(module, f):Show() end)
    f.import = import
end

local function GetHistoryFrame(module, type, builder)
    Logging:Debug("GetFrame(%s, %s)", module, type)

    local moduleFrames = frames[module]
    if not moduleFrames then
        moduleFrames = {}
        frames[module] = moduleFrames
    end

    local frame = moduleFrames[type]
    if not frame then
        Logging:Debug("GetFrame(%s, %s) : instantiating frame", module, type)
        frame = builder()
        moduleFrames[type] = frame
    end

    Logging:Debug("GetFrame(%s, %s) : %s", module, type, frame and frame:GetName() or 'nil')

    return frame
end


local function CreateHistoryFrame(module, parent, type)
    Logging:Debug("CreateFrame(%s) : %s", module, Util.Objects.ToString(type))

    local titleTranslationKey = format('r2d2_history_%s_frame', type)
    local suffix = Util.Strings.UcFirst(Util.Strings.ToCamelCase(type, "_"))

    local f = UI:CreateFrame(format("R2D2_%s_%s", module, suffix), format("%s%s", module, suffix), format(L[titleTranslationKey], Util.Strings.FromCamelCase(module)), 200, 275)
    f:SetWidth(700)
    f:SetHeight(360)
    f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 150)

    if Util.Objects.In(type, FrameTypes.Export, FrameTypes.Import) then
        local group =
            UI('InlineGroup')
                    .SetParent(f)
                    .SetLayout('fill')
                    .SetPoint("TOPLEFT", f.content, "TOPLEFT", 17, 0)
                    .SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -17, 70)()
        f.group = group

        local edit =
            UI('MultiLineEditBox')
                    .DisableButton(true)
                    .SetFullWidth(true)
                    .SetFullHeight(true)
                    --.SetNumLines(18)
                    .SetLabel("")()
        group:AddChild(edit)
        edit.scrollFrame:UpdateScrollChildRect()
        f.edit = edit
        function f.edit.Reset() f.edit:SetText("") end
    elseif type == FrameTypes.BulkDelete then
        local function ScrollingFunction(self, arg)
            if arg > 0 then
                if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
            elseif arg < 0 then
                if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
            end
        end

        -- The scrolling message frame with all the debug info.
        local edit = CreateFrame("ScrollingMessageFrame", nil, f.content)
        edit:SetMaxLines(10000)
        edit:SetFading(false)
        edit:SetFontObject(GameFontHighlightLeft)
        edit:EnableMouseWheel(true)
        edit:SetTextCopyable(true)
        edit:SetBackdrop(
                {
                    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile     = true, tileSize = 8, edgeSize = 4,
                    insets   = { left = 2, right = 2, top = 2, bottom = 2 }
                }
        )
        edit:SetPoint("TOPLEFT", f.content, "TOPLEFT", 5, -10)
        edit:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -5, 70)
        edit:SetScript("OnMouseWheel", ScrollingFunction)
        f.edit = edit
        function f.edit.Reset() f.edit:Clear() end
    end

    local statusBar = CreateFrame("StatusBar", nil, f.content, "TextStatusBar")
    statusBar:SetSize((f.group and f.group.frame or f.edit):GetWidth() - 20, 15)
    statusBar:SetPoint("TOPLEFT", f.group and f.group.frame or f.edit, "BOTTOMLEFT")
    statusBar:SetPoint("TOPRIGHT", f.group and f.group.frame or f.edit, "BOTTOMRIGHT")
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.1, 0, 0.6, 0.8)
    statusBar:SetMinMaxValues(0, 100)
    statusBar:Hide()
    f.statusBar = statusBar

    statusBar.text = f.statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusBar.text:SetPoint("CENTER", f.statusBar)
    statusBar.text:SetTextColor(1,1,1)
    statusBar.text:SetText("")

    function f.statusBar.Reset()
        f.statusBar:Hide()
        f.statusBar.text:Hide()
    end

    function f.statusBar.Update(value, text)
        f.statusBar:Show()
        if tonumber(value) then f.statusBar:SetValue(value) end
        f.statusBar.text:Show()
        f.statusBar.text:SetText(text)
    end

    local function TypeToLocaleKey(v)
        return Util.Strings.Lower(
                Util.Strings.Join('_',
                        Util.Strings.Split(
                                Util.Strings.FromCamelCase(v),
                                ' '
                        )
                )
        )
    end

    if Util.Objects.In(type, FrameTypes.Export, FrameTypes.BulkDelete) then
        local typedd =
                UI('Dropdown')
                        .SetPoint("BOTTOMLEFT", f.content, "BOTTOMLEFT", 17, 10)
                        .SetList(
                        Util(TypeIdToProcess):Copy()
                                             :Map(function (v) return L[format('history_%s', TypeToLocaleKey(v))] end)()
                )
                .SetWidth(100)
                .SetValue(ProcessTypes.Filtered)
                .SetLabel(L['type'])
                .SetParent(f)()
        typedd:SetCallback(
                "OnValueChanged",
                function (_, _, key)
                    if Util.Objects.In(key, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) then
                        f.age.Show()
                    else
                        f.age.Hide()
                    end
                end
        )
        typedd:SetCallback(
                "OnEnter", function()
                    local localeKey = format('history_%s_desc', TypeToLocaleKey(TypeIdToProcess[typedd:GetValue()]))
                    UI:CreateHelpTooltip(typedd.button, "ANCHOR_RIGHT", L[localeKey])
                end
        )
        typedd:SetCallback("OnLeave", function() UI:HideTooltip() end)
        f.type = typedd

        local age =
            UI('EditBox')
                    .SetPoint("LEFT", f.type.dropdown, "RIGHT", 10, 10)
                    .SetParent(f)
                    .SetLabel("Days")
                    .DisableButton(true)
                    .SetWidth(100)()
        age.Hide = function() f.age.frame:Hide() end
        age.Show = function() f.age.frame:Show() end
        age:SetCallback("OnEnter", function() UI:CreateHelpTooltip(age.editbox, "ANCHOR_RIGHT", L['history_days_description']) end)
        age:SetCallback("OnLeave", function() UI:HideTooltip() end)
        age.editbox:SetNumeric(true)
        f.age = age
    end

    local close = UI:CreateButton(_G.CLOSE, f.content)
    close:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -13, 10)
    close:SetScript(
            "OnClick",
            function()
                f.edit.Reset()
                f.statusBar.Reset()
                f:Hide()
            end
    )
    f.close = close

    local execute = UI:CreateButton(L['execute'], f.content)
    execute:SetPoint("RIGHT", f.close, "LEFT", -25)
    execute:SetScript(
            "OnEnter", function()
                Logging:Debug("OnEnter")
                UI:CreateHelpTooltip(execute, "ANCHOR_RIGHT", L['history_warning'])
            end
    )
    execute:SetScript("OnLeave", function() UI:HideTooltip() end)
    f.execute = execute

    f:Hide()
    return f
end

function History.ExportFrame(module, parent)
    local function CreateExportFrame()
        local f = CreateHistoryFrame(module, parent, FrameTypes.Export)
        local function ExportExecute()
            local type, exported = f.type:GetValue(), 0
            local export = AddOn:GetModule(module):ExportHistory(
                    History.Iterator(
                            module,
                            type,
                            Util.Objects.In(type, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) and tonumber(f.age:GetText())
                    ),
                    function(v)
                        exported = exported + 1
                    end
            )

            f.statusBar.Update(100, format("Exported %d entries", exported))
            f.edit:SetText(export)
            f.edit.editBox:HighlightText()
            f.edit:SetFocus()
            f.execute:Enable()
        end

        f.execute:SetScript(
                "OnClick",
                function()
                    f.edit.Reset()
                    f.statusBar.Reset()
                    f.execute:Disable()
                    EnqueueOperation(ExportExecute)
                end
        )
        return f
    end

    return GetHistoryFrame(module, FrameTypes.Export, CreateExportFrame)
end

function History.ImportFrame(module, parent)
    local function CreateImportFrame()
        local f = CreateHistoryFrame(module, parent, FrameTypes.Import)
        return f
    end

    return GetHistoryFrame(module, FrameTypes.Import, CreateImportFrame)
end

function History.BulkDeleteFrame(module, parent)
    local function CreateBulkDeleteFrame()
        local f = CreateHistoryFrame(module, parent, FrameTypes.BulkDelete)
        local function BulkDeleteExecute()
            local type, deleted = f.type:GetValue(), 0
            AddOn:GetModule(module):DeleteHistory(
                    History.Iterator(
                            module,
                            type,
                            Util.Objects.In(type, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) and tonumber(f.age:GetText())
                    ),
                    function(v)
                        deleted = deleted + 1
                        f.edit:AddMessage(format("%s %s", L['deleted'], v:Description()))
                    end
            )
            f.statusBar.Update(100, format(L['deleted_n'], deleted))
            f.execute:Enable()
        end

        f.execute:SetScript(
                "OnClick",
                function()
                    f.edit.Reset()
                    f.statusBar.Reset()
                    f.execute:Disable()
                    EnqueueOperation(BulkDeleteExecute)
                end
        )

        return f
    end

    return GetHistoryFrame(module, FrameTypes.BulkDelete, CreateBulkDeleteFrame)
end

function History.Iterator(module, type, ...)
    Logging:Debug("Iterator(%s, %d)", module, type)

    local supplier
    local m = AddOn:GetModule(module)

    -- supplier that only yields rows with number in passed ids
    local RowIdSupplier = function(ids)
        local function iter(t, i)
            i = i + 1
            local v = ids[i]
            if v ~= nil then return i, t[v] end
        end

        return iter, m.frame.rows, 0
    end

    -- supplier that only yields rows which meet age criteria
    local AgeSupplier = function(type, days)
        local cutoff = Date()
        cutoff:hour(00)
        cutoff:min(00)
        cutoff:sec(00)
        cutoff:add{day = -days}

        return Util.Functions.Filter(
                function(_, v)
                    local ts = Date(v.entry.timestamp)
                    if type == ProcessTypes.AgeOlder then
                        return ts <= cutoff
                    elseif type == ProcessTypes.AgeYounger then
                        return ts >= cutoff
                    else
                        return false
                    end
                end,
                pairs(m.frame.rows)
        )
    end

    if type == ProcessTypes.Filtered then
        local filtered = m.frame.st.filtered
        -- not required, but helps with test cases verifying deletion of appropriate rows
        Util.Tables.Shuffle(filtered)
        Logging:Debug("Iterator(%s) : Filtered = %s", module, Util.Objects.ToString(filtered))
        supplier = function() return RowIdSupplier(filtered) end
    elseif type == ProcessTypes.Selection then
        local selection = m.frame.st:GetSelection()
        Logging:Debug("Iterator(%s) : Selection = %s", module, Util.Objects.ToString(m.frame.st:GetSelection()))
        supplier = function() return RowIdSupplier({ selection }) end
    elseif Util.Objects.In(type, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) then
        -- expect one argument which is a number to delete older than
        local days = select(1, ...)
        Logging:Debug("Iterator(%s) : %s than %s days", module, type == ProcessTypes.AgeOlder and "older" or "younger", tostring(days))
        if Util.Objects.IsNumber(days) then
            supplier = function() return AgeSupplier(type, days) end
        else
            -- todo : raise error
            supplier = function() return pairs({}) end
        end
    elseif type == ProcessTypes.All then
        Logging:Debug("Iterator(%s) : All (%d)", module, #m.frame.rows)
        supplier = function() return pairs(m.frame.rows) end
    end

    return supplier
end

local Compression = AddOn.Libs.Util.Compression
local Compressors = Compression.GetCompressors(Compression.CompressorType.LibDeflate)
local Base64 = AddOn.Libs.Base64
local MaxExportSizeUncompressed = 40000

function History.ToJson(history)
    local start = debugprofilestop()
    local json = AddOn.Libs.JSON:Encode(history, nil, {pretty = true, indent = "  "})
    Logging:Debug("ToJson(JSON) : %s length %d ms elapsed", json:len(), debugprofilestop() - start)

    if json:len() > MaxExportSizeUncompressed then
        start = debugprofilestop()
        local compressed = Compressors[1]:compress(json, true)
        Logging:Debug("ToJson(COMPRESS) : %s length %d ms elapsed", compressed:len(), debugprofilestop() - start)

        start = debugprofilestop()
        local encoded = Base64:Encode(compressed)
        Logging:Debug("ToJson(Base64) : %s length %d ms elapsed", encoded:len(), debugprofilestop() - start)

        return encoded
    else
        return json
    end
end

function History.FromJson(json)
    if Base64:IsBase64(json) then
        Logging:Debug("FromJson() : Value is encoded and compressed, converting to JSON")
        local decoded = Base64:Decode(json)
        json = Compressors[1]:decompress(decoded, true)
    end

    return AddOn.Libs.JSON:Decode(json)
end

function History.Import(module, data)
    local table = History.FromJson(data)
    Logging:Debug("Import(%s) : count=%d", module, Util.Tables.Count(table))
    local m = AddOn:GetModule(module)
    m:ImportHistory(table)
end