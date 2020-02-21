local _, namespace = ...;
local Util = namespace.components.Util

Util.Tables = {}

local Self = Util.Tables

-- Reusable tables
-- Store unused tables in a cache to reuse them later
--
-- A cache for temp tables
Self.TablePool = {}
Self.TablePoolSize = 10
-- For when we need an empty table as noop or special marking
Self.NIL = {}
-- For when we need to store nil values in a table
Self.EMPTY = {}

-- Get a table (newly created or from the cache), and fill it with values
function Self.New(...)
    local t = tremove(Self.TablePool) or {}
    for i=1, select("#", ...) do
        t[i] = select(i, ...)
    end
    return t
end

-- Get a table (newly created or from the cache), and fill it with key/value pairs
function Self.Hash(...)
    local t = tremove(Self.TablePool) or {}
    for i=1, select("#", ...), 2 do
        t[select(i, ...)] = select(i + 1, ...)
    end
    return t
end

-- Add one or more tables to the cache, first parameter can define a recursive depth
---@vararg table|boolean
function Self.Release(...)
    local depth = type(...) ~= "table" and (type(...) == "number" and max(0, (...)) or ... and Self.TablePoolSize) or 0

    for i=1, select("#", ...) do
        local t = select(i, ...)
        if type(t) == "table" and t ~= Self.EMPTY and t ~= Self.NIL then
            if #Self.TablePool < Self.TablePoolSize then
                tinsert(Self.TablePool, t)

                if depth > 0 then
                    for _,v in pairs(t) do
                        if type(v) == "table" then Self.Release(depth - 1, v) end
                    end
                end

                wipe(t)
                setmetatable(t, nil)
            else
                break
            end
        end
    end
end

-- Unpack and release a table
local Fn = function (t, ...) Self.Release(t) return ... end

---@param t table
function Self.Unpack(t)
    return Fn(t, unpack(t))
end


-- Temporary tables
-- temporary tables, which are automatically released after certain operations (such as loops)
function Self.Temp(...)
    local t = tremove(Self.TablePool) or {}
    for i=1, select("#", ...) do
        local v = select(i, ...)
        t[i] = v == nil and Self.NIL or v
    end
    return setmetatable(t, Self.EMPTY)
end

function Self.HashTemp(...)
    return setmetatable(Self.Hash(...), Self.EMPTY)
end

---@param t table
function Self.IsTemp(t)
    return getmetatable(t) == Self.EMPTY
end

---@vararg table
function Self.ReleaseTemp(...)
    for i=1, select("#", ...) do
        local t = select(i, ...)
        if type(t) == "table" and Self.IsTemp(t) then Self.Release(t) end
    end
end