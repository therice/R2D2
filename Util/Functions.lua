local _, AddOn = ...;
local Util = AddOn.components.Util

Util.Functions = {}

local Self = Util.Functions

function Self.New(fn, obj) return type(fn) == "string" and (obj and obj[fn] or _G[fn]) or fn end
function Self.Noop() end