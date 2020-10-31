local lib = LibStub("LibEncounter-1.0", true)
-- todo : possibly collapse all into encounters
--
-- Currently supports the following raids
--
-- (40 person)
--  Molten Core
--  Onyxia's Lair
--  Blackwing Lair
--  Temple of Ahn'Qiraj
--  Naxxramas
--
-- (20 person)
--  Ancient Zul'Gurub
--  Ruins of Ahn'Qiraj
--
-- Mapping from map id to details (name will be used as index for localization)
lib.Maps = {
    [309] = {
        name = 'Ancient Zul\'Gurub',
    },
    [509] = {
        name = 'Ruins of Ahn\'Qiraj',
    },
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
        name = 'Temple of Ahn\'Qiraj',
    },
    [533] = {
        name = 'Naxxramas',
    },
}


-- Mapping from creature id to details (name will be used as index for localization)
lib.Creatures = {
    [15348] = {
        name = 'Kurinnaxx',
    },
    [15341] = {
        name = 'General Rajaxx',
    },
    [15340] = {
        name = 'Moam',
    },
    [15370] = {
        name = 'Buru the Gorger',
    },
    [15369] = {
        name = 'Ayamiss the Hunter',
    },
    [15339] = {
        name = 'Ossirian the Unscarred',
    },
    [14507] = {
        name = 'High Priest Venoxis',
    },
    [14517] = {
        name = 'High Priestess Jeklik',
    },
    [14510] = {
        name = 'High Priestess Mar\'li',
    },
    [14509] = {
        name = 'High Priest Thekal',
    },
    [14515] = {
        name = 'High Priestess Arlokk',
    },
    [11382] = {
        name = 'Bloodlord Mandokir',
    },
    [15114] = {
        name = 'Gahz\'ranka',
    },
    [15085] = {
        name = 'Wushoolay',
    },
    [15084] = {
        name = 'Renataki',
    },
    [15082] = {
        name = 'Gri\'lek',
    },
    [15083] = {
        name = 'Hazza\'rah',
    },
    [11380] = {
        name = 'Jin\'do the Hexxer',
    },
    [14834] = {
        name = 'Hakkar',
    },
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
        name = 'Baron Geddon',
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
    [15263] = {
        name = 'The Prophet Skeram',
    },
    [15544] = {
        name = 'Vem'
    },
    [15511] = {
        name = 'Lord Kri'
    },
    [15543] = {
        name = 'Princess Yauj'
    },
    [15516] = {
        name = 'Battleguard Sartura'
    },
    [15510] = {
        name = 'Fankriss the Unyielding'
    },
    [15299] = {
        name = 'Viscidus'
    },
    [15509] = {
        name = 'Princess Huhuran'
    },
    [15276] = {
        name = 'Emperor Vek\'lor'
    },
    [15275] = {
        name = 'Emperor Vek\'nilash'
    },
    [15517] = {
        name = 'Ouro'
    },
    [15727] = {
        name = 'C\'Thun'
    },
    [15956] = {
        name = 'Anub\'Rekhan'
    },
    [15953] = {
        name = 'Grand Widow Faerlina'
    },
    [15952] = {
        name = 'Maexxna'
    },
    [15954] = {
        name = 'Noth the Plaguebringer'
    },
    [15936] = {
        name = 'Heigan the Unclean'
    },
    [16011] = {
        name = 'Loatheb'
    },
    [16061] = {
        name = 'Instructor Razuvious'
    },
    [16060] = {
        name = 'Gothik the Harvester'
    },
    [16062] = {
        name = 'Highlord Mograine'
    },
    [16063] = {
        name = 'Sir Zeliek'
    },
    [16064] = {
        name = 'Thane Korth\'azz'
    },
    [16065] = {
        name = 'Lady Blaumeux'
    },
    [16028] = {
        name = 'Patchwerk'
    },
    [15931] = {
        name = 'Grobbulus'
    },
    [15932] = {
        name = 'Gluth'
    },
    [15928] = {
        name = 'Thaddius'
    },
    [15989] = {
        name = 'Sapphiron'
    },
    [15990] = {
        name = 'Kel\'Thuzad'
    },
}

