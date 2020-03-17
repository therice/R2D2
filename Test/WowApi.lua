local frames = {} -- Stores globally created frames and their internal properties.
local textures = {} -- Stores textures and their internal properties

local FrameClass = {} -- A class for creating frames.
local TextureClass = {} -- A class for creating textures

FrameClass.methods = {
	"SetScript", "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "Show", "Hide", "IsShown",
	"ClearAllPoints", "SetParent", "GetName", "SetOwner", "SetHyperlink", "NumLines", "SetPoint", "SetSize", "SetFrameStrata",
	"SetBackdrop", "CreateFontString", "SetNormalFontObject", "SetHighlightFontObject", "SetNormalTexture", "GetNormalTexture",
	"SetPushedTexture", "GetPushedTexture", "SetHighlightTexture", "GetHighlightTexture", "SetText", "GetScript"
}

TextureClass.methods = {
	"SetTexCoord"
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
		text = nil,
		textures = {}
	}
	return frame, frameProps
end

function TextureClass:New(t)
	local texture = {}
	for _,method in ipairs(self.methods) do
		texture[method] = self[method]
	end

	local textureProps = {
		texture = t,
		texturePath = nil,
		coord = {}
	}

	return texture, textureProps
end

function FrameClass:SetText(text)
	frames[self].text = text
end

function FrameClass:SetScript(script,handler)
	frames[self].scripts[script] = handler
end

function FrameClass:GetScript(script)
	return frames[self].scripts[script]
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

function FrameClass:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)

end

function FrameClass:SetSize(x, y)

end

function FrameClass:SetFrameStrata(strata)

end

function FrameClass:SetBackdrop(bgFile, edgeFile, tile, tileSize, edgeSize, insets)

end

function FrameClass:CreateFontString(name, layer, inheritsFrom)
	return CreateFrame("FontString", name)
end

function FrameClass:SetNormalFontObject(font)

end

function FrameClass:SetHighlightFontObject(font)

end

function FrameClass:SetNormalTexture(texture, texturePath)
	local texture = CreateTexture("normal", texture, texturePath)
	frames[self].textures['normal'] = texture
end

function FrameClass:GetNormalTexture()
	return frames[self].textures['normal']
end

function FrameClass:SetPushedTexture(texture, texturePath)
	local texture = CreateTexture("pushed", texture, texturePath)
	frames[self].textures['pushed'] = texture
end

function FrameClass:GetPushedTexture()
	return frames[self].textures['pushed']
end

function FrameClass:SetHighlightTexture(texture, texturePath)
	local texture = CreateTexture("highlight", texture, texturePath)
	frames[self].textures['highlight'] = texture
end

function FrameClass:GetHighlightTexture()
	return frames[self].textures['highlight']
end


function TextureClass:SetTexCoord(left, right, top, bottom)
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

function CreateTexture(texture, texturePath)
	local tex, internal = TextureClass:New(type)
	internal.texture = texturePath
	internal.texturePath = texturePath
	internal.coord = {}
	textures[tex] = internal
	return tex
end


C_Timer = {}
function C_Timer.After(duration, callback)

end

function C_Timer.NewTimer(duration, callback)

end

function C_Timer.NewTicker(duration, callback, iterations)

end

C_CreatureInfo = {}
C_CreatureInfo.ClassInfo = {
	[1] = {
		"Warrior", "WARRIOR"
	},
	[2] = {
		"Paladin", "PALADIN"
	},
	[3] = {
		"Hunter", "HUNTER"
	},
	[4] = {
		"Rogue", "ROGUE"
	},
	[5] = {
		"Priest", "PRIEST"
	},
	[6] = nil,
	[7] = {
		"Shaman", "SHAMAN"
	},
	[8] = {
		"Mage", "MAGE"
	},
	[9] = {
		"Warlock", "WARLOCK"
	},
	[10] = nil,
	[11] = {
		"Druid", "DRUID"
	},
	[12] = nil,
}

-- className (localized name, e.g. "Warrior"), classFile (non-localized name, e.g. "WARRIOR"), classID
function C_CreatureInfo.GetClassInfo(classID)
	local classInfo = C_CreatureInfo.ClassInfo[classID]
	if classInfo then
		return {
			className = classInfo[1],
			classFile = classInfo[2],
			classID = classID
		}
	end
	return nil
end

function UnitName(unit)
	if unit == "player" then
		return "Gnomechomsky"
	else
		return unit
	end
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

-- There are 9 classes in classic, but they are NOT the first 9 ids. Druids are class ID 11 even in classic.
-- return 9 here is consistent with Classic flavor
--function GetNumClasses()
--	return 9
--end
_G.MAX_CLASSES = 9

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

-- debugstack = debug.traceback
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

function GetAddOnMetadata(name, attr)
	if string.lower(attr) == 'version' then
		return "0.1-test"
	else
		return nil
	end
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

