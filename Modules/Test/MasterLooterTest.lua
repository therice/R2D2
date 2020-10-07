local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local ml, sb, Util, Candidate

describe("MasterLooter", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/../../Test/TestSetup.lua'))(this, {})
        R2D2:OnInitialize()
        R2D2:OnEnable()
        sb = R2D2:StandbyModule()
        sb:OnInitialize()
        ml = R2D2:MasterLooterModule()
        ml:OnInitialize()

        Util = R2D2.Libs.Util
        Candidate = R2D2.components.Models.Candidate
    end)
    
    teardown(function()
        ml:Disable()
        sb:Disable()
        After()
    end)
    
    describe("module", function()
        it("handles various candidate operations", function()
            R2D2:NewMasterLooterCheck()
            ml:OnEnable()
            R2D2:StartHandleLoot()
            ml:UpdateCandidates()
            
            local C = R2D2.Constants
            for i =1, 2 do
                for _, v in pairs(ml.candidates) do
                    v.rank = Util.Tables.Random({"Quarter Master", "Powder Monkey", "Captain", "Captain Alt", "QM Alt", "1st Mate", "Buccaneer", "Sailor", "Swabbie"})
                    v.enchanter = Util.Tables.Random({true, false})
                    v.enchant_lvl = v.enchanter and math.random(0, 300) or 0
                    v.ilvl = math.random(57.0, 69.0)
                end
        
                local data = R2D2:PrepareForSend(C.Commands.Candidates, ml.candidates)
                local success, _, data = R2D2:ProcessReceived(data)
                assert(success)
                --print(Util.Objects.ToString(unpack(data)))
            end
            
            
            R2D2.candidates = {
                ['Gnomechomsky-Atiesh'] = Candidate('Gnomechomsky-Atiesh', "WARLOCK"),
                ['Folsom-Atiesh'] = Candidate('Folsom-Atiesh', "WARRIOR"),
                ['Character6-Atiesh'] = Candidate('Character6-Atiesh', "DOESNTMATTER"),
            }
    
            ml.candidates['Character7-Atiesh'] = nil
            ml.candidates['Folsom-Atiesh'] = Candidate('Folsom-Atiesh', "WARRIOR")
            
            local sync, missing, extra = ml:CandidatesInSync()
            assert(not sync)
            assert(Util.Tables.Count(missing) == 38)
            assert(Util.Tables.Count(extra) == 1)
            
            R2D2:OnCommReceived(
                    "R2D2",
                    R2D2:PrepareForSend(C.Commands.Candidates, ml.candidates),
                    "group",
                    "Gnomechomsky-Atiesh"
            )
            
            sync, missing, extra = ml:CandidatesInSync()
            assert(sync)
            assert(Util.Tables.Count(missing) == 0)
            assert(Util.Tables.Count(extra) == 0)
        end)
    end)
end)