local frames = {} -- Stores globally created frames, and their internal properties.

local FrameClass = {} -- A class for creating frames.

FrameClass.methods = {
	"SetScript", "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "Show", "Hide", "IsShown",
	"ClearAllPoints", "SetParent", "GetName", "SetOwner", "SetHyperlink", "NumLines"
}

function FrameClass:New(name)
	local frame = {}
	for _,method in ipairs(self.methods) do
		frame[method] = self[method]
	end
	local frameProps = {
		events = {},
		scripts = {},
		timer = GetTime(),
		name = name,
		isShow = true,
		parent = nil,
	}
	return frame, frameProps
end

function FrameClass:SetScript(script,handler)
	frames[self].scripts[script] = handler
end

function FrameClass:RegisterEvent(event)
	frames[self].events[event] = true
end

function FrameClass:UnregisterEvent(event)
	frames[self].events[event] = nil
end

function FrameClass:UnregisterAllEvents(frame)
	for event in pairs(frames[self].events) do
		frames[self].events[event] = nil
	end
end

function FrameClass:Show()
	frames[self].isShow = true
end

function FrameClass:Hide()
	frames[self].isShow = false
end

function FrameClass:IsShown()
	return frames[self].isShow
end

function FrameClass:ClearAllPoints()

end

function FrameClass:SetParent(parent)
	frames[self].parent = parent
end

function FrameClass:GetName()
	return frames[self].name
end

function FrameClass:SetOwner(owner, anchor)

end

function FrameClass:SetHyperlink(link)

end

function FrameClass:NumLines()
	return 0
end

function CreateFrame(kind, name, parent)
	local frame,internal = FrameClass:New(name)
	internal.parent = parent
	frames[frame] = internal
	if name then
		_G[name] = frame
	end
	return frame
end

function UnitName(unit)
	return unit
end

function GetRealmName()
	return "Realm Name"
end

function GetCurrentRegion()
	return 1 -- "US"
end

function UnitClass(unit)
	return "Warrior", "WARRIOR"
end

function UnitHealthMax()
	return 100
end

function UnitHealth()
	return 50
end

function GetNumRaidMembers()
	return 1
end

function GetNumPartyMembers()
	return 1
end

FACTION_HORDE = "Horde"
FACTION_ALLIANCE = "Alliance"

function UnitFactionGroup(unit)
	return "Horde", "Horde"
end

function UnitRace(unit)
	return "Undead", "Scourge"
end


_time = 0
function GetTime()
	return _time
end

function IsAddOnLoaded() return nil end

SlashCmdList = {}

function __WOW_Input(text)
	local a,b = string.find(text, "^/%w+")
	local arg, text = string.sub(text, a,b), string.sub(text, b + 2)
	for k,handler in pairs(SlashCmdList) do
		local i = 0
		while true do
			i = i + 1
			if not _G["SLASH_" .. k .. i] then
				break
			elseif _G["SLASH_" .. k .. i] == arg then
				handler(text)
				return
			end
		end
	end;
	print("No command found:", text)
end

local ChatFrameTemplate = {
	AddMessage = function(self, text)
		print((string.gsub(text, "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")))
	end
}

for i=1,7 do
	local f = {}
	for k,v in pairs(ChatFrameTemplate) do
		f[k] = v
	end
	_G["ChatFrame"..i] = f
end
DEFAULT_CHAT_FRAME = ChatFrame1

debugstack = debug.traceback
date = os.date

local wow_api_locale = 'enUS'
function GetLocale()
	return wow_api_locale
end

function SetLocale(locale)
	wow_api_locale = locale
end

function GetAddOnInfo()
	return
end

function GetNumAddOns()
	return 0
end

function getglobal(k)
	return _G[k]
end

function setglobal(k, v)
	_G[k] = v
end

local function _errorhandler(msg)
	print("--------- geterrorhandler error -------\n"..msg.."\n-----end error-----\n")
end

function geterrorhandler()
	return _errorhandler
end

function InCombatLockdown()
	return false
end

function IsLoggedIn()
	return false
end

function GetFramerate()
	return 60
end

function GetCVar(var)
	return "test"
end

time = os.clock

strmatch = string.match

