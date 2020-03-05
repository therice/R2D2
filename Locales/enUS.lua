local L = LibStub("AceLocale-3.0"):NewLocale("R2D2", "enUS", true, true)
if not L then return end

L["chat version"] = "|cFF87CEFAR2D2 |cFFFFFFFFversion |cFFFFA500 %s"
L["chat_commands_config"]  = "Open the options interface (alternatives 'c')"
L["chat_commands_version"] = "Open the Version Checker (alternatives 'v' or 'ver')"
L["comment"] = "Comment"
L["comment_with_id"] = "Comment %d"
L["ep"] = "Effort Points"
L["ep_desc"] = "Effort Points (EP)"
L["equation"] = "Equation"
L["gp"] = "Gear Points"
L["gp_custom"] = "Gear Points (Custom)"
L["gp_custom_desc"] = "Gear Points (GP) Customization"
L["gp_custom_help"] = "Configure Gear Points (GP) for specific items (e.g. Head of Onyxia)"
L["gp_desc"] = "Gear Points (GP)"
L["gp_help"] = "Configure the formula for calculating Gear Points (GP) - including the base, coefficient, and any multipliers."
L["gp_tooltip_ilvl"] = "ItemLevel [R2D2] : %s"
L["gp_tooltip_gp"] = "GP [R2D2] : %d (%s)"
L["gp_tooltips"] = "Tooltip"
L["gp_tooltips_desc"] = "Gear Points (GP) on tooltips"
L["gp_tooltips_help"] = "Provide a Gear Point (GP) value for items on tooltips. This is the value that will be used for GP when an item is distributed."
L["item_lvl"] = "Item Level"
L["item_lvl_desc"] = "Item level serves as a rough indicator of the power and usefulness of an item, designed to reflect the overall benefit of using the item."
L["item_slot_with_name"] = "%s Item Slot"
L["logging"] = "Logging"
L["logging_desc"] = "Logging configuration"
L["logging_help"] = "Configuration settings for logging, such as threshold at which logging is emitted."
L["logging_threshold"] = "Logging threshold"
L["logging_threshold_desc"] = "All log events with lower level than the threshold level are ignored."
L["logging_window_toggle"] = "Toggle Logging Window"
L["logging_window_toggle_desc"] = "Toggle the display of the logging ouput window"
L["multiplier"] = "Multiplier"
L["multiplier_with_id"] = "Multiplier %d"
L["quality"] = "Quality"
L["quality_desc"] = "Quality determines the relationship of the item level (which determines the sizes of the stat bonuses on it) to the required level to equip it. It also determines the number of different stat bonuses."
L["quality_threshold"] = "Quality threshold"
L["quality_threshold_desc"] = "Only display GP values for items at or above this quality."
L["raids"] = "Raids"
L["raids_desc"] = "Raid Encounters"
L["slots"] = "Slots"
L["slot_multipler"] = "Slot Multiplier"
L["slot_comment"] = "Slot Comment"
L["version"] = "Version"