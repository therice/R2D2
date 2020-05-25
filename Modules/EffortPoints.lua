local _, AddOn = ...
local EP = AddOn:NewModule("EffortPoints", "AceHook-3.0", "AceEvent-3.0")
local Encounter = AddOn.Libs.Encounter
local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local Tables = Util.Tables
local Objects = Util.Objects
local Strings = Util.Strings
local COpts = AddOn.components.UI.ConfigOptions
local Award = AddOn.components.Models.Award
local Dialog = AddOn.Libs.Dialog

EP.defaults = {
    profile = {
        enabled = true,
        -- this is the minimum amount of EP needed to qualify for awards
        ep_min = 1,
        raid = {
            -- should EP be auto-awarded for kills
            auto_award_victory = true,
            -- should EP be awarded for defeats
            award_defeat       = false,
            -- should EP be auto-awarded for wipes
            auto_award_defeat  = false,
            -- the percent of kil EP to award on defeat
            award_defeat_pct   = 0.25,
            -- EP values by creature
            -- These are represented as strings instead of numbers in order to facilitate
            -- easy access by path when reading/writing values
            creatures  = {
                -- Lucifron
                ['12118'] = 10,
                -- Magmadar
                ['11982'] = 10,
                -- Gehennas
                ['12259'] = 10,
                -- Garr
                ['12057'] = 10,
                -- Geddon
                ['12056'] = 10,
                -- Shazzrah
                ['12264'] = 10,
                -- Sulfuron
                ['12098'] = 10,
                -- Golemagg
                ['11988'] = 10,
                -- Domo
                ['12018'] = 12,
                -- Ragnaros
                ['11502'] = 14,
                -- Onyxia
                ['10184'] = 12,
                -- Razorgore
                ['12435'] = 20,
                -- Vaelastrasz
                ['13020'] = 20,
                -- Broodlord
                ['12017'] = 20,
                -- Firemaw,
                ['11983'] = 20,
                -- Ebonroc
                ['14601'] = 20,
                -- Flamegor
                ['11981'] = 20,
                -- Chromaggus
                ['14020'] = 24,
                -- Nefarian
                ['11583'] = 28,
            }
        },
    }
}

EP.options = {
    name = L['ep'],
    desc = L['ep_desc'],
    args = {
        awards = {
            type = 'group',
            name = L['awards'],
            desc = L['awards_desc'],
            childGroups = "tab",
            args = {
                general = {
                    order  = 0,
                    type   = 'group',
                    name   = L['general_options'],
                    inline = true,
                    args = {
                        ep_min = COpts.Range("Minimum", 1, 0, 1000, 1,
                                             {
                                                 desc = "The minimum EP required to be eligible for awards"
                                             }),
                        
                    }
                },
                auto_award_settings = {
                    order = 1,
                    type = 'group',
                    name = L['awards'],
                    inline = true,
                    args = {
                        ['raid.auto_award_victory'] = COpts.Toggle(L['auto_award_victory'], 0, L['auto_award_victory_desc']),
                        ['raid.award_defeat'] = COpts.Toggle(L['award_defeat'], 1, L['award_defeat_desc']),
                        ['raid.auto_award_defeat'] = COpts.Toggle(L['auto_award_defeat'], 2, L['auto_award_defeat_desc'], function () return not EP.db.profile.raid.award_defeat end),
                        ['raid.award_defeat_pct'] = COpts.Range(L['award_defeat_pct'], 3, 0, 1, 0.01, {isPercent=true, desc= L['award_defeat_pct_desc'], disabled = function () return not EP.db.profile.raid.award_defeat end}),
                    }
                }
            }
        },
        raid = {
            type = 'group',
            name = L['raids'],
            desc = L['raids_desc'],
            childGroups = "tab",
            args = {
            }
        },
    }
}