function SendChatMessage(text, chattype, language, destination)
	assert(#text<255)
	WoWAPI_FireEvent("CHAT_MSG_"..strupper(chattype), text, "Sender", language or "Common")
end

local registeredPrefixes = {}
function RegisterAddonMessagePrefix(prefix)
	assert(#prefix<=16)	-- tested, 16 works /mikk, 20110327
	registeredPrefixes[prefix] = true
end

function SendAddonMessage(prefix, message, distribution, target)
	if RegisterAddonMessagePrefix then --4.1+
		assert(#message <= 255,
		       string.format("SendAddonMessage: message too long (%d bytes > 255)",
				     #message))
		-- CHAT_MSG_ADDON(prefix, message, distribution, sender)
		WoWAPI_FireEvent("CHAT_MSG_ADDON", prefix, message, distribution, "Sender")
	else -- allow RegisterAddonMessagePrefix to be nilled out to emulate pre-4.1
		assert(#prefix + #message < 255,
		       string.format("SendAddonMessage: message too long (%d bytes)",
				     #prefix + #message))
		-- CHAT_MSG_ADDON(prefix, message, distribution, sender)
		WoWAPI_FireEvent("CHAT_MSG_ADDON", prefix, message, distribution, "Sender")
	end
end

if not wipe then
	function wipe(tbl)
		for k in pairs(tbl) do
			tbl[k]=nil
		end
	end
end

function hooksecurefunc(func_name, post_hook_func)
	local orig_func = _G[func_name]
	assert(type(orig_func)=="function")

	_G[func_name] = function (...)
				local ret = { orig_func(...) }		-- yeahyeah wasteful, see if i care, it's a test framework
				post_hook_func(...)
				return unpack(ret)
			end
end

RED_FONT_COLOR_CODE = ""
GREEN_FONT_COLOR_CODE = ""

StaticPopupDialogs = {}

function WoWAPI_FireEvent(event,...)
	for frame, props in pairs(frames) do
		if props.events[event] then
			if props.scripts["OnEvent"] then
				for i=1,select('#',...) do
					_G["arg"..i] = select(i,...)
				end
				_G.event=event
				props.scripts["OnEvent"](frame,event,...)
			end
		end
	end
end

function WoWAPI_FireUpdate(forceNow)
	if forceNow then
		_time = forceNow
	end
	local now = GetTime()
	for frame,props in pairs(frames) do
		if props.isShow and props.scripts.OnUpdate then
			if now == 0 then
				props.timer = 0	-- reset back in case we reset the clock for more testing
			end
			_G.arg1=now-props.timer
			props.scripts.OnUpdate(frame,now-props.timer)
			props.timer = now
		end
	end
end


-- utility function for "dumping" a number of arguments (return a string representation of them)
function dump(...)
	local t = {}
	for i=1,select("#", ...) do
		local v = select(i, ...)
		if type(v)=="string" then
			tinsert(t, string.format("%q", v))
		elseif type(v)=="table" then
			tinsert(t, tostring(v).." #"..#v)
		else
			tinsert(t, tostring(v))
		end
	end
	return "<"..table.concat(t, "> <")..">"
end

-----

UIParent = {}

-- define required function pointers in global space which won't be available in testing
_G.format = string.format
-- https://wowwiki.fandom.com/wiki/API_debugstack
-- debugstack([thread, ][start[, count1[, count2]]]])
-- ignoring count2 currently (lines at end)
_G.debugstack = function (start, count1, count2)
	-- UGH => https://lua-l.lua.narkive.com/ebUKEGpe/confused-by-lua-reference-manual-5-3-and-debug-traceback
	-- If message is present but is neither a string nor nil, this function returns message without further processing.
	-- Otherwise, it returns a string with a traceback of the call stack. An optional message string is appended at the
	-- beginning of the traceback. An optional level number tells at which level to start the traceback
	-- (default is 1, the function calling traceback).
	local stack = debug.traceback()
	local chunks = {}
	for chunk in stack:gmatch("([^\n]*)\n?") do
		-- remove leading and trailing spaces
		local stripped = string.gsub(chunk, '^%s*(.-)%s*$', '%1')
		table.insert(chunks, stripped)
	end

	-- skip first line that looks like 'stack traceback:'
	local start_idx = math.min(start + 2, #chunks)
	-- where to stop, it's the start index + count1 - 1 (to account for counting line where we start)
	local end_idx = math.min(start_idx + count1 - 1, #chunks)
	return table.concat(chunks, '\n', start_idx, end_idx)
end
_G.strmatch = string.match
_G.date = os.date
_G.time = os.time
-- https://wowwiki.fandom.com/wiki/API_strsplit
-- A list of strings. Not a table. If the delimiter is not found in the string, the whole subject string will be returned.
_G.strsplit = function(delimiter, str, max)
	local record = {}
	if string.len(str) > 0 then
		max = max or -1

		local field, start = 1, 1
		local first, last = string.find(str, delimiter, start, true)
		while first and max ~= 0 do
			record[field] = string.sub(str, start, first -1)
			field = field +1
			start = last +1
			first, last = string.find(str, delimiter, start, true)
			max = max -1
		end
		record[field] = string.sub(str, start)
	end

	return record
end
-- https://wowwiki.fandom.com/wiki/API_GetItemInfo
-- https://wowwiki.fandom.com/wiki/ItemString
-- "itemName", "itemLink", itemRarity, itemLevel, itemMinLevel, "itemType", "itemSubType", itemStackCount, "itemEquipLoc", "invTexture", "itemSellPrice"
-- itemLink - e.g. |cFFFFFFFF|Hitem:12345:0:0:0|h[Item Name]|h|r
-- itemType : Localized name of the item’s class/type.
-- itemSubType : Localized name of the item’s subclass/subtype.
-- itemEquipLoc : Non-localized token identifying the inventory type of the item
local IdToInfo = { }
-- https://classic.wowhead.com/item=18832/brutality-blade
IdToInfo[18832] = {
	'Brutality Blade',
	-- there are attributes in this link which aren't standard/plain, but bonuses (e.g. enchant at 2564)
	'|cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r',
	4,
	70,
	60,
	"Weapon", --?? INVTYPE_WEAPON
	'One-Handed Swords', --??
	1,
	"INVTYPE_WEAPON",
	nil,
	nil,
}
_G.GetItemInfo = function(item)
	itemInfo = IdToInfo[item] or {}
	return table.unpack(itemInfo)
end

-- https://github.com/Gethe/wow-ui-source/tree/classic