-- version, build, date, tocversion
function GetBuildInfo()
	return "1.13.3", "3302", "Feb 7 2020", 11303
end


time = os.clock

strmatch = string.match
strlower = string.lower

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
	-- assert(type(orig_func)=="function")

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

_G.tInvert = function(tbl)
	local inverted = {};
	for k, v in pairs(tbl) do
		inverted[v] = k;
	end
	return inverted;
end


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
_G.strjoin = function(delimiter, ...)
	return table.concat({...}, delimiter)
end
_G.string.trim = function(s)
	-- from PiL2 20.4
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

_G.date = os.date
_G.time = os.time
_G.unpack = table.unpack
_G.tinsert = table.insert
_G.tremove = table.remove

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

	return unpack(record)
end

string.split = _G.strsplit

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

--[[
returns
name (string) - Name of the item subtype
isArmorType (boolean) - Seems to only return true for classID 4: Armor - subClassID 0 to 4 Miscellaneous, Cloth, Leather, Mail, Plate
--]]
_G.GetItemSubClassInfo = function(classID, subClassID)
	if classID == LE_ITEM_CLASS_WEAPON then
		if subClassID == LE_ITEM_WEAPON_WAND then
			return "Wands", false
		elseif subClassID == LE_ITEM_WEAPON_THROWN then
			return "Thrown", false
		end
	end
end

-- https://github.com/Gethe/wow-ui-source/tree/classic
_G.INVTYPE_HEAD = "Head"
_G.INVTYPE_NECK = "Neck"
_G.INVTYPE_SHOULDER = "Shoulder"
_G.INVTYPE_CHEST = "Chest"
_G.INVTYPE_WAIST = "Waist"
_G.INVTYPE_LEGS = "Legs"
_G.INVTYPE_FEET = "Feet"
_G.INVTYPE_WRIST = "Wrist"
_G.INVTYPE_HAND = "Hands"
_G.INVTYPE_FINGER = "Finger"
_G.INVTYPE_TRINKET = "Trinket"
_G.INVTYPE_CLOAK = "Back"
_G.SHIELDSLOT = "Shield"
_G.INVTYPE_HOLDABLE = "Held In Off-Hand"
_G.INVTYPE_RANGED = "Ranged"
_G.INVTYPE_RELIC =  "Relic"
_G.INVTYPE_WEAPON = "One-Hand"
_G.INVTYPE_2HWEAPON = "Two-Handed"
_G.INVTYPE_WEAPONMAINHAND = "Main Hand"
_G.INVTYPE_WEAPONOFFHAND = "Off Hand"
_G.WEAPON = "Weapon"
_G.LE_ITEM_WEAPON_AXE1H = 0
_G.LE_ITEM_WEAPON_AXE2H = 1
_G.LE_ITEM_WEAPON_BOWS = 2
_G.LE_ITEM_WEAPON_GUNS = 3
_G.LE_ITEM_WEAPON_MACE1H = 4
_G.LE_ITEM_WEAPON_MACE2H = 5
_G.LE_ITEM_WEAPON_POLEARM = 6
_G.LE_ITEM_WEAPON_SWORD1H = 7
_G.LE_ITEM_WEAPON_SWORD2H = 8
_G.LE_ITEM_WEAPON_WARGLAIVE = 9
_G.LE_ITEM_WEAPON_STAFF = 10
_G.LE_ITEM_WEAPON_BEARCLAW = 11
_G.LE_ITEM_WEAPON_CATCLAW = 12
_G.LE_ITEM_WEAPON_UNARMED = 13
_G.LE_ITEM_WEAPON_GENERIC = 14
_G.LE_ITEM_WEAPON_DAGGER = 15
_G.LE_ITEM_WEAPON_THROWN = 16
_G.LE_ITEM_WEAPON_CROSSBOW = 18
_G.LE_ITEM_WEAPON_WAND = 19
_G.LE_ITEM_ARMOR_GENERIC = 0
_G.LE_ITEM_ARMOR_CLOTH = 1
_G.LE_ITEM_ARMOR_LEATHER = 2
_G.LE_ITEM_ARMOR_MAIL = 3
_G.LE_ITEM_ARMOR_PLATE = 4
_G.LE_ITEM_ARMOR_COSMETIC = 5
_G.LE_ITEM_ARMOR_SHIELD = 6
_G.LE_ITEM_ARMOR_LIBRAM = 7
_G.LE_ITEM_ARMOR_IDOL = 8
_G.LE_ITEM_ARMOR_TOTEM = 9
_G.LE_ITEM_ARMOR_SIGIL = 10
_G.LE_ITEM_ARMOR_RELIC = 11

_G.LE_ITEM_CLASS_WEAPON = 2
_G.LE_ITEM_CLASS_ARMOR = 4