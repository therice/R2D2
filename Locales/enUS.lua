local L = LibStub("AceLocale-3.0"):NewLocale("R2D2", "enUS", true, true)
if not L then return end

L["chat version"] = "|cFF87CEFAR2D2 |cFFFFFFFFversion |cFFFFA500 %s"
L["chat_commands_config"]  = "Open the options interface (alternatives 'c')"
L["chat_commands_version"] = "Open the Version Checker (alternatives 'v' or 'ver')"
L["gp_tooltip_ilvl"] = "ItemLevel [R2D2] : %s"
L["gp_tooltip_gp"] = "GP [R2D2] : %d (%s)"
L["gp_tooltips"] = "Tooltip"
L["gp_tooltips_desc"] = "GP on tooltips"
L["gp_tooltips_help"] = "Provide a GP value for items on tooltips. This is the value that will be used for GP when an item is distributed."