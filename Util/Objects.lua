local _, AddOn = ...;
local Util      = AddOn.components.Util
local Self      = Util.Objects
local Functions = Util.Functions
local Tables    = Util.Tables

-- Check if two values are equal
function Self.Equals(a, b)
    return a == b
end

-- Check if the value is truthy (true, ~=0, ~="", ~=[])
---@param val any
function Self.IsSet(val)
    local t = type(val)
    return val
            and val ~= 0
            and not (t == "string" and val:trim() == "")
            and not (t == "table" and not next(t))
            and true or false
end

-- Check if the value is falsy (false, 0, "", [])
function Self.IsEmpty(val)
    return not Self.IsSet(val)
end


-- Return a when cond is true, b otherwise
---@generic T
---@param cond any
---@param a T
---@param b T
---@return T
function Self.Check(cond, a, b)
    if cond then return a else return b end
end

local EachFn = function (t, i)
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
        return EachFn, Tables.Temp(...)
    end
end

---@generic T, I
---@return function(t: T[], i: I): I, T
---@return T
---@return I
function Self.IEach(...)
    if ... and type(...) == "table" then
        return EachFn, ...
    else
        return Self.Each(...)
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


-- Get string representation of various object types
function Self.ToString(val, depth)
    depth = depth or 3
    local t = type(val)

    if t == "nil" then
        return "nil"
    elseif t == "table" then
        local fn = val.ToString or val.toString or val.tostring
        if depth == 0 then
            return "{...}"
        elseif type(fn) == "function" and fn ~= Self.ToString then
            return fn(val, depth)
        else
            local j = 1
            return Tables.FoldL(
                    val,
                    function (s, v, i)
                        if s ~= "{" then s = s .. ", " end
                        if i ~= j then s = s .. i .. " = " end
                        j = j + 1
                        return s .. Self.ToString(v, depth-1)
                    end,
                    "{", true
            ) .. "}"
        end
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "function" then
        return "(fn)"
    elseif t == "string" then
        return val
    else
        return val
    end
end
