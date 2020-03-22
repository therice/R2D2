local _, AddOn = ...
local Logging   = AddOn.Libs.Logging
local Util      = AddOn.Libs.Util
local ItemUtil  = AddOn.Libs.ItemUtil

function AddOn:IsInNonInstance()
    local instance_type = select(2, IsInInstance())
    if instance_type == "pvp" or instance_type == "arena" then
        return true
    else
        return false
    end
end

-- Custom, better UnitIsUnit() function.
-- Blizz UnitIsUnit() doesn't know how to compare unit-realm with unit.
-- Seems to be because unit-realm isn't a valid unitid.
function AddOn:UnitIsUnit(unit1, unit2)
    if not unit1 or not unit2 then return false end
    -- Remove realm names, if any
    if strfind(unit1, "-", nil, true) ~= nil then
        unit1 = Ambiguate(unit1, "short")
    end
    if strfind(unit2, "-", nil, true) ~= nil then
        unit2 = Ambiguate(unit2, "short")
    end
    -- v2.3.3 There's problems comparing non-ascii characters of different cases using UnitIsUnit()
    -- I.e. UnitIsUnit("Potdisc", "potdisc") works, but UnitIsUnit("Æver", "æver") doesn't.
    -- Since I can't find a way to ensure consistant returns from UnitName(), just lowercase units here
    -- before passing them.
    return UnitIsUnit(unit1:lower(), unit2:lower())
end

-- Gets a unit's name formatted with realmName.
-- If the unit contains a '-' it's assumed it belongs to the realmName part.
-- Note: If 'unit' is a playername, that player must be in our raid or party!
-- @param unit Any unit, except those that include '-' like "name-target".
-- @return Titlecased "unitName-realmName"
function AddOn:UnitName(unit)
    -- First strip any spaces
    unit = gsub(unit, " ", "")
    -- Then see if we already have a realm name appended
    local find = strfind(unit, "-", nil, true)
    if find and find < #unit then -- "-" isn't the last character
        -- Let's give it same treatment as below so we're sure it's the same
        local name, realm = strsplit("-", unit, 2)
        name = name:lower():gsub("^%l", string.upper)
        return name.."-"..realm
    end
    -- Apparently functions like GetRaidRosterInfo() will return "real" name, while UnitName() won't
    -- always work with that (see ticket #145). We need this to be consistent, so just lowercase the unit:
    unit = unit:lower()
    -- Proceed with UnitName()
    local name, realm = UnitName(unit)
    -- Extract our own realm
    if not realm or realm == "" then realm = self.realmName or "" end
    -- if the name isn't set then UnitName couldn't parse unit, most likely because we're not grouped.
    if not name then
        name = unit
    end
    -- Below won't work without name
    -- We also want to make sure the returned name is always title cased (it might not always be! ty Blizzard)
    name = name:lower():gsub("^%l", string.upper)
    return name and name.."-"..realm
end

local function GetAverageItemLevel()
    local sum, count = 0, 0
    for i=_G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED do
        local iLink = _G.GetInventoryItemLink("player", i)
        if iLink and iLink ~= "" then
            local ilvl = select(4, _G.GetItemInfo(iLink)) or 0
            sum = sum + ilvl
            count = count + 1
        end
    end
    return Util.Numbers.Round(sum / count, 2)
end

local enchanting_localized_name
function AddOn:GetPlayerInfo()
    local enchant, lvl = false, 0
    if not enchanting_localized_name then
        enchanting_localized_name = GetSpellInfo(7411)
    end
    if GetSpellBookItemInfo(enchanting_localized_name) then
        -- we know enchanting, thus are an enchanter. we don't know our lvl though.
        enchant = true
        lvl = "?"
    end

    -- GetAverageItemLevel() isn't implemented via provided API
    local ilvl = GetAverageItemLevel()
    return self.playerName, self.playerClass, "NONE", self.guildRank, enchant, lvl, ilvl, nil
end

-- https://wow.gamepedia.com/API_Ambiguate
-- Returns a version of a character-realm string suitable for use in a given context.
function AddOn.Ambiguate(name)
    -- return db.ambiguate and Ambiguate(name, "none") or Ambiguate(name, "short")
    return Ambiguate(name, "none")
end

-- The link of same item generated from different players, or if two links are generated between player spec switch, are NOT the same
-- This function compares the raw item strings with link level and spec ID removed.
--
-- Also compare with unique id removed, because wowpedia says that:
-- "In-game testing indicates that the UniqueId can change from the first loot to successive loots on the same item."
-- Although log shows item in the loot actually has no uniqueId in Legion, but just in case Blizzard changes it in the future.
--
-- @return true if two items are the same item
function AddOn:ItemIsItem(item1, item2)
    if type(item1) ~= "string" or type(item2) ~= "string" then return item1 == item2 end
    item1 = ItemUtil:ItemLinkToItemString(item1)
    item2 = ItemUtil:ItemLinkToItemString(item2)
    if not (item1 and item2) then return false end
    return ItemUtil:NeutralizeItem(item1) ==  ItemUtil:NeutralizeItem(item2)
end

function AddOn:GetItemTextWithCount(link, count)
    return link .. (count and count > 1 and (" x" .. count) or "")
end
