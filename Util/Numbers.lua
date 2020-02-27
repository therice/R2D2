local _, AddOn = ...;
local Util = AddOn.components.Util
local Self = Util.Numbers

-- Rounds a number
function Self.Round(num, p)
    p = math.pow(10, p or 0)
    return floor(num * p + .5) / p
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