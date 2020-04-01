local _, AddOn = ...
local E = AddOn.Constants.Events

AddOn.Events = {
    [E.PartyLootMethodChanged]  = "OnEvent",
    [E.PartyLeaderChanged]      = "OnEvent",
    [E.GroupLeft]               = "OnEvent",
    [E.GuildRosterUpdate]       = "OnEvent",
    [E.RaidInstanceWelcome]     = "OnEvent",
    [E.PlayerEnteringWorld]     = "OnEvent",
    [E.PlayerRegenDisabled]     = "EnterCombat",
    [E.PlayerRegenEnabled]      = "LeaveCombat",
    [E.EncounterStart]          = "OnEvent",
    [E.EncounterEnd]            = "OnEvent",
    [E.LootSlotCleared]         = "OnEvent",
    [E.LootOpened]              = "LootOpened",
    [E.LootClosed]              = "LootClosed",
    [E.LootReady]               = "OnEvent",
}
