local _, AddOn = ...
local EP        = AddOn:NewModule("EffortPoints", "AceHook-3.0", "AceEvent-3.0")
local Encounter = AddOn.Libs.Encounter
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Tables    = Util.Tables
local Objects   = Util.Objects
local COpts     = AddOn.components.UI.ConfigOptions

EP.defaults = {
    profile = {
        -- should EP be auto-awarded for kills
        auto_award = false,
        -- EP values by creature
        creatures = {
            -- Lucifron
            [12118] = 1,
            -- Magmadar
            [11982] = 1,
            -- Gehennas
            [12259] = 1,
            -- Garr
            [12057] = 1,
            -- Geddon
            [12056] = 1,
            -- Shazzrah
            [12264] = 1,
            -- Sulfuron
            [12098] = 1,
            -- Golemagg
            [11988] = 1,
            -- Domo
            [12018] = 1,
            -- Ragnaros
            [11502] = 1,
            -- Onyxia
            [10184] = 1,
            -- Razorgore
            [12435] = 1,
            -- Vaelastrasz
            [13020] = 1,
            -- Broodlord
            [12017] = 1,
            -- Firemaw,
            [11983] = 1,
            -- Ebonroc
            [14601] = 1,
            -- Flamegor
            [11981] = 1,
            -- Chromaggus
            [14020] = 1,
            -- Nefarian
            [11583] = 1,
        }
    }
}

EP.options = {
    name = L['ep'],
    desc = L['ep_desc'],
    args = {

    }
}

do
    local epdefaults = EP.defaults.profile
    -- table for storing processed defaults which needed added as arguments
    local raidep = Tables.New()

    -- iterate all the creatures and group by intance
    for _, id in Objects.Each(Tables.Keys(epdefaults)) do

    end
end

function EP:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), EP.defaults)

    --for _, id in Objects.Each(Tables.Keys(EP.defaults.profile.instances)) do
    --    Logging:Debug("%s = %s", id, AddOn.Libs.Tourist:GetMapNameByIDAlt(id))
    --end
end