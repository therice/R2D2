-- params is for passing functions directly to TestSetup in advance of loading files
local params = {...}
local pl = require('pl.path')
local thisDir = pl.abspath(debug.getinfo(1).source:match("@(.*)/.*.lua$"))
loadfile(thisDir .. '/WowAddonParser.lua')()
TestSetup(pl.abspath(thisDir .. '/../R2D2.toc'), params[1])