-- Mapping from encounter id to details
lib.Encounters = {
    -- Kurinaxx
    [718] = {
        map_id = 509,
        creature_id = {15348},
    },
    -- Rajaxx
    [719] = {
        map_id = 509,
        creature_id = {15341},
    },
    -- Moam
    [720] = {
        map_id = 509,
        creature_id = {15340},
    },
    -- Buru
    [721] = {
        map_id = 509,
        creature_id = {15370},
    },
    -- Ayamiss
    [722] = {
        map_id = 509,
        creature_id = {15369},
    },
    -- Ossirian
    [723] = {
        map_id = 509,
        creature_id = {15339},
    },
    -- Venoxis
    [784] = {
        map_id = 309,
        creature_id = {14507},
    },
    -- Jeklik
    [785] = {
        map_id = 309,
        creature_id = {14517},
    },
    -- Marli
    [786] = {
        map_id = 309,
        creature_id = {14510},
    },
    -- Thekal
    [789] = {
        map_id = 309,
        creature_id = {14509},
    },
    -- Arlokk
    [791] = {
        map_id = 309,
        creature_id = {14515},
    },
    -- Mandokir
    [787] = {
        map_id = 309,
        creature_id = {11382},
    },
    -- Gahzranka
    [790] = {
        map_id = 309,
        creature_id = {15114},
    },
    -- Edge of Madness
    [788] = {
        map_id = 309,
        creature_id = {15082, 15083, 15084, 15085},
    },
    -- Jindo
    [792] = {
        map_id = 309,
        creature_id = {11380},
    },
    -- Hakkar
    [793] = {
        map_id = 309,
        creature_id = {14834},
    },
    -- Lucifron
    [663] = {
        map_id = 409,
        creature_id = {12118},
    },
    -- Magmadar
    [664] = {
        map_id = 409,
        creature_id = {11982},
    },
    -- Gehennas
    [665] = {
        map_id = 409,
        creature_id = {12259},
    },
    -- Garr
    [666] = {
        map_id = 409,
        creature_id = {12057},
    },
    -- Geddon
    [668] = {
        map_id = 409,
        creature_id = {12056},
    },
    -- Shazzrah
    [667] = {
        map_id = 409,
        creature_id = {12264},
    },
    -- Sulfuron
    [669] = {
        map_id = 409,
        creature_id = {12098},
    },
    -- Golemagg
    [670] = {
        map_id = 409,
        creature_id = {11988},
    },
    -- Majordomo
    [671] = {
        map_id = 409,
        creature_id = {12018},
    },
    -- Ragnaros
    [672] = {
        map_id = 409,
        creature_id = {11502},
    },
    -- Onyxia
    [1084] = {
        map_id = 249,
        creature_id = {10184},
    },
    -- Razorgore
    [610] = {
        map_id = 469,
        creature_id = {12435},
    },
    -- Vaelastrasz
    [611] = {
        map_id = 469,
        creature_id = {13020},
    },
    -- Broodlord
    [612] = {
        map_id = 469,
        creature_id = {12017},
    },
    -- Firemaw
    [613] = {
        map_id = 469,
        creature_id = {11983},
    },
    -- Ebonroc
    [614] = {
        map_id = 469,
        creature_id = {14601},
    },
    -- Flamegor
    [615] = {
        map_id = 469,
        creature_id = {11981},
    },
    -- Chromaggus
    [616] = {
        map_id = 469,
        creature_id = {14020},
    },
    -- Nefarian
    [617] = {
        map_id = 469,
        creature_id = {11583},
    },
    -- Skeram
    [709] = {
        map_id = 531,
        creature_id = {15263},
    },
    -- Silithid Royalty (Three Bugs)
    [710] = {
        map_id = 531,
        creature_id = {15544, 15511, 15543},
    },
    -- Battleguard Sartura
    [711] = {
        map_id = 531,
        creature_id = {15516},
    },
    -- Fankriss the Unyielding
    [712] = {
        map_id = 531,
        creature_id = {15510},
    },
    -- Viscidus
    [713] = {
        map_id = 531,
        creature_id = {15299},
    },
    -- Princess Huhuran
    [714] = {
        map_id = 531,
        creature_id = {15509},
    },
    -- Twin Emperors
    [715] = {
        map_id = 531,
        creature_id = {15275, 15276},
    },
    -- Ouro
    [716] = {
        map_id = 531,
        creature_id = {15517},
    },
    -- C'Thun
    [717] = {
        map_id = 531,
        creature_id = {15727},
    },
    -- Anub'Rekhan
    [1107] = {
        map_id = 533,
        creature_id = {15956},
    },
    -- Faerlina
    [1110] = {
        map_id = 533,
        creature_id = {15953},
    },
    -- Maexxna
    [1116] = {
        map_id = 533,
        creature_id = {15952},
    },
    -- Noth
    [1117] = {
        map_id = 533,
        creature_id = {15954},
    },
    -- Heigan
    [1112] = {
        map_id = 533,
        creature_id = {15936},
    },
    -- Loatheb
    [1115] = {
        map_id = 533,
        creature_id = {16011},
    },
    -- Razuvious
    [1113] = {
        map_id = 533,
        creature_id = {16061},
    },
    -- Gothik
    [1109] = {
        map_id = 533,
        creature_id = {16060},
    },
    -- Four Horsemen
    [1121] = {
        map_id = 533,
        creature_id = {16062, 16063, 16064, 16065},
    },
    -- Patchwerk
    [1118] = {
        map_id = 533,
        creature_id = {16028},
    },
    -- Grobbulus
    [1111] = {
        map_id = 533,
        creature_id = {15931},
    },
    -- Gluth
    [1108] = {
        map_id = 533,
        creature_id = {15932},
    },
    -- Thaddius
    [1120] = {
        map_id = 533,
        creature_id = {15928},
    },
    -- Sapphiron
    [1119] = {
        map_id = 533,
        creature_id = {15989},
    },
    -- Kel'Thuzad
    [1114] = {
        map_id = 533,
        creature_id = {15990},
    },
}
