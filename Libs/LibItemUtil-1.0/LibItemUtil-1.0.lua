local MAJOR_VERSION = "LibItemUtil-1.0"
local MINOR_VERSION = 11303

local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local AceEvent = LibStub("AceEvent-3.0")
AceEvent:Embed(lib)

-- Inventory types are localized on each client. For this we need LibBabble-Inventory to unlocalize the strings.
-- Establish the lookup table for localized to english words
local BabbleInv = LibStub("LibBabble-Inventory-3.0"):GetReverseLookupTable()
local Deformat = LibStub("LibDeformat-3.0")
local Logging  = LibStub("LibLogging-1.0")

-- Use the GameTooltip or create a new one and initialize it
-- Used to extract Class limitations for an item, upgraded ilvl, and binding type.
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", MAJOR_VERSION .. "_TooltipParse", nil, "GameTooltipTemplate")
local tooltip = lib.tooltip
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
tooltip:UnregisterAllEvents()
tooltip:Hide()

local restrictedClassFrameNameFormat = tooltip:GetName().."TextLeft%d"

--[[
All item types we care about:

    Cloth = true,
    Leather = true,
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    Daggers = true,
    ["Fist Weapons"] = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Maces"] = true,
    ["One-Handed Swords"] = true,
    Polearms = true,
    Staves = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
    Wands = true,
--]]

