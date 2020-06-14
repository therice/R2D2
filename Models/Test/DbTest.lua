local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))
local CompressedDb, Util

local function NewDb(data)
    -- need to add random # to end or it will have the same data
    local db = R2D2.Libs.AceDB:New('R2D2_TestDB' .. random(100))
    if data then
        for k, v in pairs(data) do
            db.factionrealm[k] = v
        end
    end
    return db, CompressedDb(db.factionrealm)
end

describe("DB Model", function()
    setup(function()
        loadfile(pl.abspath(pl.dirname(this) .. '/DbTestData.lua'))()
        loadfile(pl.abspath(pl.dirname(this).. '/../../Test/TestSetup.lua'))(this, {})
        CompressedDb = R2D2.components.Models.CompressedDb
        Util = R2D2.Libs.Util
        R2D2:OnInitialize()
        R2D2:OnEnable()
    end)
    
    teardown(function()
        After()
    end)
    
    describe("DB", function()
        it("handles compress and decompress", function()
            for _, v in pairs(TestData) do
                local c = CompressedDb.static:compress(v)
                local d = CompressedDb.static:decompress(c)

                if Util.Objects.IsString(v) then
                    assert(Util.Strings.Equal(v, d))
                elseif Util.Objects.IsTable(v) then
                    assert(Util.Tables.Equals(v, d, true))
                end
            end
        end)
        it("handles single-value set/get via key", function()
            local _, db = NewDb()
            for k, v in pairs(TestData) do
                db:put(k, v)
            end

            print('Length=' .. #db)

            local c_ipairs = CompressedDb.static.ipairs

            for k, _ in c_ipairs(db) do
                print(format("ipairs(%d)/get(%d)", k, k) .. ' =>'  .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_ipairs(db) do
                print("ipairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end

        end)
        it("handles single-value get/set via insert", function()
            local _, db = NewDb()
            for _, v in pairs(TestData) do
                db:insert(v)
            end
    
            print('Length=' .. #db)
            
            local c_pairs = CompressedDb.static.pairs


            for k, _ in c_pairs(db) do
                print(format("pairs(%d)/get(%d)", k, k) .. ' =>'  .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_pairs(db) do
                print("pairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end
        end)

        it("handles table set/get via key", function()
            local _, db = NewDb()
            for _, k in pairs({'a', 'b', 'c'}) do
                db:put(k, {})
                print(Util.Objects.ToString(db:get(k)))
            end

            for _, v in pairs({{a='a', b=1, c= true}, {c='c', d=10.6, e=false}}) do
                for _, k in pairs({'a', 'b', 'c'}) do
                    db:insert(v, k)
                end
            end

            print('Length_1=' .. #db.db)
            print('Length_2=' .. #db)


            local c_pairs = CompressedDb.static.pairs

            for k, _ in c_pairs(db) do
                print(format("pairs(%s)/get(%s)", k, k) .. ' =>' .. Util.Objects.ToString(db:get(k)))
            end

            for _, v in c_pairs(db) do
                print("pairs/v" .. ' =>'  .. Util.Objects.ToString(v))
            end
        end)

        --[[
        it("scratch case", function()
            local Traffic = R2D2.components.Models.History.Traffic
            local Award = R2D2.components.Models.Award
            -- [183]
            local t = CompressedDb.static:decompress("AV4xXlReU2FjdG9yXlNHbm9tZWNow7Ntc2t5LUF0aWVzaF5TZGVzY3JpcHRpb25eU0F3YXJkZWR+YDI4fmBFUH5gZm9yfmBOZWZhcmlhbn5gKFZpY3RvcnkpXlNpZF5TMTU5MDgwODIxMS0xODQwXlNzdWJqZWN0c15UXnReU3Jlc291cmNlVHlwZV5OMV5TdmVyc2lvbl5UXlNtaW5vcl5OMF5TcGF0Y2heTjBeU21ham9yXk4xXnReU3N1YmplY3RUeXBlXk4zXlNhY3Rpb25UeXBlXk4xXlN0aW1lc3RhbXBeTjE1OTA4MDgyMTFeU3Jlc291cmNlUXVhbnRpdHleTjI4XlNhY3RvckNsYXNzXlNXQVJMT0NLXnReXg==")
            local ao = Award(t)
            local ho = Traffic():reconstitute(t)
            print(Util.Objects.ToString(ao:toTable()))
            print(Util.Objects.ToString(ho:toTable()))
            
            local subjects = {
                {"Whoo-Atiesh", "WARRIOR"},
                {"Tarazed-Atiesh", "PALADIN"},
                {"Kerridwen-Atiesh", "PRIEST"},
                {"Bigmagik-Atiesh", "HUNTER"},
                {"Saberian-Atiesh", "PALADIN"},
                {"Keelut-Atiesh", "HUNTER"},
                {"Entario-Atiesh", "HUNTER"},
                {"Findell-Atiesh", "HUNTER"},
                {"Grumpler-Atiesh", "HUNTER"},
                {"Modi-Atiesh", "WARLOCK"},
                {"Yashamaru-Atiesh", "WARLOCK"},
                {"Hobson-Atiesh", "PALADIN"},
                {"Ravenett-Atiesh", "WARRIOR"},
                {"Cirse-Atiesh", "WARLOCK"},
                {"Humanwarr-Atiesh", "WARRIOR"},
                {"Avalona-Atiesh", "WARLOCK"},
                {"Divinitee-Atiesh", "PRIEST"},
                {"Ingtar-Atiesh", "WARRIOR"},
                {"Zhitnik-Atiesh", "PALADIN"},
                {"Abramelin-Atiesh", "MAGE"},
                {"Kaiserina-Atiesh", "WARRIOR"},
                {"Gnomechómsky-Atiesh", "WARLOCK"},
                {"Pittypatt-Atiesh", "MAGE"},
                {"Warwicker-Atiesh", "MAGE"},
                {"Shipbeef-Atiesh", "MAGE"},
                {"Apolloion-Atiesh", "PALADIN"},
                {"Halcyon-Atiesh", "ROGUE"},
                {"Rarebear-Atiesh", "DRUID"},
                {"Stomatopada-Atiesh", "PALADIN"},
                {"Skogr-Atiesh", "DRUID"},
                {"Atarian-Atiesh", "WARRIOR"},
                {"Wreqt-Atiesh", "WARRIOR"},
                {"Zùùl-Atiesh", "PRIEST"},
                {"Padrion-Atiesh", "WARRIOR"},
                {"Ivannah-Atiesh", "PRIEST"},
                {"Taleath-Atiesh", "DRUID"},
                {"Bullfrog-Atiesh", "ROGUE"},
                {"Beernard-Atiesh", "PRIEST"},
                {"Mexica-Atiesh", "WARRIOR"}
            }
            ao:SetSubjects(Award.SubjectType.Raid, unpack(subjects))
            
            local hn = Traffic(ho.timestamp, ao)
            for _, attr in pairs({'actor', 'actorClass', 'resourceBefore', 'lootHistoryId', 'id'}) do
                hn[attr] = ho[attr]
            end
            
            print(Util.Objects.ToString(hn:toTable(), 8))
            print(CompressedDb.static:compress(hn:toTable()))
        end)
        --]]
        --[[
        it("verify swap compression mechanism", function()
            local Compression = Util.Compression
            local Serialize = R2D2.Libs.AceSerializer
            local Base64 = R2D2.Libs.Base64
            
            local bigOne = "Al4xXlReTv4DAv4FAlNjb2xvcv4EAv4GAv4DAk4wLjI1/gYCMv4GAv4UAjc4/gYCM/4aAi45/hkCTjT+EQJedF7+CgJsYXNz/ikCV0FSTE9DS/4pAmdyb3VwU2l6Zf4GAjQw/ikCaXRlbVR5cGVJZP5BAv4pAmJv/i0C/ikCTWFnbWFkYf4PAv49Av5GAm3+KQJ8Y2ZmYTMzNWVlfEj+RQL+RwI6MTY4MTQ6/nUC/nYC/nUCNjD+dwL+dgJ8aFtQYW50c35gb2b+hQJQ/jkCcGhlY3ld/n0CfP5cAv5YAnD+TQL+QQIwOf4pAnJlc3BvbnNlT3JpZ2lu/hgC/kQC/k4CUzE1ODk3Nv5wAjg0LTMwNv4lAlNvd25l/lwCQ2ly/qICLUF0af6dAmj+RAL+XgJTdWL+SQL+SwL+lwL+BwL+mwL+nQL+nwL+oQL+QAJTRGn+ogJuY2j+gQL+KAJTdv7AAnNp/qAC/hACU23+qAL+DgL+GgL+KQJwYXT+3wL+7gL+6gJhav7tAv7UAv7iAv6cAv6eAv6gAv6iAv7TAv4DAlP+yAJt/p0CdGFtcP4RAv6vAv6xAv6zAv5xAv67Av6oAnP+BgP+3gL+2QJN/gwC/kYCbv6FAkP+DgL+2QJ0/koCZf4aA2T+2QL+IQP+ZAJ1bP4oAv4oAk7+GQL+CQL+CwL+DQL+DwL+BQL+1AL+EwL+FQL+FwL+KQP+IAL+HAL+HgL+IAL+IgL+TwL++QL+KQJj/isC/lMCU/4wAv4yAv40Av42AlP+OAL+OgL+PAL+PgL+QAL+JAL+QwL+XQL+RwL+0QL+TAL+TgL+JAL+UAL+UgL+LgJTR2X+jQJubv4sAv7MAv5HAv5gAv5iAv5kAv5mAv5oAv5qAv5sAv5eAv5vAv5xAjEy/nsC/nYC/nkC/msDOv59AltH/g0C/uQC/oQC/oYC/ogCYP6KAm/+jAL+jgL+kAL+kgL+lAJh/pYC/lED/kIC/poCU/77Av7XAv6iAv6kAv6mAv6oAv6qAv49Av6sAv6uAv6wAv6yAjIy/mkDLf55Ajj+TAP+vQL+vwL+wQL+wwL+xQL+xwL+yQJz/ssC/k0Dbf7OAv7QAv4eA/7/Av7VAv78Av7YAv4pAv7bAv7dAv7fAv7hAv4pAv7kAv7EAv7nAv6pAv4JAv7rAm7++AL+TAP+8AL+8gL+ywL+EwL+KQL+WAL+9wL+DwL+OwP+AgP+HgP+IAP+IgNl/iQD/iYD/ikC/gMD/gUD/gcD/gkD/gcC/gsD/pED/pMD/hkC/j0C/qEC/hIDY/4UA/4WA2X+GANg/hoD/pwC/qgD/ocD/lAD/iYC/igD/h8C/isD/gwC/u0C/i8D/hIC/hQC/hYC/qoC/jED/jYDTv4fAv4xA/45A/5SA/7CA/49A/4sAv5VA/5BA/4zAv41Av43Av45Av47Av49Av4/Av6YAv5dA/5IAv6mA/6CA/5TA/4/A0f+WwL+XAL+bQL+XwJT/mEC/mMC/mUC/mcC/mkC/msC/gsE/mcD/nICM/5uAzr+bQP+awP+cAP+wgJy/j0DZXT+hQL+hwL+iQL+iwL+jQL+jwL+kQJo/pMC/r4D/oAD/tMC/oMD/t8D/v0C/qMC/qUC/qcC/qkC/jQD/o0D/ikC/o8D/gwDMjk1Mi00NTY3/ikC/pkD/sAC/ikC/h0E/p0D/sgC/soC/gIE/qQD/k8D/qcD/oUD/tYC/jAE/qsD/twC/toD/q4D/oIC/rAD/uUC/rMD/ukC/rYD/rgD/u8C/vEC/vMC/r0D/vUC/sAD/uID/i8E/tgC/k4E/ssD/hED/s0D/goD/pADNv46BP48BP5EAv7VA/6BAv7XA/5UAv7ZA/7bA/7dA/4cA/7EA2/+IQP+KQL+IwNh/iUD/icD/k8C/uUD/i0D/hAC/jAD/uoD/jMD/iMC/hsC/h0C/u8D/jgD/iMC/iUC/vQD/j4D/vcD/jEC/vkD/kQD/kYD/v0D/kkD/gEE/qID/k0E/gUEU/5RAv4/A0L+WwL+oAL+hQL+VwNkZP7oAv6iA/5fA/4PBP5iA/4SBP5lA/5uAv60Av5ABP4YBP4aBP57Av5wA0xhd2L+pQJuZ/7AAv6FAlP+8AL+JQP+IQP+xAL+KAT+KgT+9QL+gQP+mAL+hAP+hgP+MAT+iQP+MwT+jANp/o4D/tADNjM3MjMtMTf+rwL+0wP+RAT+mwP+xAJl/sYC/kkE/qAD/ksE/s8C/pkE/k8C/k8E/qkD/qIC/lIE/q0D/uAC/lYE/uMC/lgE/ugC/rUD/uwC/sED/rkD/l4E/rwD/kwD/r8D/vgC/gMC/uIC/h0D/ksC/sUD/nsE/scD/n0E/skD/gIDaf4EA/5oBP4IA/5qBP4MA/7QBP7SBP5vBP5oBP4TA/5zBP4mA/7aA/4ZA/4bA/5kBP7+Av5RA/73BP4GAv4XAv6BBP7nA/4mAv4xA/7rA/40A/7tA/6JBP7wA/4UAv7yA/6NBP4VBf4qAv72A/4vAv6RBP5DA/77A/5HA/7+A/5KA/5CAv4CBP7iBP5SA/6bBP5UA/4pAlP+4AJ6enJh/qED/gsE/qcE/mED/hEE/mQD/hQE/rQCMv50Av5uA/6wBP53Av5wA07+pgJo/oMC/isCef66BGBCb2/+gwL+wQT+fwP+xAT+SwP+xgT+UAT+2AL+yQT+iwP+NQT+zAT+NwT+zgQ0/hYCOC0y/rMCN/5CBP68Av6+Av5FBFP+RwT+3AT+ngP+SgT+ogP+TAT+BAT+jAP+xwT+qgP+2gL+UwT+3gL+6QT+4gL+sQP+5gL+7QT+vgP+7wT+9AL+ugP+XwT+9AT+9gL+9gT+JwL+EgX+4QP+1AL+AQX+AwX+BgP+BQX+zwP+awT+YgX+rwL+CgX+1gP+2AP+DgX+dQT+EQX+wwP++gT+eQT+xgP+yAP+fwRONv7pAv4sA/4ZBf6EBP4yA/7sA/6IBP43A/7xA/6MBP5jBP4lBf4/A/74A/4pBf5FA/78A/5IA/7/A/5LA/4vBf50Bf4xBf6cBP5VA/41BWH+NwX+OQX+OwX+XgL+PQX+EAT+YwP+EwT+ZgP+tAIzMf6vBP56Av4bBP5+AkP+2gP+WwL+swP+oQT+cwP+nQL+VQX+KwT+VwX+LgT+5AT+4AP+XAX+NAT+0wP+XwX+rQL+YQX+ZgU2/mUFN/5zAv4fAv5qBf6aA/5GBP6cA/5vBf7eBP6/Bf5HAv5zBf7SAv5RA/7TA/52Bf7mBP54Bf7oBP6vA/7rBP6yA/5/Bf7qAv6BBf5gBP6DBf7zBP4rBP5iBP7CA/75BP4fA/6cBf78BP6eBf7KA/4CBf7MA/6PBf44BP6yAv5iBTb+oQX+1AP+CwX+cgRT/hUD/pcF/hAF/t4D/tgF/jAE/qcD/igD/kIE/hgF/i4D/hoF/oUE/qcFLv7uA/4gBf4hAv6rBf6OBP4mBf5AA/4oBf76A/6xBf4rBf6WBP61Bf6YBP63Bf67Av65Bf40Bf4lA2Z1/jkC/tsDSP5bAmL+qAL+uQT+CgT+wAX+DQT+YAP+wgX+qgT+QQX+aAM2/skF/m4D/nAD/lUC/oICbGX+IgT+dwP+eQP+ewP+JwT+fgP+1QX+LQT+mQL+iQX+2gX+ywT+zQT+awQ1MDD+tgL+ZwL+rwL+mAP+awX+2gT+SAT+nwP+7AX+owP+4QT+twX+AQP+8gX+2QL+rAP+VAT+ewX+VwT++AX+tAP+gAX+twP+8AT+XQT+uwP+9AL+9QT+wQP+JAX+bgb+ZgT+CQb+BAX+zgP+DAY2/l4G/mAG/pQF/nEE/pYF/hcD/hcG/ncE/psF/noEU/58BP5+BP6IBU7+HQL+Hgb+gwT+6QP+pgX+HQX+qAX+igT+qgX+OgP+JAX+9QP+rgX+Kwb+kwT+sgX+LAX+lwT+CwT+MAX+Mwb+MwVT/s4CbP43Bv45Bv6FAv47BnL+PQb+uAT+bAX+PAX+Qgb+qAT+PwX+xAX+rAQ4OP7WBP5JBv7LBVtTYf4rAv5YAm7+vwT+uwRj/sMG/k8G/ngD/uECc/7UBf7DBP5XBv5ZBf7lBP4xBP6KA/7bBf6rAv5gBf5dBjAz/j0E/tAEM/68Bv5DBP5lBv7oBf7bBP7dBP5oBv7gBP6lA/7vBf51Bf5aBf7zBf5wBv56Bf72Bf59Bf5ZBP7uBP53Bv6CBf7yBP57Bv6GBf59Bv6IBf6aBf4EBv6PBv6RBv7/BP5nBP6OBf6DBv7OBP5eBv7bBv6IBv4MBf4UBv50BP6MBv6JBf4bBv4GAv6aAv6WBv7oA/7uAv6aBi40/o0E/iUG/r0G/p4G/vgG/qAG/pAE/kID/iwG/pQE/rMF/i0F/kwD/qcG/rcF/oQD/jQG/lYD/gwC/kcC/lYCZ/6FAnT+jQL+hQJJ/t4C/qgC/sAC/vEC/u0C/qYE/rcGZv5fBjcw/qME/roGbf5vAjj+ZgX+ygX+awP+RgX+fAL+fgJG/g4Cbf4lA2E6/oUCRf7tBv6CAv6FAldl/oAD/qAEYC3+sAb+UQds/j4G/okC/r0C/sAC/s8G/pUC/tEG/lkG/jIE/l0F/twF/lwG/gwDNf5mBzf+PgQ2OTD+AQP+2QT+4gb+Zwb+cQX+CwT+7gX+igX+HQL+GQb+dwVG/pwC/tkC/u8G/vkF/lsE/ngG/rwE/vQG/mAE/nwG/qwF/n8G/vAF/ggG/o0F/mkE/pAF/mUH/mcH/gUH/hMG/hUG/osG/twD/pkF/gMG/vsE/pAG/v0E/pIG/igDMf5DAv4OB/4gBv6ZBv6HBP4jBv4fBf6LBP4XB/7iAv4ZB/4nBf4bB/6jBv4uBv60Bf4uBf4xBv7oBv64Bf6qBkf+Jgf+WAJn/ikHYP4rB/7LBv4uB2P+MAf+OQV0/jMH/rYG/g4E/j4F/sMF/qsE/jwH/kIF/kAH/nsC/kIH/nUC/kgF/koF/kwFYf5OBXL+GQP+jQL+EQNw/skC/tcD/l0H/iwE/oID/lgG/nYH/ogD/mEH/tYG/jYE/t4F/l0GNf4cAi01/nMCOP4XAv7mBf5sBf5uBf7kBv5xB/7NAv5rBv6rB/7xBf7qBv5vBv55Bf5VBP58Bf7sBP51Bv76Bf7yBv78Bf6AB/6FBf4BBv4kBf6SB/4FBv6UB/4HBv6MBf4KBv4BB/7dB/42A/4RBv6VBf4NBf6PB/52BP4KB/4UBf6TBjH+CAL+PAP+5gP+Hwb+pQX+HAX+nQf+JAb+oAf+8wP+nwb+jwT+pAf+kgT+KgX+lQT+qAf+IAf+XgL+qAb+BgT+VQP+rgf+Tgb+sAf+sgf+tAf+LQf+Lwf+mgP+Mgf+QAb+XgP+NQf+RAb+QAX+xQX+vAb+QwX+vwb+sQT+fgL+VQL+VwJh/oUCVP5HAv5LAv6cAmT+hQL+UQX+UwX+zgb+VQb+0Ab+1Qf+0gb+2QX+2Qf+Wwb+2Ab+igc5/tMENf64Av4WB/7lB/5mBv7qBf7lBv5yBf7rB/6KBf67Av5uBv7nBP5xBv7uBv7zB/5aBP77Bf7xBP56Bv6BB/72Bv6DB/7uB/6ABv6HB/4LBv4CBzX+Twj+jAf+igb+DwX+kAf+GAb+/Af++wb+lQf+yQP+lwf+KgP+EAj+ggT+Dwf+GwX+hgT+NQP+nwf+nQb+GAj+GAf+Ggj+Kgb+pQf+HQj+Hgf+pgb+IQj+Mgb+Iwj+VAL+9gb+pARtb/5LB3j+jgJ1dHX+VQP+vAf+Qwb+qQT+Mgj+rAQ5MTM5/jYI/kcF/kQH/sMCZWd1/lsC/kEIYP41Bf46Amz+vwT+RQj+KQT+VgX+Xwf+1wf+1Ab+ygT+XgX+ZAf+sgL+bQj+Pgf+lQP+agf+kgP+4Ab+5wX+bQX+6QX+6Af+3wT+WAj+5wb+igX+7Qf+0wb+XQj+TQf+8gf+dAb+YQj+9gf+Ywj+hAX+/wX+hwX++AT+eAT+dQj+/wf+/gb+iAf+hAb+ugj+3AX+cAT+Bgf+jgf+cQj+Cgj+tAj+Cwf+BwL+5AP+egj+pAX+mAb+FAj+fwj+qQX+IQX+Jwb+GQj+KQb+rwX+HAf+pAb+Lwb+qQf+IQf+qwf+qQb+PwNS/lYC/lsD/jkC/pgI/kEG/r0H/jEI/jsH/mcD/k8I/sMH/ncC/sUH/m8D/n4CTv5HAv6dAv7cAv6FAkz+pgj+MwRn/rAI/sIE/l4H/kgI/mAH/tUG/kwI/twH/gwD/kEE/j8ELf4+B/7SBP6EA/5uB/7BCP7jBv5wBf7ECP5yB/5ZCP5OBP5cCP70Bf5eCP7qBP57B/70B/59B/7zBv5kCP75B/7TCP4LCP4mAv4BCP6CBv4GBf6yAv4cCf7kB/4QA/4HCP4HB/4WBv5yCP6NBv76Bv6dBf7+BP6fBf5zAv6iBf4RCP6XBv4gAv7pCP4eBf7rCP4mBv6hB/48A/6ECP7wCP6mB/4eCP4fB/62Bf72CP6MCFNPbnl4aWH+AgT+wQX+mwj+Agn+cAL+Twj+oQj+RQX+BQn+xgf+fgJE/jkFZ/79Av4GA2xr/sACJ/51A0hlbG3+0wf+VwX+QwX+SQj+yAT+Swj+twj+TQj+sgI4/mcCMf7UBP5fBv4TB/67Av4iCf7nB/4lCf5pBv5zB/7TAv7lBf4qCf7sBv7xB/5zBv5+Bf4vCf5iCP55Bv7RCP5hBP40Cf75Bv6TB/78Bv74BP6BBv7/Bv45Cf5xAv6ECf5vCP4pAv5bCf5dCf5fCf50Cf4OCWH+wwL+NQn+OwP+zwP+SAn+ewj+mwf+TAn+mwb+JQb+IgX+rAX+owf+hQj+HAj+LQb+VQn+iQj+TgP+iwj+MgX++Aj+vAX+DgL+bgn+nAL+Kgf+LAdgVf6CAv4HA2X+rAL+mQj+uAb+vwf+QQX+Twj+0AT+ogj+QwdbVP7ICUL+KwJja/5CCP5SBWv+egn+LQT+agf+Fwn+tgj+Ywf+YAX+awcxOf6FBv7aBi3+ngj+aQP+vwj+5gf+wgj+jAn+5gb+MAX+TAP+kQn+8Af+cgb+9wX+lQn+zgj+XAT+fwf+Mgn+0gj+9wb++gL+aAj+DAj+Nwn+oQn+zwP+6An+6gn+Awf+pQlT/toJYf7cCXf+WQdg/rME/q0J/pwJ/v0H/p4J/g0I/qEF/poH/hMI/n4I/k0J/pwG/uwI/lAJ/q0F/hoH/rsJ/h0H/qUG/jAG/vUI/loI/lkJQv45Av55BP4tA/6qCP6zBP6gA/5NBf61Bv7+CP6aCP65Bv7AB/5vAv5PCDf+FwT+aAn+Sgb+fgL+Dgr+3An+Qgj+LAr+qgj+gAL+vgT+OQb+Ewn+sgj+ggP+4wn+tAj+Wgb+gAn+3gX+CQr+IgIw/j0E/p8I/nMC/m0H/uEG/iMJ/nAH/iYJ/uoH/sYI/o8J/okF/soI/pMJ/voJ/vAG/nYG/v0J/v0F/vUG/voH/vgG/nQI/kQJ/pIG/gYK/tkI/m0I/mwHOf5QCv7cCP4SBv7ZAv4/Cmv+EQr+uAT+qwn+FQr+hAf+YwT+BwL+HQb+5gj+Egj+6Aj+HQr+tQn+Fwj+IwX+gwj+7wj+ogb+hwj+Jgr+9Aj+igj+WAn+wQn+VQNDaP45Av4nCP6XCP5hCf4wCP5jCf43Cv7pCf6gCP5qA/48Cv7ABkf+wwJk/k4G/lAG/scJ/ssGRv7DBv5OBv51BHL+lwj+WQL+XAf+Rgj+FQn+QQL+Sgr+bgb+TAr+5gn+Tgr+UQow/t4HOf62Av5eBjn+sAL+8An+VQj+wwj+jQn+KAn+mgT+9wn+9QX+LQn+YAj+8Qb+Ywr++Af+AQr+Zwj+0wb+aQj+Agj+CgP+awcy/rUKN/63Cv4MCv50Cv52Cv6yB/4UCv5cAv5oCv4GBv5FCf4NCP6VBv5+Cv5KCf59CP4iBv4WCP6BCP6ECv6iB/5SCf6HCv68Cf6ICP4nCv6LCv4pCv6NCv4pAkx1/rcHZv45Bv6UCv7/CP6WCv5GBv6XAzX+1Qn+aglbRv53Cf6NAv5bAv4hBGD+cgNv/nQD/uEJ/hYJ/ksK/n8J/rIK/q4C/msHM/4PBv6ZAv6FCf5mAv4hCf5WCv6LCf7rBf70Cf5sBv5dCv4rCf7LCP6UCf5hCv71B/7HCv7/Cf6aCf4CCv7KA/7VCP5pCv79Bv6gCf5sCv4OC/4QC/6eCP4MCv7fCP6YBf4YBv56Cv6vCf7pCf6xCf7nCP5LCf6BCv6eB/5OCf63Cf4oBv6hBv6GCP7pCv6JCv4gCP6/Cf6MCv4kB/7wCv7yCv70Cv40B/72Cv42Cv74Cv5fBv77Cv4ICVtB/h4E/oEC/twC/gML/kMI/lQF/qwK/tQH/sUE/uQJ/mIH/tcG/rMK/g8L/rMC/lEK/rcC/j8E/rwK/m8H/lYI/ukH/u0F/sAK/jYJ/sIK/iwJ/swI/vsJ/sYK/n4H/mQK/mUI/mYK/gMK/ssK/gUK/tgI/msI/ioL/l4L/nEK/j4J/i4L/gkH/hYK/tYI/twK/igD/tAK/jQL/n8K/jYL/uIK/oAI/iAK/oII/uYK/oYK/j0L/iUK/vMI/kAL/gME/uwH/lkJ/jkI/lgC/loC/i4I/gwE/kgL/tEJ/jMI/tAK/jsK/kEH/mkJ/k0LRXNr/ukE/pQL/qoJYFL+yAf+GQP+KwJ3/ggL/lgL/goL/hgJ/k0K/g0L/toG/g8G/m0I/mgH/tIK/hAG/ooJ/vIJ/hcL/sUI/jAF/p8I/hoL/pIJ/vkJ/i4J/vwJ/m4L/sgK/iIL/qwF/toK/v4H/twK/msK/nYL/rEL/oUG/rEC/i0L/ggH/kEJ/q4J/hUF/ikD/g8I/goC/kkJ/nwI/iEG/hEH/uMK/ocL/uUK/lEJ/ooL/iQK/vII/h8I/lcJ/u0K/iQH/pIL/lkC/lsC/vUK/jUK/pgL/qwE/qMJ/voK/psK/jcIW/7NBf77CP7QBf4TCv4QCf4+Bv5HCv5WBv4JC/6wCv4LC/5bC/6wC/5dC/6WA/4eCf5RCv5iC/5XCv5kC/5ZCv5mC/5bCv6FB/60CP5eCv6/C/7FCv5iCv7CC/4hC/6CB/7CA/4xC/4BA/51C/4BB/53C/6WA/7OC/5ACf7hCP7GC/4YCv6AC/55CP7VC/6yCf4cCv6FC/45C/7tCP6FCv48C/7fC/6nB/5WCf6qB/7jC/6tB/5YA/7aA/5bA/79CP4vCP6XC/5FBv7FBf4OA/5nCf6cC/49Cv5xA/5fCf6CAv5oBP5xCf5zCf51A/5UC/73C/5HCP6sC/76C/6uC/4MC/5tCv4PC/7jBf7SCv6GCTT+5QX+twv+JAn+uQv+Jwn+CAz+NwP+Cgz+Gwv+Xwr+wAv+bQv+MQn+mQn+EQz++wf+JQv+2wr+agr+FQz+zgr+sQv+Sgz+hAP+PQn+iQb+CAj+4Aj+mQX+Ewz+kwb+CQX+Gwr+gAr+Iwz+Hwr+Twn+iAv+3Qv+Jwz+sAX+jAv+4Qv+Kwz+LQT+WQn+VwP+WQP+MAz+6Av+0An+NAz+6ws4/gcJ/hkE/p0L/rIE/rQE/rYE/j4G/k8F/ggEdf5NBv4gBP5CDP6tCv5YBf5ZC/7aB/7dBf79C/5BBDH+vQb+TAz+FAv+wAj+Fgv+Vwj+Ugz+Igj+VQz+vgv+Xwj+zQj+WQz+9wf+EAz+Zgj+Egz+BAr+Ngn+YQz+CAr+Ywz+mAz+aQX+Zgz+3gj+zwv+Gwz+Xgz+xwv+lgf+GAL+JQL+bgz+hAv+2Qv+hgv+cgz+3Av+Igr+Gwj+dgz+4Av+Kgz+KAr+egz+7gr+VgP+CQT+fwz+vgf+gQz+wQf+vAb+swL+TAv+cANG/sQGZXdh/nIJ/swH/vQLZ3D+KwL+RgL+kAz+Vwv+kgz+rQv+5Qn+/Av+SAz+QQT+sQL+0wT+Uwr+iQn+FQv+uAv+ngz+Wgr+oAz+aQv+HAv+YAr+fAf+lwn+/gn+Wwz+qAz+XQz+jgb+Jgv+nwn+agj+Fgz+Ywz+5gz+GQz+CQj+agz+qgz+rwn+6wP+ugz+4Qr+vAz+JAz+IQr+uQn+Uwn+iAr+jQv+4gv+xgz+JAf+CARy/pUL/mIJ/kkL/jUM/hYE/tAM/swF/sMC/h8E/gML/iME/ngD/iUE/nwD/qsL/uAM/kUM/uIM/tsH/pYM/tIK/oMJ/tQE/tsG/mQG/pwM/usM/mUL/moG/lMM/osF/u8M/lcM/g0M/h8L/g8M/vUM/nEL/tEL/oYH/s0K/q0M/kkM/roK/uUF/rEM/o0H/rMM/pEH/rUM/h0M/hgC/hoK/t8K/tcL/pwH/uoI/nEM/joL/u4I/nUM/vEI/ikM/r4J/o8L/iwM/gcE/skM/kcL/ukL/swM/hUEM/5EBf44DP7ABv7xC/7PBf5TB/52Cf54Cf4iDf7XBf4kDf5aC/4mDf7kDP7SCv47BP4qDf5mBf4DDP6dDP4vDf6OCf4JDP4zDf4MDP6kDP4ODP5aDP7+Bf7EC/4CBv5FDf52CP76DP48Df4nDf5vCv48Cf7dCP5CDf4aDP4CDf5zC/57CjL+fQr+IAz+NQv+Bw3+FQj+vQz+Tg3+Jgz+Iwr+wgz+Ug3+6wr+QQv+VQ3+VQP+ngT+rwb+BAv+zQn+pAT+qQL+WA3+gAz+nAj+wQf+5Qw3/hkN/k4L/lALbv5SC/6FAv5MBnT+Tgb+ZQ3+1gf+Zw3+lAz+zQT+Kgv+4wf+YgX+1AT+Pw3+bw3+Lg3+Bgz+MA3+uwv+vQv++An+owz+bAv+dw3+pgz+OA3+mwn+awz+yQv+/Az+Dwv+tA3+eQv+Zwz+Pwn+AQ3+cwj+fA3+Bwb+gAv+3gr+iw3+gwv+vQP+HQX+EgL+JQb+bQj+Cg3+5wr+iwv+wwz+Uw3+oAz+JAf+mQ3+Uwf+ogT+nQ3+ygz+AQn+lwr+NAj+nQv+hQz+OQxU/sMG/twC/sUG/qEKYEX+ewP+BAP+OQVs/loHd/6rCv6xCP74C/5EDP7uB/5MCv4BA/6VDP7kDP6DDP6fCP62Df67Cv5UCP5jC/6+Cv4YC/6rB/72Cf7uB/6NCP6oAi3+vAT+jgL+hQIo/goJ/s0JKf4dC/7yDP7PCP6YCf55Df5cDP5nCv7PDf7IC/6sDP6WDP4DDv5ADf6DDf5wCP4vC/7ZAv5rDP6AC/4NB/5JDf6zCf43C/7aC/6+DP64Cf7bDf4oDP69Cf6VDf5UDf4QDf6qBv67Bf69Bf46Bf7lDf73Cv4XDf7HBf6lDf5gDf6lAv7iDf7SBf7eDP7WBf6vDf79Df77C/5pDf6zDf5vCjn+ZQX+hwn+uA3+UAz+7Az+Bwz+MAX+yAj+4AP+Cwz+vw3+Hgv+MAn+wg3+HA7+9gz++Ab+xQ3+IQ7+Ag7+TA7+/wz+aQz+zg3++Az+Xwz+dwj+HgL+mQf+LA7+Igz+CA3+TQ3+JQz+iQv+UA3+VAn+6gr+igr+lg3+Nw7+PwP+rAb+rgb+Yg3+PAb+igz+FA3+lQr+Fg3+ggz+cAL+pQ3+qw3+oAr+dgP+JAT+egP+JgT+fQP++g3+Qwz+Iw3+SA7+Rgz+4wz+Kgv+ugr+OgT+Tg7+Mwv+Bw7+BAz+CQ7+ugv+GQv+oQz+vg3+xAr+dg3+Ng3+eA3+ZQr+mwn+HAz+fQ3+Ow3+OAn+PQ3+agf+Pgf+ZQz+JQ7+aAz+Jw7+Og3+4wP+1Av+owX+1A3+2Av+jg3+CQ3+cwz+wAz+ugn+kw3+NA7+dA7+Ng7+mgT+EQ3+rwf+KAf+ogr+Kgj+twf+LAj+ugf+fQ7+Mwz+oQ3+ZwP+KA3+pQ3+Twv+yQb+qA3+EQP+hQJSb2L+0wX+Vgv+Rg7+fQn+WwX+SQ7+AQ7+Dgv+OAf+0AT+tgL+mgv+6Qz+LQ3+UQ7+cQ3+Zwv+Mg3+DQ7+Vgz+dQ3+wA3+ng7+Ww7+oA7+Iwv+4gj+dAv+KAv+ygv+0AT+2gY3/g8D/qoO/swN/mQO/kIJ/p0J/qMO/uMD/h8M/rAO/uAK/rIO/kwN/rYJ/m8O/nQM/pIN/lEN/rkO/o4L/t8N/q0H/r4O/rEH/sAOYP62B/64B/4tCP48Dv5/Dv6iDf7jB/6bC/7EB/6GDP5+Av6zBP61BP63BP4/Bv7NB/4FA/6nCP6pCP6uDf7WDv7YB/6ODv5KDv7yDv5gBv5gBv5ODv6pB/5PDP5YCv6/Cv4xDf5bCP7lDv6iDP6cDv7oDv5aDv7QCP5cDv45Df59C/75DP6kDv4HCv79C/44B/5CAv70Dv5yCv6rDv58C/4pDv4eAv7lCP7TDf7+Dv7sA/7XDf4gAv7ZDf61Dv4LDf7oCv53DP7EDP7sCv7TAv7TA/69Dv4mCP6/Dv6zB/7ICf4PD/7DDv67B/40Cv6gDf5kCf7jBf7aBv7KDnr+OAb+nQL+oAL+sgf+OQhlYv4rAv4hA/4iD/6TDP42Cf7ZDv4nD/5NDP6FCf7QCjT+tgv+6gz+4Q7+ug3+cg3+BgL+aQX+Kgn+VQL+Dw7+EQ5j/hMO/hUOZP4XDv7xDP6WCf4aDv70DP43D/7EDf4DDf4UDP7vDv7HDf4+D/7HBf5jDv6sDv45D/5nDv6fBf5cDf6CC/7+Dv5LDf4eCv4CD/7aDf7eC/64Dv5zDv4ID/7ACf7kC/6OCG/+kAj+kgj+lAj+lgj+MQz+lgv+WQ3+xw7+mAz+lwP+Nwz+Fw/+OQz+wgb+oAP+8A1XaP7cAv4/CP7NCf67BP6OAv6cAv5VC/6KDv6RDP5mDf6NDv4lDf5wD/7xDv7qCf49BP7QCv6zAv5QDv4tD/4KDv6KBf5tBv4xD/6bDv5rC/5ZDv7zDP5vC/4zCf7sDv6iDv7XCP6OD/5iDP7FD/5sBP6SD/5DD/6MD/6TBv5nAv6YD/5KDf60Cf44C/5uDv6dD/5xDv4NDf54DP7FDP68Dv6qBv6nCf5eCf5gCf6fDf7LDP6tD/5qB/6gCP6lDf5sCf5WAv5vCf7DBv7XDP6kC/5jDf55Cf7UDv5TDzT+Iw/+tQj+aA3+xA/+0QT+ugr+aAf+AhD+5Af+LA/+BQz+Lg/+MAX+kAn+zw/+wwr+0Q/+GQ7+IAv+ww3+7A7+Xw7+2Q/+PQ3+BxD+Uwj+QQ3+2QL+7g/+qQn+dQP+2Ar+JAv+Zg7+tgz+aA7+7wP+SA3+Rw/+4w/+Lg7+jw3+Aw/+tg7+DA3+Pgv+Dg3+eQz+7A/+PwP+HxD+8A/+zwn+8g/+ZAn+agf+Swv+7gv+owj+wQb+xA5t/m0J/ssG/hoD/rED/iIN/nwJ/m4P/q8L/kgM/gcQ/rcK/uAH/mwH/soP/g0Q/swP/lMP/r0N/hIQ/hgO/ocP/hUQ/ooP/tYP/h8O/mAM/hkQ/j0P/joE/tMK/gYI/ssN/jUQ/qQL/iIQ/u0O/nsK/tAE/uIP/i0O/nAM/pwP/k0P/jIO/p8P/j8L/g8N/jMQ/lUDVmH+dwn+LAJ0/jkFc3r+DQ/+3QP+qApw/uIC/jcQ/uYN/kYG/k8I/kgG/jwQ/tYJ/vcP/m4J/nAE/j4Mcv6kC0L+dwl0/mUN/q8K/sIP/gUQ/rINMP6XA/6TA/6YDP63Av5OEP6XDv6fDP63Bf4QEP7JCP7mDv5YDv4UEP43Df5XEP7KCv7gA/7MCv6lDv6wC/6VEP4OCP51B/4dEP4pAv7VCv4SCv5jEP7XD/5/C/4eAv7SDf79Dv4qEP5pEP6DCv4xDv6eD/4GD/6gD/5vEP7jBP4kB/5yEP50EP4RA/53EP55EP5YD/5CEP4OAv58EP5+EP5dD/44EP6XCv7TCf6wD/4GCf4YD1tN/qgC/qoIUXVp/twJ/toD/hIK/lcD/v4P/r8P/t8M/nUP/gMQ/rEK/o8O/pQQ/lEK/p8IMP7tCf6ZEP7zCf6YDv4LDv5SEP5qC/5UEP7BC/6fDv5wC/6hDv5ZEP4nC/77DP5iDP6pEP64Av7UCv7bCf51Cv6vEP6sCf5cAv5ED/7vA/4rDv4pEP5oEP5tDv5qEP6/DP5OD/7cDf6UDf66Dv4JD/4/A0b+pQj+WAJ3/hIP/uoL/sEH/mYJ/s4Q/mwD/tAQ/nQK/oUCQf60D/6lC/7RDmX+jxD+4BD+2A7+kxD+lwP+Ewf+4Qct/mgF/mkF/gwQ/poQ/u0M/pkO/nQN/qAQ/lUQ/qIQ/usO/qQQ/hoG/u4O/vUQ/q0M/iQR/j8E/v8N/vUO/q4Q/ncK/hMK/v0Q/iMQ/kMJ/pUP/pMG/i4F/gYN/v8O/psP/rgQ/jsL/gUP/nIO/m4Q/jIQ/r4Q/qoG/o8K/pEK/igH/pMK/vEP/oAQ/sUF/mYJ/sgF/oQQ/vwK/jUF/gIF/vQN/toQ/iAEYf4gEf5HEP5HDP5rB/6XA/5gD/6FCf5wAv65Av7oEP5RDP4sEf6rB/7OD/6eEP4yD/4TEP4wEf7wEP7VD/7FC/7zEP5+Df6nEP5tCv5lEf6YB/46Ef5BD/4NCv76EP7WCv54Cv7+EP7fD/4oAzT+rw7+1gv+IAb+SQ/+Tgn+TA/+BxH+bBD+uxD+TBH+6w/+ThH+PwP+Cgn+ZAL+pQL+gQL+EhH+Wg3+mAr+HAL+QA7+DQL+1gz+8A3+KQj+UAX+Qgr+Dgn+DgJk/mER/uEM/l0F/v8N/iMR/pQQ/t4G/rYC/pgM/skP/pUO/nAN/nkP/uMO/m4R/lYO/hQG/qwJbv4QDv5LAv6BD2D+FA7+aQL+hA/+7hD+pQz+Ng/+MhH+qQz+hw3+iwX+YA7+ZBH+qhH+tQL++RD+Dwr++xD+PRH+sBD+dhH+QxH+/A7+hxH+bA7+sw7+5g/+axD+uhD+SxH+MRD+kBH+rAf+PwP+5Qv+lAv+lxH+8w/+tQv+yg7+pw3+qQ3+2Qz+EQn+RQ7+swj+sA3+GQn+sAv+sQL+mQL+sQL+1AT+dQf+KhH+6RD+mxD+bRH+7BD+8Az+WAz+wQ3+wRH+8RD+WBD+JBD+GAr+xg3+Ygz+7BH+bwr+sAz+9Q7+ewv+0Av+ZBD+rwn+TQz+ZxD+0xH+AQ/+SBH+Tw3+ShH+6Q/+UQ/+dQ7+cBD+KQL+fAz+Lwz+XAP+VBH+PQ7+gA7+mgr+Xg3+7wv+BQv+dAP+8A3+Ugb+iA7+bQ/+phH+sQ3+5wn+mQL+4wU0/rwG/j4E/gsQ/ncP/ssP/uoQ/s0P/vUR/jQN/p0O/jUP/hsO/sIR/n4G/t8P/v4R/q0M/rEC/uIH/qsQ/gQS/kMN/mUO/kER/iUQ/p8F/hMH/goS/m8M/gUR/g0S/pEN/sEM/o4R/tkR/lIP/hMS/sgM/hMN/t8R/jkQ/pcDOP6lDf7+Cmz+AQty/gMLSP4OAv6hAv4jEv7pEf5IEP5rB/6xAv5DBf6wAv5pB/7fDv7xCf54D/4OEP4tEf4REP7tEP6GD/7vEP7qDv76Ef51Ef78Ef6jDv45Ev7rEf7RBP4pEv6pDv59Ef4FEv7hCP7/EP5hC/5FEf6aD/6CCv7kCv65EP7oD/4wEP7qD/5NEv6REf6YDf6fBP7bA/7jDf6lBP5/EP4ZEv4UD/6uBP5ZEf5NC/4aD/6JDP60Bv7YDP5/B/6+BP7lAv5eEv6REP4lEv6zCv7mDP6YCv4+BP7jB/5qEf5SDv67Df7ACf4uEf4zD/7SD/6ID/7UD/7JCv7DEf6lEP41Ef5/Df5tCv6eEv5uCP5fEP6yDP6FDf5AEv75Dv7QDf6uCv5FEv67DP7UEf4GEf6CEv4PEv6EEv4REv67Dv6HEv6tEP6JEv6hBP6cDf6MEv7KEP5VEf6sBP7jBf6YB/6lDVP+Vwf+nhH+yAn+yw5o/rAH/pcI/poS/tMG/uEQ/iYP/uYM/tAK/gkQ/iwL/q8R/rkN/mkS/usQ/poO/lMQ/m0S/sAR/jUS/nAS/nsN/nIS/tgP/jYR/nUS/isN/gMS/nkS/j8S/igO/oMR/kEC/ooN/rUQ/gQR/rwS/kgS/nAO/r8S/lAP/t4N/qIP/jgO/jYF/jgF/jsO/hgS/hMP/hUE/mwH/uIR/swO/uQR/h4S/tMO/t0Q/tUO/mIR/uIQ/uYM/tYE/rgK/l8G/qIS/uIO/jEN/rMR/lEE/p8Q/qcS/qEQ/nMR/qsS/jcS/sQR/o0P/uwS/rAS/joK/hIT/t0P/gYS/rEQ/rcM/iQC/rQQ/tIR/kYS/vgS/oES/kkR/koS/tgR/oUS/hIS/sMS/qsG/gET/r4F/lES/pcK/mgD/lgR/hwS/j0Q/kEM/iAS/iAN/lQG/g0T/ugR/psS/uoR/iMT/tAE/nEC/kwQ/nYP/uAO/i4S/vMR/jAS/uMS/mwS/vcR/ukO/vkR/nQR/ukS/kES/v0R/sYR/icS/kgT/j0S/vAS/rUS/vIS/iAT/kMR/gIR/vYS/gsS/kcR/i8T/g4S/jET/hAS/v0S/kIL/jgO/jYG/jgG/noO/rIG/nwO/jkT/vgK/tIE/qUN/kkFZ/5LBXP+Mgr+lhJo/q0I/scG/swGZP7nEf75C/5FE/5gEv4nEv7fEP6FCf48BP5VCv5ME/5PEP4vEv5REP5QE/72Ef41Df40Ev6JD/42Ev5eDv44Ev5ZE/6xAv6GE/4mE/60DP7qEv6yEE7+Xgb+uhL+jQ3+DBL+ZhP+SRL+tw7+SxL+MxP+whL+2xH+JAj+Cw/+KAj+WQ/+Kwj+MQf+xA7+chP+Fw3+mQL+VRL+/wr+UQf+WRL+zw7+HhH+gRP+/A3+2BL+IhH+JhL+sQL+4Qf+KQ01/mIF/hUT/rER/hcT/jES/ucO/qgS/lYQ/pMT/tQI/psT/loQ/iIT/mES/tYE/pgM/iQO/l0T/s0N/l8T/q0S/nsK/uEH/p8T/kYR/oAS/tsL/r4S/mgT/sAS/moT/pcN/o0I/joI/t4R/gQT/hMR/m8C/jgH/oUG/oIO/s0J/qUK/vML/h4N/gID/lEHZP5kAv7ODmD+0hD+dxP+jhD+/w/+ghP+uxP+JQ/+2Q7+rgL+sgL+bAf+aAf+mwz+ZxL+TRP+bBH+igX+DA7+bxH+0A/+vxH++BH+5xL+VRP+HxP+1hP+xRH+WxD+bQj+/RP+eQL+1QT+mRP+RA3+zBP+JhD+bgT+fhL+5A/+Lw7+kA3++hL+3hP+/BL+NQ7+DBH+VQP+3RH+5wv+5RP+mBH+aAP+6Q3+Bwn+0Qz+tBP+Agv+iQL+zQb+1xL+Sgj++xP+sg3+ExT+UQr+5wz+LBL+ihP+KxH+Uw7+ahL+CBT+5BL+UhP+kRP+qhL+eg3+9wz+VxP+cxL+xhH+NRT+CQX+sxL+hA3+1BP+rQ7+FgX+Rg/+YxP+LRP+oRP+3BP+MBP+pBP+MhP+wRL+IxT+FBL+Vw3+jRL+BRP+rQT+XQ3+sQ/+wAb+kxL+HA/+TwX+/Q/+MRT+fgn+MxT+5wn+/RP+8w7+1QT+JxH+FBP+3xL+aBL+UBD+wQr+axL+jxP+MxL+0w/+wwv+HQ7+cgv+DxT+IRP+rxL+ngj+3gf+aRT+7xL+egv+8RL+QBH+txL+nBP+wRP+2RP+fxL+5Q/+vRL+UxT+LxD+IRT+CxH+/hL+Vg3+UBL+JxT+8w/+UxL+sxP+VxL+tRP+WhL+XBL+uRP+jA7++hP+ww/+NBT+fBT+YgX+0wT+6BP+wxP+4RL+TxP+phL+cRH+bhL+VBP+HhP+Hg7+GBT+dxH+PA/+EhT+nRT+SBT+rBD+9g7+kw/+/xD+Zgf+hRT+HBT+LBD+5w/++xL+3Q3+IhT+jRT+iBL+mg3+ixL+ng3+WhT+5hP+rQT+gxD+PRP+1gn+YBT+fA7+uwT+vQT+rgj+mRL++BP+uhP+MhT+mxT+ZxT+3gf+Pgf+KhL+DQv+KRH+LRL+ixP+ThP+xgz+pBT+ChT+UxP+DBT+qBT+dxT+NBH+qwz+ERT+exT+HAIy/t8G/kkU/iYO/nwL/igT/hkU/igQ/k8U/rsS/lEU/jAO/okU/k8P/roU/owU/msT/ncO/jcT/gMT/sEU/igU/pcD/jwT/l4U/u8L/ssO/lEL/vMT/gsT/pgU/sEP/poU/pIQ/tEU/hwC/uMH/twG/oUR/qEU/m8U/mgL/nEU/jIS/jQP/nQU/qcM/jgP/usU/qsU/ikL/v0T/rwG/m4E/ugU/kIP/gYS/rMU/vUS/iwT/u8U/mUT/lIU/mcT/lQU/mkT/rsU/pAL/scM/jkO/gIT/mkG/hUN/sIU/jgH/mgF/kAO/qUCbXP+Uwf+rAj+2BBy/mQU/tcO/mYU/k4K/hoV/oMMNf5gC/7WFP45FP7yEf4FFP7/Av4DEP5XDv4bE/5yEf5vEv4NFP6UE/5gE/50Ev6tFP4KFf6FBv4WFP62Ev4XCv76Dv4WBf4rE/4hDP5QFP4kFf7xFP4mFf6KFP70FP6hD/72FP66Bf5tE/6aDf6xBv6zBv4/Bv6wE/6CDP5xAv6lDf5ECv6uCP5GCv7wDf71E/5LBf47Ff4kD/7QFP4+Ff5jBv7aBv5BFf4NC/5mEv69Cv5FFf47FP6MCv7bFP7lEv4LFP6SE/7oEv5DFP6CFP7NE/56FP6PA/5fBv7hD/4dFf6xFP7eD/5gE/4oA/7ZDf4bFP4rEP60Dv6MEf7XEf4oFf71FP7HCP5ZCf54Dv5uE/46Bv57Dv6VEv5pFf7BB/4xFf5dFP7PEP6yD/7gAv6kBHf+whBp/nIJ/nMV/gQQ/pwS/g0L/okV/mAG/qwR/nkC/iwN/gMU/tgU/kYV/lED/hAG/oAV/j8U/hQV/hYQ/jMR/mUE/q4S/ngR/nsU/pcD/rEV/lQV/vgO/lYV/rgS/qAF/moO/gMR/mQT/tsT/l0V/qMT/l8V/goR/mEV/uET/iUH/lYP/gwP/sUQ/sEO/hAP/q8T/pAU/lIS/ukT/pES/nAD/isK/lEH/s8H/twM/ssG/h4N/nEV/vcT/kMT/vkT/s8U/ggV/nYV/q8P/s8E/tQE/mwE/okT/rUV/joU/qQS/n8V/hEV/scT/hwT/kwV/t8U/oEU/scV/iAO/uMU/okV/uoJ/tIT/n8U/l4T/kwU/qAF/oYR/loV/iMV/s0V/h4U/gQP/iAU/mAV/r0Q/qgT/ikC/vkIZ/77CP5SAv6gFf4DCf5sBP6lDf4PCf7aDP7jFf51A/4eDVf+uQdo/qwV/tkS/vwT/tcE/kIC/uEF/tIE/lMV/m0U/gQU/n4V/u0K/roV/pAT/rwV/qMQ/qwS/uEU/hAU/s4T/o8D/kMF/mkR/owV/noS/hcU/kQU/sgV/twP/pIV/rcQ/qIT/h8U/icV/t8T/ikV/tMV/hIW/hQW/qoP/i8V/igU/gQJ/nUT/gsJ/uYC/iEQ/vUL/rgE/gUV/kcO/gcV/q4V/q0U/j4H/mIF/nMP/tAE/vEV/nwV/msR/iwW/ikJ/vYV/i8R/qYU/t4U/kIU/qkU/jwW/v0V/jUW/iUW/pMD/sUV/gUW/s8E/rUU/pMV/tUR/pUV/oMS/osU/tIV/o0T/iQH/vkIev7ECf4bA/4ND/7KCf6OBf7NCf4WFv6YCv5cDf6lDf7YCf7LBv59Fv7MCf6qCP4OCv5sD/7NFP4kAv6QEP5VFv5GE/5QCv6YB/5xAv55Ff44FP7yFf59Ff70Ff50B/7GE/5iFv7mEv6DFf5NFf7gFP6/Ff7iFP7OE/7QCv6RFv6hEv6MFf48Ef7XCv4/Ef6UD/5CEv6TBv66Av5vFv5AFv4lFf7PFf7zFP7RFf4PFv73CP5xEP5zEP4+A/52EP4sAv7EEP6fEf57EP47Av7JEP4yDP6sD/45EP7TCf5NFv4DBf4NCf5QBf6NEP6lEf5fEv5jEf6iFv6ZAv5CAv63Av66Cv4OFf6ME/4FCv4uFv5zFP6pEv51FP5dDv7LE/5nFv6HFf7BFf7LFv63Cv4gB/47Ef5/Ef78EP55Cv7zEv6gBf4XBf5rDv5bFf4KFv4tEP4IEf4zDv68EP5NEf4QFlP+wBD+txb+wxD+ehD+xxD+vRb+gBb+agf+hAz+KxT+fgJX/qwJ/hEDYv6BAv6qCP4eFv4gFv7IFv6DE/7KFv5sB/4nEv49BP4/D/7QFv7ZFP5wFP49FP5RE/4vFv7VFv4VFf6LD/5PFf7GEf7cFv7RBP7KEf4QCv7hFv7ZCv7PEf4oA/4PBv6tFv5HEv5BFv4MFv5DFv50Fv6zFv5ZCf4OEf6cAv4QEf72Fv7qCf6jFf4XEf45DP6MDP6ODP6DAv61D/4DF/6LFv7fEP4PE/5KDv6iFv5cDf7jBf4+BP65Av5LE/6VFv5eFv6XFv7aFP5hFv5KFf5jFv6cFv76Ff6pFv5YE/7jFP44FzT+4wX+GBf+zBH+pxb+4hb+jxX+BgL+QQT+Hxf+LhP+rxb+Qhb+0BX+Bw/+JRf+xwz+0gz+zAn+xQn+9hb+sAL+FhH+eAL+0BD+AgP+Rgf+QRD+sAb+/xb+IA9y/oAT/gQX/o4W/mAS/qIW/r8T/k0O/hMH/skR/ioW/rYV/l8W/nMN/kIX/qUU/psW/kEU/nYU/joN/lAV/pAW/nAX/k0X/oAR/j4R/hUK/hcV/qsW/lkV/owN/toT/ocU/vkS/iIX/lgX/uwW/toR/rQW/kYE/pAK/qUP/lIR/kkW/n4O/sIU/lcR/s4S/rcPbf5dEf49Ef5XA/4GA/5sF/7qFf5WFv5/F/4iAv6FCf4/BP61Cv4LF/63Ff4QFf4OF/5yFP4TFf4RF/69Ff5WE/6GFf70EP56FP5vF/6kF/6BF/4aF/5tFv5iE/4iFf6gE/5cFf4LFv4uEP6xFv5ZF/7tFv6QF/5tBf6SF/6SCv6VF/7GDv7BFv5RCv7OEv4/EP5mF/7MBv5FCv79Av6gF/5lFP51Ff4NC/60F/5BBP4rEv4VFP50F/7zFf56D/41BP7TFv6tF/7JE/6EFf5OFf54FP47D/4pC/7UF/5+FP7LDf6mFv6BEf77Ff5+C/4pE/44B/5UF/7wFP69F/7qFv5tEP5MEv40E/7uFv6TEf7PBf6WEf7bFf46E/6QA/7KF/5lF/5WAv5CEP7OB3T+aRf+pBH+NBf+jRb+oRf+jxb+ohb+Ogr+3gb+PgT+BAn+qBf+dhf+6Qb+qxf+EhX+yBP+MRH+3xf+2Bb+sRf+GBX+dgv+CBj+ZgL+XBP+Pgn+5xf+gxf+ghH+URdO/kwX/j8W/iAX/lYX/owX/r8X/o4X/oYS/vQX/v0E/pUR/sAU/skS/o4S/gMJ/q8C/qUNSnVk/rkE/gQD/k4H/qAR/uEVdP7bDP7xAv4fEf4EGP4hEf49Ff7TF/7/E/5CAv7TBP4CEP7CE/7YF/6WFv7aF/4wD/4QGP73Ff5LFf6nFP5lFv6eFv4TBf6gFv6zF/5DGP7aBv62F/7NEf6oFv6FF/5/BF4="
            print(#bigOne)
            
            -- 21316
            local t = CompressedDb.static:decompress(bigOne)
            
            --print(#bigOne .. " => " .. Util.Objects.ToString(t))
            
            local Compressors = Compression.GetCompressors(
                    Compression.CompressorType.LibCompress,
                    Compression.CompressorType.LibDeflate
            )
    
            for _, compressor in pairs(Compressors) do
                print(format("%s", compressor:GetName()))
                local serialized = Serialize:Serialize(t)
                print(format("Serialized = %d", #serialized))
                local compressed = compressor:compress(serialized, false)
                print(format("Compressed = %d", #compressed))
                local encoded =  Base64:Encode(compressed)
                print(format("Encoded = %d", #encoded))
                
                local decoded = Base64:Decode(encoded)
                local uncompressed = compressor:decompress(decoded, false)
                local r, v = Serialize:Deserialize(uncompressed)
                --print(Util.Objects.ToString(v))
                --print(tostring(t==v))
                assert(Util.Tables.Equals(t, v, true))
            end
        end)
        --]]
        it("upgrades compression mechanism #1", function()
            local c_pairs = CompressedDb.static.pairs
            local c_ipairs = CompressedDb.static.ipairs
    
            for _, data in pairs({TestUpgradeData1, TestUpgradeData2}) do
                local db, cdb = NewDb(data)
        
                for k, _ in pairs(db.factionrealm) do
                    print(format("db pairs(%s)/get(%s)", tostring(k), tostring(k)) .. ' =>'.. Util.Objects.ToString(db.factionrealm[k]))
                end
                for k, _ in c_pairs(cdb) do
                    print(format("cdb pairs(%s)/get(%s)", tostring(k), tostring(k)) .. ' =>'.. Util.Objects.ToString(cdb:get(k)))
                end
        
                for k, _ in ipairs(db.factionrealm) do
                    print(format("db ipairs(%d)/get(%d)", k, k) .. ' =>' .. Util.Objects.ToString(db.factionrealm[k]))
                end
        
                for k, _ in c_ipairs(cdb) do
                    print(format("cdb ipairs(%d)/get(%d)", k, k) .. ' =>' .. Util.Objects.ToString(cdb:get(k)))
                end
                
                cdb = CompressedDb(cdb.db)
            end
        end)
    end)
end)