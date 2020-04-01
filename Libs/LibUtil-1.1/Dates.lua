local MAJOR_VERSION = "LibUtil-1.1"
local MINOR_VERSION = 11303

local lib, minor = LibStub(MAJOR_VERSION, true)
if not lib or next(lib.Numbers) or (minor or 0) > MINOR_VERSION then return end

local Util = lib
local Self = Util.Dates

-- calculates how long ago a given date (in the past) was from now
--
--@param date a string date in format of dd/mm/yyyy
--@return day, month, year
function Self.GetInterval(date)
    local d, m, y = strsplit("/", oldDate, 3)
    local sinceEpoch = time( {year = y, month = m, day = d, hour = 0} )
    local diff = date("*t", math.abs(time() - sinceEpoch))
    return diff.day - 1, diff.month - 1, diff.year - 1970
end