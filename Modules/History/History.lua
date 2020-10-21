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
    Import      =   "impot",
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
    export:SetPoint("RIGHT", f.delete,  "LEFT", -10, 0)
    export:SetScript("OnClick", function() History.ExportFrame(module, f):Show() end)
    f.export = export

    local import = UI:CreateButton(L['import'], f.content)
    import:SetPoint("RIGHT", f.export, "LEFT", -10, 0)
    import:SetScript("OnClick", function() end)
    f.import = import
end

local function GetFrame(module, type, builder)
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


function History.ExportFrame(module, parent)
    local function CreateFrame()
        local f = UI:CreateFrame("R2D2_" .. module .. "_Export", module .. "Export", format(L["r2d2_history_export_frame"], Util.Strings.FromCamelCase(module)), 200, 275)
        f:SetWidth(700)
        f:SetHeight(360)
        f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 150)

        local group =
            UI('InlineGroup')
                .SetParent(f)
                .SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -5, 50)
                .SetPoint("TOPLEFT", f.content, "TOPLEFT", 17, 0)()
        f.group = group

        local edit =
            UI('MultiLineEditBox')
                .DisableButton(true)
                .SetFullWidth(true)
                .SetFullHeight(true)
                .SetNumLines(18)
                .SetLabel("")()
        group:AddChild(edit)
        edit.scrollFrame:UpdateScrollChildRect()
        f.edit = edit

        --local edit = UI('EditBox').SetWidth(f:GetWidth() - 25).SetHeight(f:GetHeight())()
        --local edit =
        --    UI('EditBox')
        --        .SetFullWidth(true)
        --        .SetLabel("")
        --        .SetMaxLetters(0)()
        --edit.button:Hide()
        --edit.frame:SetClipsChildren(true)

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

        local exportType =
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
        exportType:SetCallback(
                "OnValueChanged",
                function (_, _, key)
                    if Util.Objects.In(key, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) then
                        f.age.Show()
                    else
                        f.age.Hide()
                    end
                end
        )
        exportType:SetCallback(
                "OnEnter", function()
                    local localeKey = format('history_%s_desc', TypeToLocaleKey(TypeIdToProcess[exportType:GetValue()]))
                    UI:CreateHelpTooltip(exportType.button, "ANCHOR_RIGHT", L[localeKey])
                end
        )
        exportType:SetCallback("OnLeave", function() UI:HideTooltip() end)
        f.exportType = exportType

        local age =
            UI('EditBox')
                .SetPoint("LEFT", f.exportType.dropdown, "RIGHT", 10, 10)
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

        local close = UI:CreateButton(_G.CLOSE, f.content)
        close:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -13, 10)
        close:SetScript("OnClick", function() f:Hide() end)
        f.close = close

        local export = UI:CreateButton(L['execute'], f.content)
        export:SetPoint("RIGHT", f.close, "LEFT", -25)
        export:SetScript("OnClick",
                function()
                    local exportType = f.exportType:GetValue()
                    local export =
                        AddOn:GetModule(module):ExportHistory(
                                History.Iterator(
                                        module,
                                        exportType,
                                        Util.Objects.In(exportType, ProcessTypes.AgeOlder, ProcessTypes.AgeYounger) and tonumber(age:GetText())
                                )
                        )

                    f.edit:SetText(export)
                    f.edit.editBox:HighlightText()
                    f.edit:SetFocus()
                end)
        f.export = export

        f:Hide()
        return f
    end

    return GetFrame(module, FrameTypes.Export, CreateFrame)
end


function History.BulkDeleteFrame(module, parent)
    local function CreateFrame()
        local f = UI:CreateFrame("R2D2_" .. module .. "_BulkDelete", module .. "BulkDelete", format(L["r2d2_history_bulk_delete_frame"], Util.Strings.FromCamelCase(module)), 200, 275)
        f:SetWidth(425)
        f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 150)

        local close = UI:CreateButton(_G.CLOSE, f.content)
        close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -13, 10)
        close:SetScript("OnClick", function() f:Hide() end)
        f.close = close

        return f
    end

    return GetFrame(module, FrameTypes.BulkDelete, CreateFrame)
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