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
        Bagged                  =   "Bagged",
        Candidates              =   "Candidates",
        CandidatesRequest       =   "CandidatesRequest",
        ChangeResponse          =   "ChangeResponse",
        HandleLootStart         =   "HandleLootStart",
        HandleLootStop          =   "HandleLootStop",
        LootAck                 =   "LootAck",
        LootHistoryAdd          =   "LootHistoryAdd",
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
        ReRoll                  =   "ReRoll",
        Roll                    =   "Roll",
        Rolls                   =   "Rolls",
        StartHandleLoot         =   "StartHandleLoot",
        VersionCheck            =   "VersionCheck",
        VersionCheckReply       =   "VersionCheckReply",
    },

    DropDowns = {
        AllocateRightClick      =   name .. "_Allocate_RightClick",
        AllocateFilter          =   name .. "_Allocate_Filter"
    },

    Events = {
        ChatMessageWhisper      =   "CHAT_MSG_WHISPER",
        EncounterEnd            =   "ENCOUNTER_END",
        EncounterStart          =   "ENCOUNTER_START",
        GroupRosterUpdate       =   "GROUP_ROSTER_UPDATE",
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
        AwardFailed             =   name .. "_AwardFailed",
        AwardSuccess            =   name .. "_AwardSuccess",
        ConfigTableChanged      =   name .. "_ConfigTableChanged",
        LootHistorySend         =   name .. "_LootHistorySend",
        MasterLooterAddItem     =   name .. "_MasterLooterAddItem",
        MasterLooterBuildDb     =   name .. "_MasterLooterBuildDb",
        SessionChangedPost      =   name .. "_SessionChangedPost"
    },

    Modes = {
        Standard                =   0x01,
        Test                    =   0x02,
        Develop                 =   0x04,
    },
    
    Popups = {
        ConfirmAdjustPoints     =   name .. "_ConfirmAdjustPoints",
        ConfirmAbort            =   name .. "_ConfigAbort",
        ConfirmAward            =   name .. "_ConfirmAward",
        ConfirmReannounceItems  =   name .. "_ConfirmReannounceItems",
        ConfirmUsage            =   name .. "_ConfirmUsage",
    },

    Responses = {
        Disabled                =   "Disabled",
        NotInRaid               =   "NotInRaid",
    },

    VersionStatus = {
        Current   = "Current",
        OutOfDate = "OutOfDate"
    }
}