local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local Models

local function CreateCandidate()
    local player = R2D2:UnitName("player")
    local class = select(2, UnitClass("player"))
    return Models.Candidate:new(player, class, "Officer", false, 0, 62)
end

describe("Candidate Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../Test/TestSetup.lua'))(this, {})
        R2D2:OnInitialize()
        R2D2:OnEnable()
        Models = R2D2.components.Models
    end)

    teardown(function()
        After()
    end)

    describe("Candidate", function()
        it("is created", function()
            local candidate = CreateCandidate()
            assert.equals(candidate.rank, "Officer")
        end)
        it("is cloned", function()
            local candidate1 = CreateCandidate()
            local candidate2 = candidate1:clone()
            assert.equals(candidate1.name, candidate2.name)
        end)
    end)
end)
