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
            award_defeat       = true,
            -- should EP be auto-awarded for wipes
            auto_award_defeat  = false,
            -- the percent of kil EP to award on defeat
            award_defeat_pct   = 0.25,
            -- EP values by creature
            -- These are represented as strings instead of numbers in order to facilitate
            -- easy access by path when reading/writing values
            creatures  = {
                -- Kurinaxx
                ['15348'] = 7,
                -- Rajaxx
                ['15341'] = 7,
                -- Moam
                ['15340'] = 7,
                -- Buru
                ['15370'] = 7,
                -- Ayamiss
                ['15369'] = 7,
                -- Ossirian
                ['15339'] = 10,
                -- Venoxis
                ['14507'] = 5,
                -- Jeklik
                ['14517'] = 5,
                -- Marli
                ['14510'] = 5,
                -- Thekal
                ['14509'] = 5,
                -- Arlokk
                ['14515'] = 5,
                -- Mandokir
                ['11382'] = 7,
                -- Gahzranka
                ['15114'] = 5,
                -- Wushoolay
                ['15085'] = 5,
                -- Renataki
                ['15084'] = 5,
                -- Grilek
                ['15082'] = 5,
                -- Hazzarah
                ['15083'] = 5,
                -- Jindo
                ['11380'] = 7,
                -- Hakkar
                ['14834'] = 8,
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
                -- Skeram
                ['15263'] = 26,
                -- Silithid Royalty (Three Bugs)
                ['silithid_royalty'] = 26,
                -- Battleguard Sartura
                ['15516'] = 26,
                -- Fankriss the Unyielding
                ['15510'] = 26,
                -- Viscidus
                ['15299'] = 26,
                -- Princess Huhuran
                ['15509'] = 26,
                -- Ouro
                ['15517'] = 26,
                -- Twin Emperors
                ['twin_emperors'] = 32,
                -- C'Thun
                ['15727'] = 38,
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

-- Mapping from translation key to actual creatures are part of encounter
local MultiCreatureEncounters = {
    ['silithid_royalty'] = Encounter:GetEncounterCreatureId(710),
    ['twin_emperors']    = Encounter:GetEncounterCreatureId(715),
}

do
    local defaults = EP.defaults.profile.raid
    
    -- update defaults to set scaling off for all raids
    for mapId, _ in pairs(Encounter.Maps) do
        defaults[tostring(mapId)] = {
            scaling = false,
            scaling_pct = 1.0,
        }
    end
    
    -- table for storing processed defaults which needed added as arguments
    -- Creatures indexed by map name
    local creature_ep = Tables.New()

    -- iterate all the creatures and group by map (instance)
    for _, id in Objects.Each(Tables.Keys(defaults.creatures)) do
        -- if you don't convert to number, library calls will fail
        local creature_id, creature, map = tonumber(id)
        -- also need to account for multi-creature encounters wherein display name
        -- is not one of the individual creatures
        if creature_id then
            creature, map = Encounter:GetCreatureDetail(creature_id)
        else
            -- take name from localization
            creature = L[id]
            creature_id = id
            _, map = Encounter:GetCreatureDetail(MultiCreatureEncounters[id][1])
        end
        
        local creatures = creature_ep[map] or Util.Tables.New()
        Tables.Push(creatures, {
            creature_id = creature_id,
            creature_name = creature,
        })
        creature_ep[map] = creatures
    end
    
    local creature_ep_args = EP.options.args.raid.args
    for _, key in Objects.Each(Tables.Sort(Tables.Keys(creature_ep))) do
        -- arguments that map to the map name (under which creatures will be attached)
        local map_args = Tables.New()
        
        -- key will be the map name
        -- add settings for scaling (reducing) EP and GP awards from the raid
        local mapId = Encounter:GetMapId(key)
        if mapId then
            local settingPrefix = 'raid.'..tostring(mapId)
            map_args[settingPrefix..'.scaling'] =  COpts.Toggle(L['scale_ep_gp'], 1, L['scale_ep_gp_desc'])
            map_args[settingPrefix..'.scaling_pct'] =  COpts.Range(
                    L['scale_ep_gp_pct'], 2, 0, 1, 0.01,
                    {
                        isPercent=true,
                        desc= L['scale_ep_gp_pct_desc'],
                        width='full',
                        hidden = function () return not EP.db.profile.raid[tostring(mapId)]['scaling'] end
                  }
            )
        end
        
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

function EP:ScaleIfRequired(value, mapId)
    Logging:Debug("EP:ScaleIfRequired() : value = %s, mapId = %s", tostring(value), tostring(mapId))
    if Util.Objects.IsNil(mapId) then
        -- only applicable if in instance and part of a raid
        -- todo : maybe this should also include groups?
        if IsInInstance() and IsInRaid() then
            _, _, _, _, _, _, _, mapId = GetInstanceInfo()
            Logging:Debug("EP:ScaleIfRequired() : mapId = %s via GetInstanceInfo()", tostring(mapId))
        end
    
        -- check again, if not found then return value
        if Util.Objects.IsNil(mapId) then
            Logging:Debug("EP:ScaleIfRequired() : Unable to determine map id, returning original value")
            return value
        end
    end
    
    local raidScalingSettings
    if next(AddOn.mlDb) and not Util.Objects.IsEmpty(AddOn:GetMasterLooterDbValue('raid', tostring(mapId))) then
        raidScalingSettings = AddOn:GetMasterLooterDbValue('raid', tostring(mapId))
        Logging:Debug("EP:ScaleIfRequired() : Scaling settings obtained from ML DB")
    else
        raidScalingSettings = self.db.profile.raid[tostring(mapId)]
        Logging:Debug("EP:ScaleIfRequired() : Scaling settings obtained from Effort Points Module")
    end
    
    Logging:Debug("EP:ScaleIfRequired() : mapId = %s, scaling_settings = %s", tostring(mapId), Util.Objects.ToString(raidScalingSettings))
    if raidScalingSettings then
        local scaleAward = raidScalingSettings.scaling or false
        local scalePct = raidScalingSettings.scaling_pct or 1.0
        -- if the raid has reduced (scaled) awards, apply them now
        if scaleAward then
            local scaled = Util.Numbers.Round(value * scalePct)
            Logging:Debug("EP:ScaleIfRequired() : Scaling %d by %.1f %% = %d", value, (scalePct * 100.0), scaled)
            return scaled
        else
            Logging:Debug("EP:ScaleIfRequired() : Scaling disabled for mapId = %s , returning original value", tostring(mapId))
            return value
        end
    else
        Logging:Debug("EP:ScaleIfRequired() : No scaling settings available for mapId = %s , returning original value", tostring(mapId))
        return value
    end
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
    
    local creatureIds = Encounter:GetEncounterCreatureId(encounter.id)
    local mapId = Encounter:GetEncounterMapId(encounter.id)
    Logging:Debug("OnEncounterEnd(%s) : mapId = %s, creatureIds = %s", Util.Objects.ToString(encounter:toTable()), tostring(mapId), Util.Objects.ToString(creatureIds))

    if creatureIds then
        local success = encounter:IsSuccess()
        -- normalize creature ids into a table, typically will only be one but may be multiple
        if not Util.Objects.IsTable(creatureIds) then
            creatureIds = { creatureIds }
        end
        
        local creatureEp
        -- this will handle the typical case where one creature per encounter
        for _, id in pairs(creatureIds) do
            creatureEp = self.db.profile.raid.creatures[tostring(id)]
            if not Util.Objects.IsNil(creatureEp) then
                break
            end
        end
        
        -- didn't find the mapping, see if a match in our multiple creature encounters
        if Util.Objects.IsNil(creatureEp) then
            creatureIds = Util.Tables.Sort(creatureIds)
            for encounter_name, creatures in pairs(MultiCreatureEncounters) do
                local compareTo = Util.Tables.Sort(Util.Tables.Copy(creatures))
                if Util.Tables.Equals(creatureIds, compareTo) then
                    creatureEp = self.db.profile.raid.creatures[encounter_name]
                    break
                end
            end
        end
        
        -- have EP and either victory or defeat with awarding of defeat EP
        if creatureEp and (success or (not success and awardDefeat)) then
            Logging:Debug("OnEncounterEnd(%s) : EP = %d", Util.Objects.ToString(encounter:toTable()), tonumber(creatureEp))
            
            creatureEp = tonumber(creatureEp)
            -- if defeat, scale EP based upon defeat percentage
            if not success then
                creatureEp = Util.Numbers.Round(creatureEp * self.db.profile.raid.award_defeat_pct)
                Logging:Debug("OnEncounterEnd(%s) : EP (Defeat) = %d", Util.Objects.ToString(encounter:toTable()), tonumber(creatureEp))
            end
    
            creatureEp = self:ScaleIfRequired(creatureEp, mapId)
            
            local award = Award()
            -- implicitly to group/raid
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
            local standbyRoster, standbyAwardPct = AddOn:StandbyModule():GetAwardRoster()
            if standbyRoster and Tables.Count(standbyRoster) > 0 and standbyAwardPct then
                award = Award()
                award:SetSubjects(Award.SubjectType.Standby, standbyRoster)
                award:SetAction(Award.ActionType.Add)
                award:SetResource(Award.ResourceType.Ep, Util.Numbers.Round(creatureEp * standbyAwardPct))
                award.description = L["standby"] .. ' : ' .. format(
                        success and L["award_n_ep_for_boss_victory"] or L["award_n_ep_for_boss_defeat"],
                        creatureEp, encounter.name
                )
                
                -- todo : do we want to prompt for standby/bench awards?
                AddOn:PointsModule():Adjust(award)
            end
        else
            Logging:Warn("OnEncounterEnd(%s) : No EP value found for Creature Id(s) %s",
                         Util.Objects.ToString(encounter:toTable()),
                         Util.Objects.ToString(creatureIds))
        end
    else
        Logging:Warn("OnEncounterEnd(%s) : No Creature Id found for Encounter",  Util.Objects.ToString(encounter:toTable()))
    end
end