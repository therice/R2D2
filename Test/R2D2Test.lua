local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

-- local logFile

local function CreateItem(id)
    local _, link, rarity, ilvl, _, type, subType, _, equipLoc, texture, _,
    typeId, subTypeId, bindType, _, _, _ = GetItemInfo(id)
    local itemId = link and ItemUtil:ItemLinkToId(link)
    return Models.Item:new(
            itemId,
            link,
            rarity,
            ilvl,
            type,
            equipLoc,
            subType,
            texture,
            typeId,
            subTypeId,
            bindType,
            ItemUtil:GetItemClassesAllowedFlag(link)
    )
end

describe("R2D2", function()
    setup(function()
        loadfile(pl.abspath(pl.abspath('.') .. '/TestSetup.lua'))(this, {})
        R2D2:OnInitialize()
        R2D2:OnEnable()
    end)
    teardown(function()
        After()
    end)
    describe("Core", function()
        it("prints chat commands", function()
            R2D2:ChatCommand("VerSION A BEBPP")
            R2D2:ChatCommand("help")
            R2D2:ChatCommand("notacommand")
        end)
    end)
    describe("Comm", function()
        it("scrubs data", function()
            local scrubbed = R2D2.ScrubData(
                    1,
                    true,
                    "test",
                    {},
                    {a="b", c = {d="e"}}
            )
            print(R2D2.Libs.Util.Objects.ToString(scrubbed))


            local item = R2D2.components.Models.Item:FromGetItemInfo(18832)
            print(R2D2.Libs.Util.Objects.ToString(item))

            scrubbed = R2D2.ScrubData(
                    2,
                    {a = item, b = item, c = item, d = {z = item, x = item}}
            )
            print(R2D2.Libs.Util.Objects.ToString(scrubbed, 10))
        end)
    end)
end)

