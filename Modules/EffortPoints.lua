local _, AddOn = ...
local EP        = AddOn:NewModule("EffortPoints", "AceHook-3.0", "AceEvent-3.0")
local Encounter = AddOn.Libs.Encounter
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Tables    = Util.Tables
local Objects   = Util.Objects
local Strings   = Util.Strings
local COpts     = AddOn.components.UI.ConfigOptions

EP.defaults = {
    profile = {
        enabled = true,
        -- should EP be auto-awarded for kills, maybe needs pushed down to creature?
        auto_award = false,
        -- EP values by creature
        -- These are represented as strings instead of numbers in order to facilitate
        -- easy access by path when reading/writing values
        creatures = {
            -- Lucifron
            ['12118'] = 1,
            -- Magmadar
            ['11982'] = 1,
            -- Gehennas
            ['12259'] = 1,
            -- Garr
            ['12057'] = 1,
            -- Geddon
            ['12056'] = 1,
            -- Shazzrah
            ['12264'] = 1,
            -- Sulfuron
            ['12098'] = 1,
            -- Golemagg
            ['11988'] = 1,
            -- Domo
            ['12018'] = 1,
            -- Ragnaros
            ['11502'] = 1,
            -- Onyxia
            ['10184'] = 1,
            -- Razorgore
            ['12435'] = 1,
            -- Vaelastrasz
            ['13020'] = 1,
            -- Broodlord
            ['12017'] = 1,
            -- Firemaw,
            ['11983'] = 1,
            -- Ebonroc
            ['14601'] = 1,
            -- Flamegor
            ['11981'] = 1,
            -- Chromaggus
            ['14020'] = 1,
            -- Nefarian
            ['11583'] = 1,
        }
    }
}

EP.options = {
    name = L['ep'],
    desc = L['ep_desc'],
    args = {
        raids = {
            type = 'group',
            name = L['raids'],
            desc = L['raids_desc'],
            childGroups = "tab",
            args = {
            }
        },
        foo = {
            type = 'group',
            name = 'foo',
            desc = 'Foo',
            args = {

            }
        },
    }
}

do
    local defaults = EP.defaults.profile
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


    local creature_ep_args = EP.options.args.raids.args
    for _, key in Objects.Each(Tables.Sort(Tables.Keys(creature_ep))) do
        -- arguments that map to the map name (under which creatures will be attached)
        local map_args = Tables.New()
        -- iterate through all the creatrues in the map
        for _, c in Objects.Each(creature_ep[key]) do
            local creature_args = Tables.New()
            -- the key is of format 'creature.id', which will then be used for
            -- reading/writing values from the "db"
            creature_args['creatures.'..tostring(c.creature_id)] = COpts.Range(L['ep'], 1, 1, 100, 1)

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
end

function EP:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
end