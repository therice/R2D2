local _, AddOn = ...
local E = AddOn.Constants.Events

AddOn.Events = {
    [E.EncounterStart]          = "OnEvent",
    [E.EncounterEnd]            = "OnEvent",
    [E.GroupLeft]               = "OnEvent",
    [E.LootSlotCleared]         = "OnEvent",
    [E.LootOpened]              = "LootOpened",
    [E.LootClosed]              = "LootClosed",
    [E.LootReady]               = "OnEvent",
    [E.PartyLootMethodChanged]  = "OnEvent",
    [E.PartyLeaderChanged]      = "OnEvent",
    [E.PlayerEnteringWorld]     = "OnEvent",
    [E.PlayerRegenDisabled]     = "EnterCombat",
    [E.PlayerRegenEnabled]      = "LeaveCombat",
    [E.RaidInstanceWelcome]     = "OnEvent",
}
