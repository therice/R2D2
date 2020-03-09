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


-- Use the GameTooltip or create a new one and initialize it
-- Used to extract Class limitations for an item, upgraded ilvl, and binding type.
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", MAJOR_VERSION .. "_Tooltip", nil, "GameTooltipTemplate")
local tooltip = lib.tooltip
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
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
function lib:ItemLinkToId(itemlink)
    if not itemlink then return nil end
    local itemID = strmatch(itemlink, 'item:(%d+)')
    if not itemID then return end
    return tonumber(itemID)
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