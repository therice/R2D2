local _, namespace = ...;
local Util = namespace.components.Util

Util.Numbers = {}

local Self = Util.Numbers

-- Rounds a number
function Self.Round(num, p)
    p = math.pow(10, p or 0)
    return floor(num * p + .5) / p
end
