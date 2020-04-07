local _, AddOn = ...
local Logging   = AddOn.Libs.Logging
local Util      = AddOn.Libs.Util
local ItemUtil  = AddOn.Libs.ItemUtil
local L         = AddOn.components.Locale
local UI        = AddOn.components.UI

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
    return self.playerName, self.playerClass, self.guildRank, enchant, lvl, ilvl
end

function AddOn:GetGuildRanks()
    if not IsInGuild() then return {} end
    GuildRoster()
    local t = {}
    for i = 1, GuildControlGetNumRanks() do
        local name = GuildControlGetRankName(i)
        t[name] = i
    end
    return t;
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

function AddOn.SetCellClassIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, class)
    local celldata = data and (data[realrow].cols and data[realrow].cols[column] or data[realrow][column])
    local class = celldata and celldata.args and celldata.args[1] or class
    if class then
        frame:SetNormalTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local coords = CLASS_ICON_TCOORDS[class]
        frame:GetNormalTexture():SetTexCoord(unpack(coords))
    else
        frame:SetNormalTexture("Interface/ICONS/INV_Sigil_Thorim.png")
    end
end

function AddOn.GetClassColor(class)
    if Util.Objects.IsEmpty(class) then error("No class specified") end
    
    local color = RAID_CLASS_COLORS[class:upper()]
    if not color then
        -- if class not found, return epic color.
        return {r=1,g=1,b=1,a=1}
    else
        color.a = 1.0
        return color
    end
end

function AddOn.GetClassColorRGB(class)
    local c = AddOn.GetClassColor(class)
    return UI.RGBToHex(c.r,c.g,c.b)

end

function AddOn:GetUnitClassColoredName(name)
    local candidate = self.candidates[name]

    if candidate and candidate.class then
        local c = AddOn.GetClassColor(candidate.class)
        return UI.ColoredDecorator(c):decorate(self.Ambiguate(name))
    else
        local englishClass = select(2, UnitClass(Ambiguate(name, "short")))
        name = self:UnitName(name)
        if not englishClass or not name then
            return self.Ambiguate(name)
        else
            local color = RAID_CLASS_COLORS[englishClass].colorStr
            return UI.ColoredDecorator(color):decorate(self.Ambiguate(name))
        end
    end
end

-- @param link the item link for what we wish to compare against
-- @param equipLoc the location at which gear can be equipped
-- @param current if specified, compare against gear stored in this table (key is slot # and value is item link)
-- @return the gear currently equipped with the same slot as input
function AddOn:GetPlayersGear(link, equipLoc, current)
    Logging:Trace("GetPlayersGear(%s, %s) : %s", link, equipLoc, Util.Objects.ToString(current))
    local GetInventoryItemLink = GetInventoryItemLink
    if current then
        GetInventoryItemLink = function(_, slot) return current[slot] end
    end

    -- todo : need to handle tokens and trinkets
    local item1, item2
    -- map equipment location to slots where it can be equipped
    local gearSlots = ItemUtil:GetGearSlots(equipLoc)
    Logging:Trace("GetPlayersGear() : %s -> %s", equipLoc, Util.Objects.ToString(gearSlots))
    if not gearSlots then return nil, nil end
    -- index 1 will always have a value if returned

    item1 = GetInventoryItemLink("player", GetInventorySlotInfo(gearSlots[1]))
    -- gear slots supports an 'or' construct with the value being other potential gear slot
    if not item1 and gearSlots['or'] then
        item1 = GetInventoryItemLink("player", GetInventorySlotInfo(gearSlots['or']))
    end
    if gearSlots[2] then
        item2 = GetInventoryItemLink("player", GetInventorySlotInfo(gearSlots[2]))
    end
    Logging:Trace("GetPlayersGear() : %s, %s", item1 or 'empty', item2 or 'empty')
    return item1, item2
end

function AddOn:GetGear(link, equipLoc)
    return self:GetPlayersGear(link, equipLoc, self.playersData.gear)
end

function AddOn:UpdatePlayersGear(startSlot, endSlot)
    startSlot = startSlot or INVSLOT_FIRST_EQUIPPED
    endSlot = endSlot or INVSLOT_LAST_EQUIPPED
    for i = startSlot, endSlot do
        local link = GetInventoryItemLink("player", i)
        if link then
            local name = GetItemInfo(link)
            if name then
                self.playersData.gear[i] = link
            else
                self:ScheduleTimer("UpdatePlayersGear", 1, i, i)
            end
        else
            self.playersData.gear[i] = nil
        end
    end
end

function AddOn:UpdatePlayersData()
    Logging:Trace("UpdatePlayersData()")
    self.playersData.ilvl = GetAverageItemLevel()
    self:UpdatePlayersGear()
end

function AddOn:GetItemLevelDifference(item, g1, g2)
    if not g1 and g2 then error("You can't provide g2 without g1 in :GetItemLevelDifference()") end
    local _, link, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(item)
    if not g1 then
        g1, g2 = self:GetPlayersGear(link, equipLoc, self.playersData.gear)
    end

    if equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_FINGER" then
       local itemId = ItemUtil:ItemLinkToId(link)
        if itemId == ItemUtil:ItemLinkToId(g1) then
            local ilvl2 = select(4, GetItemInfo(g1))
            return ilvl - ilvl2
        elseif g2 and itemId == ItemUtil:ItemLinkToId(g2) then
            local ilvl2 = select(4, GetItemInfo(g2))
            return ilvl - ilvl2
        end
    end

    local diff = 0
    local g1diff, g2diff = g1 and select(4, GetItemInfo(g1)), g2 and select(4, GetItemInfo(g2))
    if g1diff and g2diff then
        diff = g1diff >= g2diff and ilvl - g2diff or ilvl - g1diff
    elseif g1diff then
        diff = ilvl - g1diff
    end

    return diff
end

function AddOn:ConvertIntervalToString(years, months, days)
    local text = format(L["n_days"], days)
    
    if years > 0 then
        text = format(L["n_days_and_n_months_and_n_years"], text, months, years)
    elseif months > 0 then
        text = format(L["n_days_and_n_monthss"], text, months)
    end
    
    return text
end

AddOn.FilterClassesByFactionFn = function(class)
    if AddOn.playerFaction == 'Alliance' then
        return class ~= "Shaman"
    elseif AddOn.playerFaction == 'Horde' then
        return class ~= "Paladin"
    end
    return true
end
