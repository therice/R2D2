local lib = LibStub("LibEncounter-1.0", true)

-- todo : possibly collapse all into encounters
--
-- Currently supports the following raids
--
--  Molten Core
--  Onyxia's Lair
--  Blackwing Lair
--

-- Mapping from map id to details (name will be used as index for localization)
lib.Maps = {
    [409] = {
        name = 'Molten Core',
    },
    [249] = {
        name = 'Onyxia\'s Lair',
    },
    [469] = {
        name = 'Blackwing Lair',
    },
    [531] = {
        name = 'Ahn\'Qiraj Temple',
    },
    [533] = {
        name = 'Naxxramas',
    },
}

-- Mapping from creature id to details (name will be used as index for localization)
lib.Creatures = {
    [12118] = {
        name = 'Lucifron',
    },
    [11982] = {
        name = 'Magmadar',
    },
    [12259] = {
        name = 'Gehennas',
    },
    [12057] = {
        name = 'Garr',
    },
    [12056] = {
        name = 'Baron Geddon"',
    },
    [12264] = {
        name = 'Shazzrah',
    },
    [12098] = {
        name = 'Sulfuron Harbinger',
    },
    [11988] = {
        name = 'Golemagg the Incinerator',
    },
    [12018] = {
        name = 'Majordomo Executus',
    },
    [11502] = {
        name = 'Ragnaros',
    },
    [10184] = {
        name = 'Onyxia',
    },
    [12435] = {
        name = 'Razorgore the Untamed',
    },
    [13020] = {
        name = 'Vaelastrasz the Corrupt',
    },
    [12017] = {
        name = 'Broodlord Lashlayer',
    },
    [11983] = {
        name = 'Firemaw',
    },
    [14601] = {
        name = 'Ebonroc',
    },
    [11981] = {
        name = 'Flamegor',
    },
    [14020] = {
        name = 'Chromaggus',
    },
    [11583] = {
        name = 'Nefarian',
    },
}

-- Mapping from encounter id to details
lib.Encounters = {
    -- Lucifron
    [663] = {
        map_id = 409,
        creature_id = 12118,
    },
    -- Magmadar
    [664] = {
        map_id = 409,
        creature_id = 11982,
    },
    -- Gehennas
    [665] = {
        map_id = 409,
        creature_id = 12259,
    },
    -- Garr
    [666] = {
        map_id = 409,
        creature_id = 12057,
    },
    -- Geddon
    [668] = {
        map_id = 409,
        creature_id = 12056,
    },
    -- Shazzrah
    [667] = {
        map_id = 409,
        creature_id = 12264,
    },
    -- Sulfuron
    [669] = {
        map_id = 409,
        creature_id = 12098,
    },
    -- Golemagg
    [670] = {
        map_id = 409,
        creature_id = 11988,
    },
    -- Majordomo
    [671] = {
        map_id = 409,
        creature_id = 12018, -- todo :  11663 and 11664
    },
    -- Ragnaros
    [672] = {
        map_id = 409,
        creature_id = 11502,
    },
    -- Onyxia
    [1084] = {
        map_id = 249,
        creature_id = 10184,
    },
    -- Razorgore
    [610] = {
        map_id = 469,
        creature_id = 12435,
    },
    -- Vaelastrasz
    [611] = {
        map_id = 469,
        creature_id = 13020,
    },
    -- Broodlord
    [612] = {
        map_id = 469,
        creature_id = 12017,
    },
    -- Firemaw
    [613] = {
        map_id = 469,
        creature_id = 11983,
    },
    -- Ebonroc
    [614] = {
        map_id = 469,
        creature_id = 14601,
    },
    -- Flamegor
    [615] = {
        map_id = 469,
        creature_id = 11981,
    },
    -- Chromaggus
    [616] = {
        map_id = 469,
        creature_id = 14020,
    },
    -- Nefarian
    [617] = {
        map_id = 469,
        creature_id = 11583,
    },
}
