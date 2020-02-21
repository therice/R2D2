local _, namespace = ...;
local Util = namespace.components.Util

Util.Objects = {}

local Self = Util.Objects
local Functions = Util.Functions
local Tables = Util.Tables

-- Return a when cond is true, b otherwise
---@generic T
---@param cond any
---@param a T
---@param b T
---@return T
function Self.Check(cond, a, b)
    if cond then return a else return b end
end

local Fn = function (t, i)
    i = (i or 0) + 1
    if i > #t then
        Tables.ReleaseTemp(t)
    else
        local v = t[i]
        return i, Self.Check(v == Tables.NIL, nil, v)
    end
end

---@generic T, I
---@return function(t: T[], i: I): I, T
---@return T
---@return I
function Self.Each(...)
    if ... and type(...) == "table" then
        return next, ...
    elseif select("#", ...) == 0 then
        return Functions.Noop
    else
        return Fn, Tables.Temp(...)
    end
end


-- Shortcut for val == x or val == y or ...
---@param val any
---@return boolean
function Self.In(val, ...)
    for _,v in Self.Each(...) do
        if v == val then return true end
    end
    return false
end
