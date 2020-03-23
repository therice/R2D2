
local MAJOR_VERSION = "LibUtil-1.1"
local MINOR_VERSION = 11303

local lib, minor = LibStub(MAJOR_VERSION, true)
if not lib or next(lib.Numbers) or (minor or 0) > MINOR_VERSION then return end

local Util = lib
local Self = Util.Numbers


-- Rounds a number
function Self.Round(num, p)
    p = math.pow(10, p or 0)
    return floor(num * p + .5) / p
end

function Self.Round2(num, p)
    if type(num) ~= "number" then return nil end
    return tonumber(string.format("%." .. (p or 0) .. "f", num))
end

-- Check if num is in interval (exclusive)
---@param num number
---@param a number
---@param b number
function Self.Between(num, a, b)
    return num > a and num < b
end

-- Check if num is in interval (inclusive)
function Self.In(num, a, b)
    return num >= a and num <= b
end

---@param num number
---@param minLength number
function Self.ToHex(num, minLength)
    return ("%." .. (minLength or 1) .. "x"):format(num)
end