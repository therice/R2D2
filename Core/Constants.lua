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
        Candidates          =   "Candidates",
        LootTable           =   "LootTable",
        LootTableAdd        =   "LootTableAdd",
        MasterLooterDb      =   "MasterLooterDb",
        MasterLooterDbCheck =   "MasterLooterDbCheck",
        PlayerInfoRequest   =   "PlayerInfoRequest",
        PlayerInfo          =   "PlayerInfo",
    },

    Messages = {
        MasterLooterAddItem =   name .. "_MasterLooterAddItem",
        MasterLooterBuildDb =   name .. "_MasterLooterBuildDb"
    }
}