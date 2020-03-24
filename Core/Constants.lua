local name, AddOn = ...

AddOn.Constants = {
    name    =   name,
    chat    =   "chat",
    group   =   "group",
    guild   =   "guild",
    player  =   "player",
    party   =   "party",

    Channels = {
        None        =   "NONE",
        Guild       =   "GUILD",
        Instance    =   "INSTANCE_CHAT",
        Officer     =   "OFFICER",
        Party       =   "PARTY",
        Raid        =   "RAID",
        RaidWarning =   "RAID_WARNING",
        Whisper     =   "WHISPER",
    },

    Commands = {
        Awarded                 =   "Awarded",
        Candidates              =   "Candidates",
        CandidatesRequest       =   "CandidatesRequest",
        HandleLootStart         =   "HandleLootStart",
        HandleLootStop          =   "HandleLootStop",
        LootAck                 =   "LootAck",
        LootTable               =   "LootTable",
        LootTableAdd            =   "LootTableAdd",
        LootSessionEnd          =   "LootSessionEnd",
        MasterLooterDb          =   "MasterLooterDb",
        MasterLooterDbRequest   =   "MasterLooterDbRequest",
        MasterLooterDbCheck     =   "MasterLooterDbCheck",
        OfflineTimer            =   "OfflineTimer",
        PlayerInfo              =   "PlayerInfo",
        PlayerInfoRequest       =   "PlayerInfoRequest",
        Reconnect               =   "Reconnect",
        ReconnectData           =   "ReconnectData",
        Response                =   "Response",
        Roll                    =   "Roll",
        Rolls                   =   "Rolls",
        StartHandleLoot         =   "StartHandleLoot",
    },

    DropDowns = {
        AllocateRightClick      =   name .. "_Allocate_RightClick",
        AllocateFilter          =   name .. "_Allocate_Filter"
    },

    Events = {
        EncounterEnd            =   "ENCOUNTER_END",
        EncounterStart          =   "ENCOUNTER_START",
        GuildRosterUpdate       =   "GUILD_ROSTER_UPDATE",
        GroupLeft               =   "GROUP_LEFT",
        LootClosed              =   "LOOT_CLOSED",
        LootOpened              =   "LOOT_OPENED",
        LootReady               =   "LOOT_READY",
        LootSlotCleared         =   "LOOT_SLOT_CLEARED",
        PartyLootMethodChanged  =   "PARTY_LOOT_METHOD_CHANGED",
        PartyLeaderChanged      =   "PARTY_LEADER_CHANGED",
        PlayerEnteringWorld     =   "PLAYER_ENTERING_WORLD",
        PlayerRegenEnabled      =   "PLAYER_REGEN_ENABLED",
        PlayerRegenDisabled     =   "PLAYER_REGEN_DISABLED",
        RaidInstanceWelcome     =   "RAID_INSTANCE_WELCOME",
    },

    Messages = {
        MasterLooterAddItem     =   name .. "_MasterLooterAddItem",
        MasterLooterBuildDb     =   name .. "_MasterLooterBuildDb",
        SessionChangedPost      =   name .. "_SessionChangedPost"
    },

    Popups = {
        ConfirmAbort            =   name .. "_ConfigAbort",
        ConfirmAward            =   name .. "_ConfirmAward"
    },

    Responses = {
        Disabled                =   "Disabled",
        NotInRaid               =   "NotInRaid",
    }

}