local _, AddOn = ...;
local Util      = AddOn.components.Util
local Self      = Util.Tables
local Functions = Util.Functions
local pairs, type, table = pairs, type, table


-- Get table keys
---@param t table
---@return table
function Self.Keys(t)
    local u = Self.New()
    for i,v in pairs(t) do tinsert(u, i) end
    return u
end

-- Get table values as continuously indexed list
---@param t table
---@return table
function Self.Values(t)
    local u = Self.New()
    for i,v in pairs(t) do tinsert(u, v) end
    return u
end

-- Copy a table and optionally apply a function to every entry
---@param fn function
---@param index boolean
---@param notVal boolean
function Self.Copy(t, fn, index, notVal, ...)
    local fn, u = Functions.New(fn), Self.New()
    for i,v in pairs(t) do
        if fn then
            u[i] = Functions.Call(fn, v, i, index, notVal, ...)
        else
            u[i] = v
        end
    end
    return u
end

-- Good old FoldLeft
---@param t table
---@param u any
function Self.FoldL(t, fn, u, index, ...)
    fn, u = Functions.New(fn), u or Self.New()
    for i,v in pairs(t) do
        if index then
            u = fn(u, v, i, ...)
        else
            u = fn(u, v, ...)
        end
    end
    return u
end

-- Sort a table
local SortFn = function (a, b) return a > b end
function Self.Sort(t, fn)
    fn = fn == true and SortFn or Functions.New(fn) or nil
    table.sort(t, fn)
    return t
end

-- Copy a table and optionally apply a function to every entry
---@param fn function
---@param index boolean
---@param notVal boolean
function Self.Copy(t, fn, index, notVal, ...)
    local fn, u = Functions.New(fn), Self.New()
    for i,v in pairs(t) do
        if fn then
            u[i] = Functions.Call(fn, v, i, index, notVal, ...)
        else
            u[i] = v
        end
    end
    return u
end


-- Omit specific keys from a table
function Self.CopyUnselect(t, ...)
    local u = Self.New()
    for i,v in pairs(t) do
        if not Util.In(i, ...) then
            u[i] = v
        end
    end
    return u
end


---@return number
function Self.Count(t)
    return Self.FoldL(t, Functions.Inc, 0)
end


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