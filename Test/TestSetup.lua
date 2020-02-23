-- params is for passing functions directly to TestSetup in advance of loading files
-- [1] - Calling File
-- [2] - Prehook Functions
local params = {...}
local pl = require('pl.path')
local logFile

function Before()
    local caller = params[1]
    local path = pl.dirname(caller)
    local name = pl.basename(caller):match("(.*).lua$")
    print("Caller -> FILE(" .. caller .. ") PATH(" .. path .. ") NAME(" .. name .. ")")
    _G.R2D2_Testing = true
    logFile = io.open(pl.abspath('.') .. '/' .. name .. '.log', 'w')
    _G.R2D2_Testing_GetLogFile = function() return logFile end
end

function After()
    if logFile then
        logFile:close()
    end
    _G.R2D2_Testing = nil
end

Before()

local thisDir = pl.abspath(debug.getinfo(1).source:match("@(.*)/.*.lua$"))
loadfile(thisDir .. '/WowAddonParser.lua')()
TestSetup(pl.abspath(thisDir .. '/../R2D2.toc'), params[2] or {})


