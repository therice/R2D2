-- params is for passing functions directly to TestSetup in advance of loading files
-- [1] - Calling File
-- [2] - Prehook Functions
local params = {...}
local pl = require('pl.path')
local assert = require("luassert")
local say    = require("say")
local logFile

--
-- custom assertions start
--
local function less(state, arguments)
    return arguments[1] < arguments[2]
end

local function greater(state, arguments)
    return arguments[1] > arguments[2]
end

say:set_namespace("en")
say:set("assertion.less.positive", "Expected %s to be smaller than %s")
say:set("assertion.less.negative", "Expected %s to not be smaller than %s")
assert:register("assertion", "less", less, "assertion.less.positive", "assertion.less.negative")

say:set("assertion.greater.positive", "Expected %s to be greater than %s")
say:set("assertion.greater.negative", "Expected %s to not be greater than %s")
assert:register("assertion", "greater", greater, "assertion.greater.positive", "assertion.greater.negative")
--
-- custom assertions end
--

function Before()
    local caller = params[1]
    local path = pl.dirname(caller)
    local name = pl.basename(caller):match("(.*).lua$")
    print("Caller -> FILE(" .. caller .. ") PATH(" .. path .. ") NAME(" .. name .. ")")
    _G.R2D2_Testing = true
    logFile = io.open(pl.abspath(path) .. '/' .. name .. '.log', 'w')
    _G.R2D2_Testing_GetLogFile = function() return logFile end
end

function After()
    if logFile then
        logFile:close()
    end
    _G.R2D2_Testing = nil
end

Before()


function GetSize(tbl, includeIndices, includeKeys)
    local size = 0;

    includeIndices = (includeIndices == nil and true) or includeIndices
    includeKeys = (includeKeys == nil and true) or includeKeys

    if (includeIndices and includeKeys) then
        for _, _ in pairs(tbl) do
            size = size + 1
        end

    elseif (includeIndices and not includeKeys) then
        for _, _ in ipairs(tbl) do
            size = size + 1
        end
    elseif (not includeIndices and includeKeys) then
        for key, _ in pairs(tbl) do
            if (type(key) == "string") then
                size = size + 1
            end
        end
    end

    return size;
end

local thisDir = pl.abspath(debug.getinfo(1).source:match("@(.*)/.*.lua$"))
loadfile(thisDir .. '/WowAddonParser.lua')()
TestSetup(pl.abspath(thisDir .. '/../R2D2.toc'), params[2] or {})


