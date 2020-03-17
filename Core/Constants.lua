local name, AddOn = ...

AddOn.Constants = {
    name    =   name,
    group   =   "group",
    guild   =   "guild",
    player  =   "player",

    Channels = {
        Guild       =   "GUILD",
        Instance    =   "INSTANCE_CHAT",
        Officer     =   "OFFICER",
        Party       =   "PARTY",
        Raid        =   "RAID",
        Whisper     =   "WHISPER",
    },

    Commands = {
        Candidates          =   "Candidates",
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