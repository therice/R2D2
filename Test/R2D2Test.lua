local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))


describe("R2D2", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this).. '/TestSetup.lua'))(this, {})
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
            scrubbed = R2D2.ScrubData(
                    2,
                    {a = item, b = item, c = item, d = {z = item, x = item}}
            )
            print(R2D2.Libs.Util.Objects.ToString(scrubbed, 10))
        end)
        it("handles data send/receipt", function()
    
            for _, m in ipairs({'ABABAB', '12345678901234567890123456789012345678901234567890', "{2, {a = {boe = false, subType = One-Handed Swords, link = |cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r, equipLoc = INVTYPE_WEAPON, id = 18832, typeId = 2, ilvl = 70, texture = 135313, quality = 4, type = Weapon, subTypeId = 7, classes = 4294967295}, d = {z = {boe = false, subType = One-Handed Swords, link = |cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r, equipLoc = INVTYPE_WEAPON, id = 18832, typeId = 2, ilvl = 70, texture = 135313, quality = 4, type = Weapon, subTypeId = 7, classes = 4294967295}, x = {boe = false, subType = One-Handed Swords, link = |cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r, equipLoc = INVTYPE_WEAPON, id = 18832, typeId = 2, ilvl = 70, texture = 135313, quality = 4, type = Weapon, subTypeId = 7, classes = 4294967295}}, c = {boe = false, subType = One-Handed Swords, link = |cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r, equipLoc = INVTYPE_WEAPON, id = 18832, typeId = 2, ilvl = 70, texture = 135313, quality = 4, type = Weapon, subTypeId = 7, classes = 4294967295}, b = {boe = false, subType = One-Handed Swords, link = |cff9d9d9d|Hitem:18832:2564:0:0:0:0:0:0:80:0:0:0:0|h[Brutality Blade]|h|r, equipLoc = INVTYPE_WEAPON, id = 18832, typeId = 2, ilvl = 70, texture = 135313, quality = 4, type = Weapon, subTypeId = 7, classes = 4294967295}}}"}) do
                local new = R2D2:PrepareForSend("Test", m)
                local old = R2D2:Serialize("Test", R2D2.ScrubData(m))
                
                local r = { R2D2:ProcessReceived(new) }
                print("#1 " .. R2D2.Libs.Util.Objects.ToString(r))
                r = { R2D2:ProcessReceived(old)}
                print("#2 " .. R2D2.Libs.Util.Objects.ToString(r))
                r = {R2D2:Deserialize(new)}
                print("#3 " .. R2D2.Libs.Util.Objects.ToString(r))
            end
        end)
    end)
    describe("Mode", function()
        it("works as expected", function()
            local Modes = R2D2.Constants.Modes
            local mode = R2D2.Mode:new()
            assert(mode:Enabled(Modes.Standard))
            assert(mode:Disabled(Modes.Test))
            assert(mode:Disabled(Modes.Develop))
            
            mode:Enable(Modes.Test, Modes.Develop)
            assert(mode:Enabled(Modes.Standard))
            assert(mode:Enabled(Modes.Test))
            assert(mode:Enabled(Modes.Develop))

            mode:Disable(Modes.Test, Modes.Develop)
            assert(mode:Enabled(Modes.Standard))
            assert(mode:Disabled(Modes.Test))
            assert(mode:Disabled(Modes.Develop))

            mode:Enable(Modes.Test, Modes.Develop)
            mode:Disable(Modes.Test)
            assert(mode:Enabled(Modes.Standard))
            assert(mode:Disabled(Modes.Test))
            assert(mode:Enabled(Modes.Develop))

            mode = R2D2.Mode:new()
            mode:Enable(Modes.Develop)
            mode:Enable(Modes.Persistence)
            assert(mode:Disabled(Modes.Test))
            mode:Enable(Modes.Test)
            assert(mode:Enabled(Modes.Test))
            mode:Disable(Modes.Test)
            assert(mode:Disabled(Modes.Test))
            mode:Disable(Modes.Test)
            assert(mode:Disabled(Modes.Test))
        end)
    end)
end)
