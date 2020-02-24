TestCustomItems = {
    -- Classic P2
    [18422] = { 4, 74, "INVTYPE_NECK", "Horde" },       -- Head of Onyxia
    [18423] = { 4, 74, "INVTYPE_NECK", "Alliance" },    -- Head of Onyxia
    -- Classic P5
    [20928] = { 4, 78, "INVTYPE_SHOULDER" },    -- T2.5 shoulder, feet (Qiraji Bindings of Command)
    [20932] = { 4, 78, "INVTYPE_SHOULDER" },    -- T2.5 shoulder, feet (Qiraji Bindings of Dominance)
}

TestScalingConfig =  {
    weapon = {
        {1.5,'One-Hand Weapon'},
        {0.5, 'Off Hand Weapon / Tank Main Hand Weapon'},
        {0.15, 'Hunter One-Hand Weapon'},
    },
    weaponmainh = {
        {1.5, 'Main Hand Weapon'},
        {0.25, 'Hunter One Hand Weapon'},
    },
    weaponoffh = {
        {0.5, 'Off Hand Weapon'},
        {0.25, 'Hunter One Hand Weapon'},
    },
    ranged = {
        {2.0, 'Hunter Ranged'},
        {0.3, 'Non-Hunter Ranged'},
    }
}

-- Stub defaults for AceDB
DbScalingDefaults = {
    profile = {

    }
}

do
    local ConfigIndexMappings = {
        'scale',
        'comment',
    }

    for slot, config in pairs(TestScalingConfig) do
        local index = 1
        for _, config_entry in pairs(config) do
            for i=1, #config_entry do
                local profileEntryKey = slot .. '_' .. ConfigIndexMappings[i] .. '_' .. index
                DbScalingDefaults.profile[profileEntryKey] = config_entry[i]
            end
            index = index +1
        end
    end
end
