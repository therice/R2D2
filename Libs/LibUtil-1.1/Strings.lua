local MAJOR_VERSION = "LibUtil-1.1"
local MINOR_VERSION = 11303

local lib, minor = LibStub(MAJOR_VERSION, true)
if not lib or next(lib.Strings) or (minor or 0) > MINOR_VERSION then return end

local Util = lib
local Self = Util.Strings

-------------------------------------------------------
--                       String                      --
-------------------------------------------------------

---@return boolean
function Self.IsSet(str)
    return str and type(str) == "string" and str:trim() ~= ""
end

---@param str string
function Self.IsEmpty(str)
    return not Self.IsSet(str)
end

---@param str string
function Self.StartsWith(str, str2)
    return type(str) == "string" and str:sub(1, str2:len()) == str2
end

---@param str string
---@param str2 string
function Self.EndsWith(str, str2)
    return type(str) == "string" and str:sub(-str2:len()) == str2
end

function Self.Wrap(str, before, after)
    if Self.IsEmpty(str) then
        return ""
    end

    return (before or " ") .. str .. (after or before or " ")
end

function Self.Prefix(str, prefix)
    return Self.Wrap(str, prefix, "")
end

function Self.Postfix(str, postfix)
    return Self.Wrap(str, "", postfix)
end

-- Split string on delimiter
function Self.Split(str, del)
    local t = Util.Tables.New()
    for v in (str .. del):gmatch("(.-)" .. del:gsub(".", "%%%1")) do
        tinsert(t, v)
    end
    return t
end

-- Join a bunch of strings with given delimiter
---@vararg string
function Self.Join(del, ...)
    local s = ""
    for _,v in Util.Each(...) do
        if not Self.IsEmpty(v) then
            s = s .. (s == "" and "" or del or " ") .. v
        end
    end
    return s
end

-- Uppercase only if language supports letter casing
---@param str string
---@param locale string
function Self.UcLang(str, locale)
    return Util.In(locale or GetLocale(), "koKR", "zhCN", "zhTW") and str or str:upper()
end

-- Lowercase only if language supports letter casing
---@param str string
---@param locale string
function Self.LcLang(str, locale)
    return Util.In(locale or GetLocale(), "koKR", "zhCN", "zhTW") and str or str:lower()
end

-- Uppercase first char
---@param str string
---@param locale string
function Self.UcFirst(str, locale)
    return str:sub(1, 1):upper() .. str:sub(2)
end

-- Lowercase first char
---@param str string
---@param locale string
---@return string
function Self.LcFirst(str, locale)
    return str:sub(1, 1):lower() .. str:sub(2)
end

function Self.Lower(str)
    return string.lower(str or "")
end

function Self.IsLower(s)
    return (s == Self.Lower(s))
end

function Self.Upper(str)
    return string.upper(str or "")
end

function Self.IsUpper(s)
    return (s == Self.Upper(s))
end

-- Check if string is a number
---@param str string
---@param leadingZero boolean
function Self.IsNumber2(str, leadingZero)
    return tonumber(str) and (leadingZero or not Self.StartsWith(str, "0"))
end

function Self.IsNumber(str)
    return type(str) == 'string' and tonumber(str) ~= nil
end

-- Get abbreviation of given length
---@param str string
function Self.Abbr(str, length)
    return str:len() <= length and str or str:sub(1, length) .. "..."
end

---@param a number
function Self.Color(r, g, b, a)
    return ("%.2x%.2x%.2x%.2x"):format((a or 1) * 255, (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

---@param str string
---@param from integer
---@param len integer
---@param sub string
function Self.Replace(str, from, len, sub)
    from, len, sub = from or 1, len or str:len(), sub or ""
    local to = from < 0 and str:len() + from + len + 1 or from + len
    return str:sub(1, from - 1) .. sub .. str:sub(to)
end

---@param str string
---@param del string
function Self.ToCamelCase(str, del)
    local s = ""
    for v in str:gmatch("[^" .. (del or "%p%s") .. "]+") do
        s = s .. Self.UcFirst(v:lower())
    end
    return Self.LcFirst(s)
end

---@param str string
---@param del string
function Self.FromCamelCase(str, del, case)
    local s = str:gsub("%u", (del or " ") .. "%1")
    return case == true and s:upper() or case == false and s:lower() or s
end

-- Get string representation values for dumping
---@param val any
---@param depth integer
---@return string
function Self.ToString(val, depth)
    return Util.Objects.ToString(val, depth)
end

function Self.Escape(s)
    return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'))
end
