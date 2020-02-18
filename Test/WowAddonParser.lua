local pl = require('pl.path')
local xml2lua = require("xml2lua")
-- handler that converts the XML to a LUA table
local handler = require("xmlhandler.dom")

local function findlast(s, pattern, plain)
    local curr = 0
    repeat
        local next = s:find(pattern, curr + 1, plain)
        if (next) then curr = next end
    until (not next)
    if (curr > 0) then
        return curr
    end
end

local function endswith(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

local function normalize(file)
    return file:gsub('\\', '/')
end

-- return absolute path to file
local function filename(dir, file)
    return normalize(dir .. '/' .. file)
end

-- returns absolute pathname of specified file
local function absolutepath(file)
    local normalized = normalize(file)
    local endAt = findlast(normalized, '/', true)
    return normalized:sub(1, endAt - 1)
end

local Addon = {
    toc = nil,
    attrs = {},
    files = {},
}
Addon.__index = Addon

setmetatable(Addon, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

function Addon:new(toc)
    return setmetatable({
        toc = toc,
        attrs = {},
        files = {},
    }, Addon)
end

function Addon:GetProperty(k, v)
    self.attrs[k] = v
end

function Addon:SetProperty(k, v)
    self.attrs[k] = v
end

function Addon:AddFile(f)
    table.insert(self.files, f)
end

function Addon:ResolveFiles(from, files, resolutions)
    from = from or absolutepath(self.toc)
    files = files or self.files
    resolutions = resolutions or {}

    --local rootPath = from
    -- print('Performing resolution from ' .. from)

    for _, file in pairs(files) do
        local resolvedFile =  filename(from, file)
        --print('Resolved ' .. file .. ' to ' .. resolvedFile)
        -- LUA extension, straight include
        if endswith(resolvedFile, '.lua') then
            table.insert(resolutions, resolvedFile)
        -- XML extension, resole again
        elseif endswith(resolvedFile, '.xml') then
            local rootPath = absolutepath(resolvedFile)
            --print('New root for resolution is ' .. rootPath)
            --print('Parsing ' .. resolvedFile)
            local parsed = ParseXml(resolvedFile)
            self:ResolveFiles(rootPath, parsed, resolutions)
        else
            error(format("Unable to handle %s", resolvedFile))
        end
    end

    return resolutions
end

function ParseXml(file)
    local wowXmlHandler = handler:new()
    local wowXmlParser = xml2lua.parser(wowXmlHandler)
    wowXmlParser:parse(xml2lua.loadFile(file))
    -- xml2lua.printable(wowXmlHandler.root)

    local parsed = {}
    for _, child in pairs(wowXmlHandler.root._children) do
        if type(child) == 'table' then
            table.insert(parsed, child["_attr"].file)
        end
    end
    return parsed
end

-- https://wow.gamepedia.com/TOC_format
function ParseTOC(toc)
    local file = assert(io.open(toc, "r"))
    local addon = Addon:new(toc)
    print('Parsing Add-On TOC @ ' .. toc)
    while true do
        local line = file:read()
        if line == nil then break end
        -- remove leading and trailing spaces
        line = line:match("^%s*(.-)%s*$")
        -- metadata
        if line:sub(1, 2) == '##' then
            local TagValue = line:match("##[ ]?(.*)")
            local Tag, Value = string.match(TagValue, "([^:]*):[ ]?(.*)")
            if Tag and Value then
                addon:SetProperty(Tag, Value)
            end
        -- comment or empty line
        elseif line:sub(1, 1) == '#' or line:len() == 0 then
            -- no-op
        else
            addon:AddFile(line)
        end
    end

    file:close()
    return addon
end

function TestSetup(toc, preload_functions)
    preload_functions = preload_functions or {}
    local addon = ParseTOC(toc)
    local load = addon:ResolveFiles()

    -- insert non-addon files needing for testing
    local thisDir = pl.abspath(debug.getinfo(1).source:match("@(.*)/.*.lua$"))
    table.insert(load, 1, thisDir .. '/WowApi.lua')

    local loadedFileCount = 1

    for _, toload in pairs(load) do
        print('Loading File -> ' .. toload)
        loadfile(toload)()
        -- after we load the Wow API, call any specified loader functions
        if loadedFileCount == 1 then
            for _, f in pairs(preload_functions) do f() end
        end
        loadedFileCount = loadedFileCount + 1
    end
end

