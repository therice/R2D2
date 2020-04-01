local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local function byte2bin(n)
    local t, d = {}, 0
    d = math.log(n)/math.log(2) -- binary logarithm
    for i=math.floor(d+1),0,-1 do
        t[#t+1] = math.floor(n / 2^i)
         n = n % 2^i
    end
    return #t > 0 and table.concat(t) or '00'
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
            scrubbed = R2D2.ScrubData(
                    2,
                    {a = item, b = item, c = item, d = {z = item, x = item}}
            )
            print(R2D2.Libs.Util.Objects.ToString(scrubbed, 10))
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
        end)
    end)
end)

