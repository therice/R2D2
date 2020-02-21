local _, namespace = ...;
local Util = namespace.components.Util

Util.Strings = {}
local Self = Util.Strings

function Self.Capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2)
end