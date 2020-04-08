local L = LibStub("AceLocale-3.0"):NewLocale("R2D2", "enUS", true, true)
if not L then return end

L["abort"] = "Abort"
L["action_type"] = "Action Type"
L["add_note"] = "Add Note"
L["add_note_desc"] = "Click to add note"
L["add_rolls"] = "Add Rolls"
L["adjust"] = "Adjust"
L["adjust_ep"] = "Adjust EP"
L["adjust_gp"] = "Adjust GP"
L["all_items_have_been_awarded"] = "All items have been awarded and the loot session concluded"
L["all_unawarded_items"] = "All un-awarded items"
L["always_show_tooltip_howto"] = "Double click to toggle tooltip"
L["announce_item_text"] = "Items under consideration:"
L["announced_awaiting_answer"] = "Loot announced, waiting for answer"
L["auto_award"] = "Automatic EP awards"
L["auto_award_defeat"] = "Defeat"
L["auto_award_defeat_desc"] = "Automatically award EP to raid and standby for wipes on a boss"
L["auto_award_defeat_pct"] = "Defeat EP Scaling"
L["auto_award_defeat_ptc_desc"] = "The percentage of EP (for a victory) to award on a wipe"
L["auto_award_victory"] = "Victory"
L["auto_award_victory_desc"] = "Automatically award EP to raid and standby when a boss is defeated"
L["auto_pass"] = "Autopass"
L["auto_passed_on_item"] = "Auto-passed on %s"
L["award"] = "Award"
L["award_for"] = "Award for"
L["award_later_unsupported_when_testing"] = "Award later isn't supported when testing"
L["award_scaling_for_reason"] = "Award scaling percentage for %s"
L["award_scaling_help"] = "Configure percentages of base GP, with respect to award reason. For example, if awarded for 'Off-Spec (Greed)', GP = BASE_GP * GREED_PCT"
L["awarded"] = "Awarded"
L["awards"] = "Awards"
L["bank"] = "Bank"
L["candidate_selecting_response"] = "Candidate is selecting response, please wait"
L["candidate_no_response_in_time"] = "Candidate didn't respond in time"
L["candidate_removed"] = "Candidate removed"
L["changing_loot_method_to_ml"] = "Changing loot method to Master Looting"
L["change_award"] = "Change Award"
L["change_note"] = "Click to change your note"
L["change_response"] = "Change Response"
L["chat version"] = "|cFF87CEFAR2D2 |cFFFFFFFFversion |cFFFFA500 %s"
L["chat_commands_config"]  = "Open the options interface (alternatives 'c')"
L["chat_commands_test"] = "Emulate a loot session with # items, 1 if omitted (alternatives 't')"
L["chat_commands_version"] = "Open the Version Checker (alternatives 'v' or 'ver')"
L["click_more_info"] = "Click to expand/collapse more information"
L["click_to_switch_item"] = "Click to switch to %s"
L["comment"] = "Comment"
L["comment_with_id"] = "Comment %d"
L["confirm_abort"] = "Are you certain you want to abort?"
L["confirm_adjust_player_points"] = "Are you certain you want to %s %d %s %s %s?"
L["confirm_award_item_to_player"] = "Are you certain you want to give %s to %s?"
L["confirm_rolls"] = "Are you certain you want to request rolls for all un-awarded items from %s?"
L["confirm_unawarded"] = "Are you certain you want to re-announce all un-awarded items to %s?"
L["confirm_usage_text"] = "|cFF87CEFA R2D2 |r\n\nWould you like to use R2D2 with this group?"
L["deselect_responses"] = "De-select responses to filter them"
L["description"] = "Description"
L["diff"] = "Diff"
L["disenchant"] = "Disenchant"
L["disabled"] = "Candidate has disabled R2D2"
L["enable"] = "Enable"
L["ep"] = "Effort Points"
L["ep_abbrev"] = "EP"
L["ep_desc"] = "Effort Points (EP)"
L["equation"] = "Equation"
L["equipment_loc"] = "Item Type"
L["equipment_loc_desc"] = "The type of the item, which includes where it can be equipped"
L["equipment_slots"] = "Equipment Slots"
L["error_test_as_non_leader"] = "You cannot initiate a test while in a group without being the group leader."
L["errors"] = "Error(s)"
L["free"] = "Free"
L["gp"] = "Gear Points"
L["gp_abbrev"] = "GP"
L["gp_custom"] = "Gear Points (Custom)"
L["gp_custom_desc"] = "Gear Points (GP) Customization"
L["gp_custom_help"] = "Configure Gear Points (GP) for specific items (e.g. Head of Onyxia)"
L["gp_desc"] = "Gear Points (GP)"
L["gp_help"] = "Configure the formula for calculating Gear Points (GP) - including the base, coefficient, and any multipliers (gear, award reason, etc.)"
L["gp_tooltip_ilvl"] = "ItemLevel [R2D2] : %s"
L["gp_tooltip_gp"] = "GP [R2D2] : %d (%s)"
L["gp_tooltips"] = "Tooltip"
L["gp_tooltips_desc"] = "Gear Points (GP) on tooltips"
L["gp_tooltips_help"] = "Provide a Gear Point (GP) value for items on tooltips. This is the value that will be used for GP when an item is distributed."
L["g1"] = "g1"
L["g2"] = "g2"
L["in"] = "In"
L["item_added_to_award_later_list"] = "%s was added to the award later list"
L["item_awarded_to"] = "Item was awarded to"
L["item_awarded_no_reaward"] = "Awarded item cannot be awarded later"
L["item_bagged_cannot_be_awarded"] = "Items stored in the Loot Master's bag for award later cannot be awarded"
L["item_has_been_awarded"] = "This item has been awarded"
L["item_lvl"] = "Item Level"
L["item_lvl_desc"] = "Item level serves as a rough indicator of the power and usefulness of an item, designed to reflect the overall benefit of using the item."
L["item_slot_with_name"] = "%s Item Slot"
L["is_not_active_in_this_raid"] = " is not active in this raid"
L["latest_items_won"] = "Latest item(s) won"
L["left_click"] = "Left Click"
L["logging"] = "Logging"
L["logging_desc"] = "Logging configuration"
L["logging_help"] = "Configuration settings for logging, such as threshold at which logging is emitted."
L["logging_threshold"] = "Logging threshold"
L["logging_threshold_desc"] = "All log events with lower level than the threshold level are ignored."
L["logging_window_toggle"] = "Toggle Logging Window"
L["logging_window_toggle_desc"] = "Toggle the display of the logging ouput window"
L["loot_master"] = "The loot master"
L["member_of"] = "Member of"
L["minor_upgrade"] = "Minor Upgrade"
L["ms_need"] = "Main-Spec (Need)"
L["multiplier"] = "Multiplier"
L["multiplier_with_id"] = "Multiplier %d"
L["name"] = "Name"
L["n_ago"] = "%s ago"
L["n_days"] = "%s days"
L["n_days_and_n_months"] = "%s and %d months"
L["n_days_and_n_months_and_n_years"] = "%s, %d months and %d years"
L["no_entries_in_loot_history"] = "No entries in the loot history"
L["not_accounced"] = "Not announced"
L["not_found"] = "Not Found"
L["not_in_instance"] = "Candidate is not in the instance"
L["notes"] = "Notes"
L["open_config"] = "Open Configuration"
L["open_standings"] = "Open Standings (EP/GP)"
L["offline_or_not_installed"] = "Offline or R2D2 not installed"
L["os_greed"] = "Off-Spec (Greed)"
L["out_of_instance"] = "Out of instance"
L["player_ended_session"] = "%s has ended the session"
L["player_handles_looting"] = "%s now handles looting"
L["player_requested_reroll"] = "%s has asked you to re-roll"
L["pr_abbrev"] = "PR"
L["pvp"] = "PVP"
L["quality"] = "Quality"
L["quality_desc"] = "Quality determines the relationship of the item level (which determines the sizes of the stat bonuses on it) to the required level to equip it. It also determines the number of different stat bonuses."
L["quality_threshold"] = "Quality threshold"
L["quality_threshold_desc"] = "Only display GP values for items at or above this quality."
L["quantity"] = "Quantity"
L["raids"] = "Raids"
L["raids_desc"] = "Raid Encounters"
L["reannounce"] = "Re-announce"
L["reannounced_i_to_t"] = "Re-announced '%s' to '%s'"
L["remove_from_consideration"] = "Remove from consideration"
L["requested_rolls_for_i_from_t"] = "Requested rolls for '%s' from '%s'"
L["response"] = "Response"
L["response_unavailable"] = "Response isn't available. Please upgrade R2D2."
L["response_to_item"] = "Response to %s"
L["resource_type"] = "Resource Type"
L["roll_result"] = "%s has rolled %d for %s"
L["r2d2_loot_allocate_frame"] = "R2D2 Loot Allocation"
L["r2d2_loot_frame"] = "R2D2 Loot"
L["r2d2_loot_session_frame"] = "R2D2 Session Setup"
L["r2d2_standings_frame"] = "R2D2 Standings"
L["r2d2_adjust_points_frame"] = "R2D2 Adjust Points"
L["settings"] = "Settings"
L["session_data_sync"] = "Please wait a few seconds while data is synchronizing."
L["session_error"] = "An unexpected condition was encountered - please restart the session"
L["session_in_combat"] = "You cannot start a session while in combat."
L["session_items_not_loaded"] = "Session cannot be started as not all items are loaded."
L["session_no_items"] = "Session cannot be started as there are no items."
L["session_not running"] = "No session running"
L["shift_left_click"] = "Shift + Left Click"
L["standby"] = "Standby/Bench"
L["standby_desc"] = "Configuration settings for standby/bench EP"
L["standby_pct"] = "Standby/Bench EP Scaling"
L["standby_pct_desc"] = "The percentage of EP to award for a bench/standby player"
L["standby_toggle"] = "Support for awarding EP to standby/bench players"
L["standby_toggle_desc"] = "When enabled, allows for whispering \'r2d2 standby [name]\' to be added to standby/bench roster"
L["store_in_bag_award_later"] = "Store in bag and award later"
L["slots"] = "Slots"
L["slot_multiplier"] = "Slot Multiplier"
L["slot_comment"] = "Slot Comment"
L["test"] = "test"
L["this_item"] = "This item"
L["timeout"] = "Timeout"
L["unguilded"] = "Unguilded"
L["version"] = "Version"
L["whisperkey_ms_need"] = "mainspec, ms, need, 1"
L["whisperkey_os_greed"] = "offspec, os, greed, 2"
L["whisperkey_minor_upgrade"] = "minorupgrade, minor, 3"
L["whisperkey_pvp"] = "pvp, 4"
L["your_note"] = "Your note:"
L["x_unspecified_or_incorrect_type"] = "%s was not specified (or of incorrect type)"