local Disallowed = {
    DRUID = {
        Mail = true,
        Plate = true,
        Shields = true,
        Bows = true,
        Crossbows = true,
        Guns = true,
        ["One-Handed Axes"] = true,
        ["One-Handed Swords"] = true,
        ["Two-Handed Axes"] = true,
        ["Two-Handed Swords"] = true,
        Librams = true,
        Sigils = true,
        Thrown = true,
        Totems = true,
        Wands = true,
    },
    HUNTER = {
        Plate = true,
        Shields = true,
        ["One-Handed Maces"] = true,
        ["Two-Handed Maces"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Totems = true,
        Wands = true,
    },
    MAGE = {
        Leather = true,
        Mail = true,
        Plate = true,
        Shields = true,
        Bows = true,
        Crossbows = true,
        ["Fist Weapons"] = true,
        Guns = true,
        ["One-Handed Axes"] = true,
        ["One-Handed Maces"] = true,
        Polearms = true,
        ["Two-Handed Axes"] = true,
        ["Two-Handed Maces"] = true,
        ["Two-Handed Swords"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Thrown = true,
        Totems = true,
    },
    PALADIN = {
        Bows = true,
        Crossbows = true,
        ["Fist Weapons"] = true,
        Guns = true,
        Staves = true,
        Idols = true,
        Sigils = true,
        Thrown = true,
        Totems = true,
        Wands = true,
    },
    PRIEST = {
        Leather = true,
        Mail = true,
        Plate = true,
        Shields = true,
        Bows = true,
        Crossbows = true,
        ["Fist Weapons"] = true,
        Guns = true,
        ["One-Handed Axes"] = true,
        ["One-Handed Swords"] = true,
        Polearms = true,
        ["Two-Handed Axes"] = true,
        ["Two-Handed Maces"] = true,
        ["Two-Handed Swords"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Thrown = true,
        Totems = true,
    },
    ROGUE = {
        Mail = true,
        Plate = true,
        Shields = true,
        Polearms = true,
        Staves = true,
        ["Two-Handed Axes"] = true,
        ["Two-Handed Maces"] = true,
        ["Two-Handed Swords"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Totems = true,
        Wands = true,
    },
    SHAMAN = {
        Plate = true,
        Bows = true,
        Crossbows = true,
        Guns = true,
        ["One-Handed Swords"] = true,
        Polearms = true,
        ["Two-Handed Swords"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Thrown = true,
        Wands = true,
    },
    WARLOCK = {
        Leather = true,
        Mail = true,
        Plate = true,
        Shields = true,
        Bows = true,
        Crossbows = true,
        ["Fist Weapons"] = true,
        Guns = true,
        ["One-Handed Axes"] = true,
        ["One-Handed Maces"] = true,
        Polearms = true,
        ["Two-Handed Axes"] = true,
        ["Two-Handed Maces"] = true,
        ["Two-Handed Swords"] = true,
        Idols = true,
        Librams = true,
        Sigils = true,
        Thrown = true,
        Totems = true,
    },
    WARRIOR = {
        Idols = true,
        Librams = true,
        Sigils = true,
        Totems = true,
        Wands = true,
    },
}

local function GetNumClasses()
    return _G.MAX_CLASSES
end

lib.ClassDisplayNameToId = {}
lib.ClassTagNameToId = {}
lib.ClassIdToDisplayName = {}
lib.ClassIdToFileName = {}

do
    for i=1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        -- could be nil
        if info then
            lib.ClassDisplayNameToId[info.className] = i
            lib.ClassTagNameToId[info.classFile] = i
        end
    end

    local druid = C_CreatureInfo.GetClassInfo(11)
    lib.ClassDisplayNameToId[druid.className] = 11
    lib.ClassTagNameToId[druid.classFile] = 11
end

lib.ClassIdToDisplayName = tInvert(lib.ClassDisplayNameToId)
lib.ClassIdToFileName = tInvert(lib.ClassTagNameToId)


-- Support for custom item definitions
--
-- keys are item ids and values are tuple where index is
--  1. rarity, int, 4 = epic
--  2. ilvl, int
--  3. inventory slot, string (supports special keywords such as CUSTOM_SCALE and CUSTOM_GP)
--  4. faction (Horde/Alliance), string
--[[
For example:

{
    -- Classic P2
    [18422] = { 4, 74, "INVTYPE_NECK", "Horde" },       -- Head of Onyxia
    [18423] = { 4, 74, "INVTYPE_NECK", "Alliance" },    -- Head of Onyxia
    -- Classic P5
    [20928] = { 4, 78, "INVTYPE_SHOULDER" },    -- T2.5 shoulder, feet (Qiraji Bindings of Command)
    [20932] = { 4, 78, "INVTYPE_SHOULDER" },    -- T2.5 shoulder, feet (Qiraji Bindings of Dominance)
}
--]]
local CustomItems = {}

function lib:GetCustomItems()
    return CustomItems
end

function lib:SetCustomItems(data)
    CustomItems = {}
    for k, v in pairs(data) do
        CustomItems[k] = v
    end
end

function lib:ResetCustomItems()
    lib:SetCustomItems({})
end

function lib:AddCustomItem(itemId, rarity, ilvl, slot, faction)
    CustomItems[itemId] = { rarity, ilvl, slot, faction}
end

function lib:RemoveCustomItem(itemId)
    CustomItems[itemId] = nil
end

function lib:GetCustomItem(itemId)
    return CustomItems[itemId]
end

--- Convert an itemlink to itemID
--  @param itemlink of which you want the itemID from
--  @returns number or nil
function lib:ItemLinkToId(link)
    return tonumber(strmatch(link or "", "item:(%d+):"))
end

-- determine if specified class is compatible with item
function lib:ClassCanUse(class, item)
    -- this will be localized
    local subType = select(7, GetItemInfo(item))
    if not subType then return true end

    -- Check if this is a restricted class token.
    -- Possibly cache this check if performance is an issue.
    local link = select(2, GetItemInfo(item))
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(link)
    -- lets see if we can find a 'Classes: Mage, Druid' string on the itemtooltip
    -- Only scanning line 2 is not enough, we need to scan all the lines
    for lineID = 1, tooltip:NumLines(), 1 do
        local line = _G[restrictedClassFrameNameFormat:format(lineID)]
        if line then
            local text = line:GetText()
            if text then
                local classList = Deformat(text, ITEM_CLASSES_ALLOWED)
                if classList then
                    tooltip:Hide()
                    for _, restrictedClass in pairs({strsplit(',', classList)}) do
                        restrictedClass = strtrim(strupper(restrictedClass))
                        restrictedClass = strupper(LOCALIZED_CLASS_NAMES_FEMALE[restrictedClass] or LOCALIZED_CLASS_NAMES_MALE[restrictedClass])
                        if class == restrictedClass then
                            return true
                        end
                    end
                    return false
                end
            end
        end
    end
    tooltip:Hide()

    -- Check if players can equip this item.
    subType = BabbleInv[subType]
    if Disallowed[class][subType] then
        return false
    end

    return true
end

-- @return The bitwise flag indicates the classes allowed for the item, as specified on the tooltip by "Classes: xxx"
-- If the tooltip does not specify "Classes: xxx" or if the item is not cached, return 0xffffffff
-- This function only checks the tooltip and does not consider if the item is equipable by the class.
-- Item must have been cached to get the correct result.
--
-- If the number at binary bit i is 1 (bit 1 is the lowest bit), then the item works for the class with ID i.
-- 0b100,000,000,010 indicates the item works for Paladin(classID 2) and DemonHunter(class ID 12)
function lib:GetItemClassesAllowedFlag(itemLink)
    if type(str) == "string" and str:trim() ~= "" then return 0 end
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    Logging:Trace("GetItemClassesAllowedFlag(%s)", itemLink)

    local delimiter = ", "
    for i = 1, tooltip:NumLines() or 0 do
        local line = getglobal(restrictedClassFrameNameFormat:format(i))
        if line and line.GetText then
            local text = line:GetText() or ""
            local classesText = Deformat(text, ITEM_CLASSES_ALLOWED)
            if classesText then
                tooltip:Hide()
                if LIST_DELIMITER and LIST_DELIMITER ~= "" and classesText:find(LIST_DELIMITER:gsub("%%s","")) then
                    delimiter = LIST_DELIMITER:gsub("%%s","")
                elseif PLAYER_LIST_DELIMITER and PLAYER_LIST_DELIMITER ~= "" and classesText:find(PLAYER_LIST_DELIMITER) then
                    delimiter = PLAYER_LIST_DELIMITER
                end

                local result = 0
                for className in string.gmatch(classesText..delimiter, "(.-)"..delimiter) do
                    local classID = ClassDisplayNameToId[className]
                    if classID then
                        result = result + bit.lshift(1, classID-1)
                    else
                        Logging:Warn("Error while getting classes flag of %s  Class %s does not exist", itemLink, className)
                    end
                end
                return result
            end
        end
    end

    tooltip:Hide()
    return 0xffffffff -- The item works for all classes
end