do
    local defaults = EP.defaults.profile.raid
    -- table for storing processed defaults which needed added as arguments
    -- Creatures indexed by map name
    local creature_ep = Tables.New()

    -- iterate all the creatures and group by map (instance)
    for _, id in Objects.Each(Tables.Keys(defaults.creatures)) do
        -- if you don't convert to number, library calls will fail
        id = tonumber(id)
        local creature, map = Encounter:GetCreatureDetail(id)
        local creatures = creature_ep[map] or Util.Tables.New()
        Tables.Push(creatures, {
            creature_id = id,
            creature_name = creature,
        })
        creature_ep[map] = creatures
    end


    local creature_ep_args = EP.options.args.raid.args
    for _, key in Objects.Each(Tables.Sort(Tables.Keys(creature_ep))) do
        -- arguments that map to the map name (under which creatures will be attached)
        local map_args = Tables.New()
        -- iterate through all the creatures in the map
        for _, c in Objects.Each(creature_ep[key]) do
            local creature_args = Tables.New()
            -- the key is of format 'creature.id', which will then be used for
            -- reading/writing values from the "db"
            creature_args['raid.creatures.'..tostring(c.creature_id)] = COpts.Range(L['ep'], 1, 1, 100, 1)

            map_args[Strings.ToCamelCase(c.creature_name, ' ')] = {
                type = 'group',
                name = c.creature_name,
                args = creature_args,
            }
        end

        creature_ep_args[Strings.ToCamelCase(key, ' ')] = {
            type = 'group',
            name = key,
            args = map_args
        }
    end
end

function EP:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), EP.defaults)
    AddOn:SyncModule():AddHandler(
            self:GetName(),
            format("%s %s", L['ep'], L['settings']),
            function() return self.db.profile end,
            function(data) self:ImportData(data) end
    )
end

function EP:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end

function EP:OnEncounterEnd(encounter)
    if not encounter then
        Logging:Warn("EP:OnEncounterEnd() : No encounter provided")
        return
    end
    -- (1) lookup associated EP for encounter
    -- (2) scale based upon victory/defeat
    -- (3) award to current members of raid
    -- (4) award to anyone on standby (bench), scaled by standby percentage
    
    -- basic settings for awarding EP based upon encounter
    local autoAwardVictory =  self.db.profile.raid.auto_award_victory
    local awardDefeat = self.db.profile.raid.award_defeat
    local autoAwardDefeat = self.db.profile.raid.auto_award_defeat
    
    local creatureId = Encounter:GetEncounterCreatureId(encounter.id)
    if creatureId then
        local creatureEp = self.db.profile.raid.creatures[tostring(creatureId)]
        local success = encounter:IsSuccess()
        
        -- have EP and either victory or defeat with awarding of defeat EP
        if creatureEp and (success or (not success and awardDefeat)) then
            creatureEp = tonumber(creatureEp)
            -- if defeat, scale EP based upon defeat percentage
            if not success then
                creatureEp = math.floor(creatureEp * self.db.profile.raid.award_defeat_pct)
            end
            
            local award = Award()
            -- implictly to group/raid
            award:SetSubjects(Award.SubjectType.Raid)
            award:SetAction(Award.ActionType.Add)
            award:SetResource(Award.ResourceType.Ep, creatureEp)
            award.description = format(
                    success and L["award_n_ep_for_boss_victory"] or L["award_n_ep_for_boss_defeat"],
                    creatureEp, encounter.name
            )
    
            if (success and autoAwardVictory) or (not success and autoAwardDefeat) then
                AddOn:PointsModule():Adjust(award)
            else
                Dialog:Spawn(AddOn.Constants.Popups.ConfirmAdjustPoints, award)
            end
            
            -- now look at standby
            local standbyRoster, awardPct = AddOn:StandbyModule():GetAwardRoster()
            if standbyRoster and Tables.Count(standbyRoster) > 0 and awardPct then
                award = Award()
                award:SetSubjects(Award.SubjectType.Standby, standbyRoster)
                award:SetAction(Award.ActionType.Add)
                award:SetResource(Award.ResourceType.Ep, math.floor(creatureEp * awardPct))
                award.description = L["standby"] .. ' : ' .. format(
                        success and L["award_n_ep_for_boss_victory"] or L["award_n_ep_for_boss_defeat"],
                        creatureEp, encounter.name
                )
                
                -- todo : do we want to prompt for standby/bench awards?
                AddOn:PointsModule():Adjust(award)
            end
        else
            Logging:Warn("OnEncounterEnd(%s) : No EP value found for Creature Id %d", Util.Objects.ToString(encounter:toTable()), creatureId)
        end
    else
        Logging:Warn("OnEncounterEnd(%s) : No Creature Id found for Encounter",  Util.Objects.ToString(encounter:toTable()))
    end
end