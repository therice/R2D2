local L = LibStub("AceLocale-3.0"):NewLocale("R2D2", "enUS", true, true)
if not L then return end

L["abort"] = "Abort"
L["accept_whispers"] = "Accept Whispers"
L["accept_whispers_desc"] = "Allows players to use whispers for indicating their response for an item"
L["action"] = "Action"
L["actor"] = "Actor"
L["action_type"] = "Action Type"
L["active"] = "Active"
L["active_desc"] = "Disables R2D2 when unchecked. Note: This resets on every logout or UI reload."
L["added"] = "Added"
L["add_note"] = "Add Note"
L["add_note_desc"] = "Click to add note"
L["add_rolls"] = "Add Rolls"
L["adjust"] = "Adjust"
L["adjust_ep"] = "Adjust EP"
L["adjust_gp"] = "Adjust GP"
L["after"] = "After"
L["all_items_have_been_awarded"] = "All items have been awarded and the loot session concluded"
L["all_unawarded_items"] = "All un-awarded items"
L["always_show_tooltip_howto"] = "Double click to toggle tooltip"
L["amount"] = "Amount"
L["announcements"] = "Announcements"
L["announce_awards"] = "Announce Awards"
L["announce_awards_desc"] = "Enables the announcement of awards in configured channel(s)"
L["announce_awards_desc_detail"] = "\nChoose the channel to which awards will be announced, along with the announcement text. The following keyword substitutions are available:\n"
L["announce_item_text"] = "Items under consideration:"
L["announce_items"] = "Announce Items"
L["announce_items_desc"] = "Enables the announcement of items under consideration, in then configured channel(s), whenever a session starts"
L["announce_items_desc_detail"] = "\nChoose the channel to which items under consideration will be announced, along with the announcement header"
L["announce_items_desc_detail2"] = "\nEnter the message to announce for each item. The following keyword substitutions are available:\n"
L["announce_&i_desc"] = "|cfffcd400 &i|r: item link"
L["announce_&l_desc"] = "|cfffcd400 &l|r: item level"
L["announce_&p_desc"] = "|cfffcd400 &p|r: name of the player receiving the item"
L["announce_&r_desc"] = "|cfffcd400 &r|r: reason"
L["announce_&s_desc"] = "|cfffcd400 &s|r: session id"
L["announce_&t_desc"] = "|cfffcd400 &t|r: item type"
L["announce_&n_desc"] = "|cfffcd400 &n|r: roll, if supplied"
L["announce_&o_desc"] = "|cfffcd400 &o|r: item owner, if applicable"
L["announce_&m_desc"] = "|cfffcd400 &m|r: candidates note"
L["announce_&g_desc"] = "|cfffcd400 &g|r: item GP"
L["announced_awaiting_answer"] = "Loot announced, waiting for answer"
L["auto_award"] = "EP awards"
L["auto_award_defeat"] = "Automatic Defeat Awards"
L["auto_award_defeat_desc"] = "Automatically award EP to raid and standby for wipes on a boss"
L["auto_award_victory"] = "Victory"
L["auto_award_victory_desc"] = "Automatically award EP to raid and standby when a boss is defeated"
L["auto_extracted_from_whisper"] = "Automatically extracted from whisper"
L["auto_loot_boe_desc"] = "Automatically add all Bind On Equip (BOE) items to loot session(s)"
L["auto_loot_equipable_desc"] = "Automatically add all eligible and equipable items to loot session(s)"
L["auto_loot_non_equipable_desc"] = "Automatically add all eligible and non-equipable items to loot session(s)"
L["auto_pass"] = "Autopass"
L["auto_passed_on_item"] = "Auto-passed on %s"
L["auto_start"] = "Auto Start"
L["auto_start_desc"] = "Enables automatic starting of a session with all eligible items. Disabling will show an editable item list before starting a session."
L["award"] = "Award"
L["award_defeat"] = "Defeat"
L["award_defeat_desc"] = "Should EP be awarded to raid and standby for wipes on a boss"
L["award_defeat_pct"] = "Defeat EP Scaling"
L["award_defeat_pct_desc"] = "The percentage of EP (for a victory) to award on a wipe"
L["award_n_ep_for_boss_victory"] = "Awarded %d EP for %s (Victory)"
L["award_n_ep_for_boss_defeat"] = "Awarded %d EP for %s (Defeat)"
L["award_for"] = "Award for"
L["award_later_unsupported_when_testing"] = "Award later isn't supported when testing"
L["award_scaling_for_reason"] = "Award scaling percentage for %s"
L["award_scaling_help"] = "Configure the percentages for each award reason, which is used in the calculation of GP.\nFor example, if awarded for 'Off-Spec (Greed)', GP = BASE_GP * 'Off-Spec (Greed) %'"
L["awarded_item_for_reason"] = "Awarded %s for %s"
L["awarded"] = "Awarded"
L["awards"] = "Awards"
L["awards_desc"] = "Settings for configuring awarding of EP"
L["bank"] = "Bank"
L["before"] = "Before"
L["candidate_selecting_response"] = "Candidate is selecting response, please wait"
L["candidate_no_response_in_time"] = "Candidate didn't respond in time"
L["candidate_removed"] = "Candidate removed"
L["changing_loot_method_to_ml"] = "Changing loot method to Master Looting"
L["change_award"] = "Change Award"
L["change_note"] = "Click to change your note"
L["change_response"] = "Change Response"
L["channel"] = "Channel"
L["channel_desc"] = "Select a channel to which announcements will be made"
L["chat"] = "Chat"
L["chat version"] = "|cFF87CEFAR2D2 |cFFFFFFFFversion|cFFFFA500 %s|r"
L["chat_commands_config"]  = "Open the options interface (alternatives 'c')"
L["chat_commands_looth"] = "Opens the Loot History"
L["chat_commands_standby"] = "Opens the Standby/Bench Roster"
L["chat_commands_test"] = "Emulate a loot session with # items, 1 if omitted (alternatives 't')"
L["chat_commands_traffich"] = "Opens the EP/GP Traffic History"
L["chat_commands_version"] = "Open the version checker (alternatives 'v' or 'ver') - can specify boolean as argument to show outdated clients"
L["clear_selection"] = "Clear Selection"
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
L["considerations"] = "Considerations"
L["contact"] = "Contact"
L["date"] = "Date"
L["deselect_responses"] = "De-select responses to filter them"
L["description"] = "Description"
L["diff"] = "Diff"
L["disenchant"] = "Disenchant"
L["disabled"] = "Candidate has disabled R2D2"
L["double_click_to_delete_this_entry"] = "Double click to delete this entry"
L["dropped_by"] = "Dropped by"
L["enable"] = "Enable"
L["ep"] = "Effort Points"
L["ep_abbrev"] = "EP"
L["ep_desc"] = "Effort Points (EP)"
L["equation"] = "Equation"
L["equipable"] = "Equipable"
L["equipable_not"] = "Non-Equipable"
L["equipment_loc"] = "Item Type"
L["equipment_loc_desc"] = "The type of the item, which includes where it can be equipped"
L["equipment_slots"] = "Equipment Slots"
L["equipment_slots_help"] = "Configure the multiplier for each equipment slot, which is used in the calculation of GP (equipment_slot_multiplier)."
L["error_test_as_non_leader"] = "You cannot initiate a test while in a group without being the group leader."
L["errors"] = "Error(s)"
L["everyone_up_to_date"] = "Everyone is up to date"
L["free"] = "Free"
L["general_options"] = "General Options"
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
L["instance"] = "Instance"
L["is_not_active_in_this_raid"] = "NOT active in this raid"
L["item"] = "Item"
L["item_added_to_award_later_list"] = "%s was added to the award later list"
L["item_awarded_to"] = "Item was awarded to"
L["item_awarded_no_reaward"] = "Awarded item cannot be awarded later"
L["item_bagged_cannot_be_awarded"] = "Items stored in the Loot Master's bag for award later cannot be awarded"
L["item_has_been_awarded"] = "This item has been awarded"
L["item_lvl"] = "Item Level"
L["item_lvl_desc"] = "Item level serves as a rough indicator of the power and usefulness of an item, designed to reflect the overall benefit of using the item."
L["item_only_able_to_be_looted_by_you_bop"] = "The item can only be looted by you but it is not bind on pick up"
L["item_quality_below_threshold"] = "Item quality is below the loot threshold"
L["item_response_ack_from_s"] = "Response for item %s received and acknowledged from %s"
L["item_slot_with_name"] = "%s Item Slot"
L["latest_items_won"] = "Latest item(s) won"
L["left_click"] = "Left Click"
L["logging"] = "Logging"
L["logging_desc"] = "Logging configuration"
L["logging_help"] = "Configuration settings for logging, such as threshold at which logging is emitted."
L["logging_threshold"] = "Logging threshold"
L["logging_threshold_desc"] = "All log events with lower level than the threshold level are ignored."
L["logging_window_toggle"] = "Toggle Logging Window"
L["logging_window_toggle_desc"] = "Toggle the display of the logging ouput window"
L["loot_history"] = "Loot History"
L["loot_history_desc"] = "Historical audit records of loot distribution"
L["loot_master"] = "The loot master"
L["loot_options"] = "Loot options"
L["loot_won"] = "Loot won"
L["member_of"] = "Member of"
L["message"] = "Message"
L["message_desc"] = "The message to send to the selected channel"
L["message_for_each_item"] = "Message for each item"
L["message_header"] = "Message Header"
L["message_header_desc"] = "The message used as the header for item announcements"
L["minimize_in_combat"] = "Minimize while in combat"
L["minimize_in_combat_desc"] = "Enable to minimize all frames when entering combat"
L["minor_upgrade"] = "Minor Upgrade"
L["ml"] = "Master Looter"
L["ml_desc"] = "These settings will only be used when you are the Master Looter"
L["ms_need"] = "Main-Spec (Need)"
L["modes"] = "Mode(s)"
L["multiplier"] = "Multiplier"
L["multiplier_with_id"] = "Multiplier %d"
L["name"] = "Name"
L["n_ago"] = "%s ago"
L["n_days"] = "%s days"
L["n_days_and_n_months"] = "%s and %d months"
L["n_days_and_n_months_and_n_years"] = "%s, %d months and %d years"
L["no_contacts_for_standby_member"] = "No alternative contacts for standby/bench member"
L["no_entries_in_loot_history"] = "No entries in the loot history"
L["no_permission_to_loot_item_at_x"] = "No permission to loot the item at slot %s"
L["not_annouced"] = "Not announced"
L["not_found"] = "Not Found"
L["not_installed"] = "Not installed"
L["not_in_instance"] = "Candidate is not in the instance"
L["notes"] = "Notes"
L["number_of_raids_from which_loot_was_received"] = "Number of raids from which loot was received"
L["offline"] = "Offline"
L["online"] = "Online"
L["only_use_in_raids"] = "Only use in raids"
L["only_use_in_raids_desc"] = "Check to disable R2D2 in parties"
L["open_config"] = "Open Configuration"
L["open_loot_history"] = "Open Loot History"
L["open_loot_history_desc"] = "Opens the Loot History"
L["open_standings"] = "Open Standings (EP/GP)"
L["open_traffic_history"] = "Open EP/GP Traffic History"
L["open_traffic_history_desc"] = "Opens the EP/GP Traffic History"
L["offline_or_not_installed"] = "Offline or R2D2 not installed"
L["os_greed"] = "Off-Spec (Greed)"
L["out_of_instance"] = "Out of instance"
L["out_of_raid"] = "Out of raid support"
L["out_of_raid_desc"] = "When enabled and in a group of 8 or more members, anyone that isn't in the instance when a session starts will automatically send an 'Out of Raid' response"
L["ping"] = "Ping"
L["pinged"] = "Pinged"
L["player_ended_session"] = "%s has ended the session"
L["player_handles_looting"] = "%s now handles looting"
L["player_ineligible_for_item"] = "Player is ineligible for this item"
L["player_not_in_group"] = "Player is not in the group"
L["player_not_in_instance"] = "Player is not in the instance"
L["player_offline"] = "Player is offline"
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
L["reason"] = "Reason"
L["remove_from_consideration"] = "Remove from consideration"
L["requested_rolls_for_i_from_t"] = "Requested rolls for '%s' from '%s'"
L["response"] = "Response"
L["responses"] = "Responses"
L["responses_from_chat"] = "Responses from Chat"
L["responses_from_chat_desc"] = "If a player doesn't have R2D2 installed, the following whisper responses are supported for item(s). \nExample: \"/w ML_NAME !item 1 greed\" would (by default) register as 'greeding' on the first item in the session.\nBelow you can choose keywords for the individual buttons. Only A-Z, a-z and 0-9 is accepted for keywords, everything else is considered a delimiter.\nPlayers can receive the keyword list by messaging '!help' to the Master Looter once R2D2 is enabled"
L["response_unavailable"] = "Response isn't available. Please upgrade R2D2."
L["response_to_item"] = "Response to %s"
L["resource"] = "Resource"
L["resource_type"] = "Resource Type"
L["roll_result"] = "%s has rolled %d for %s"
L["r2d2_adjust_points_frame"] = "R2D2 Adjust Points"
L["r2d2_loot_allocate_frame"] = "R2D2 Loot Allocation"
L["r2d2_loot_frame"] = "R2D2 Loot"
L["r2d2_loot_history_frame"] = "R2D2 Loot History"
L["r2d2_loot_session_frame"] = "R2D2 Session Setup"
L["r2d2_standby_bench_frame"] = "R2D2 Standby/Bench"
L["r2d2_standings_frame"] = "R2D2 Standings"
L["r2d2_traffic_history_frame"] = "R2D2 Traffic History"
L["r2d2_version_check_frame"] = "R2D2 Version Checker"
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
L["standby_toggle_desc"] = "When enabled, allows for whispering \'r2d2 !standby [contact1] [contact2] [contact3]\' to be added to standby/bench roster"
L["store_in_bag_award_later"] = "Store in bag and award later"
L["slots"] = "Slots"
L["slot_multiplier"] = "Slot Multiplier"
L["slot_comment"] = "Slot Comment"
L["status"] = "Status"
L["status_texts"] = "Status texts"
L["subject"] = "Subject"
L["sync"] = "Sync"
L["sync_desc"] = "Opens synchronization interface, allowing for syncing settings between guild or group members"
L["test"] = "test"
L["test_desc"] = "Click to emulate the master looting of items for yourself and anyone in your raid (equivalent to /r2d2 test #)"
L["Test"] = "Test"
L["the_following_versions_are_out_of_date"] = "The following versions are out of date"
L["this_item"] = "This item"
L["timeout"] = "Timeout"
L["timeout_duration"] = "Duration"
L["timeout_duration_desc"] = "The timeout duration, in seconds"
L["timeout_enable"] = "Enable Timeout"
L["timeout_enable_desc"] = "Enables timeout on Loot Frame presented to candidates for response"
L["timeout_giving_item_to_player"] = "Timeout when giving %s to %s"
L["total_awards"] = "Total awards"
L["total_items_won"] = "Total items won"
L["traffic_history"] = "EP/GP Traffic Histry"
L["traffic_history_desc"] = "Historical audit records of EP/GP traffic"
L["unable_to_give_loot_without_loot_window_open"] = "Unable to give out loot without the loot window being open"
L["unable_to_give_item_to_player"] =  "Unable to give %s to %s"
L["unguilded"] = "Unguilded"
L["usage"] = "Usage"
L["usage_ask_ml"] = "Ask me every time I become Master Looter"
L["usage_desc"] = "Choose when to use R2D2"
L["usage_leader_always"] = "Always use when leader"
L["usage_leader_ask"] = "Ask me when leader"
L["usage_leader_desc"] = "Should the same usage setting be used when entering an instance as the leader?"
L["usage_ml"] = "Always use when I am the Master Looter"
L["usage_never"] = "Never use"
L["usage_options"] = "Usage Options"
L["verify_after_each_award"] = "Verify after each EP award"
L["verify_after_each_award_desc"] = "After each award of EP to standby/bench, verify each player is still available/online."
L["version"] = "Version"
L["version_check"] = "Version Check"
L["version_check_desc"] = "Opens version check interface, allowing to query what version of R2D2 each group or guild member has installed"
L["version_out_of_date_msg"] = "Your version %s is out of date. Newer version is %s, please update R2D2."
L["waiting_for_response"] = "Waiting for response"
L["whisper_guide_1"] = "[R2D2]: !item item_number response - 'item_number' is the item session id, 'response' is one of the keywords below. You can whisper '!items' to get a list of items with numbers. E.G. '!item 1 greed' would greed on item #1"
L["whisper_guide_2"] = "[R2D2]: You'll get a confirmation message if you were successfully added"
L["whisper_items"] = "[R2D2]: Currently available items (item_number item_link)"
L["whisper_items_none"] = "[R2D2]: No items currently available"
L["whisper_item_ack"] = "[R2D2]: Response to %s acknowledged as \"%s\""
L["whisper_standby_ack"] = "[R2D2]: You have been added to standby/bench. Alternate contacts are as follows (if provided): %s"
L["whisper_standby_ignored"] = "[R2D2]: Standby/Bench is not enabled or you whispered a player that is not the master looter. Current master looter is '%s'"
L["whisperkey_for_x"] = "Set whisper key for %s"
L["whisperkey_ms_need"] = "mainspec, ms, need, 1"
L["whisperkey_os_greed"] = "offspec, os, greed, 2"
L["whisperkey_minor_upgrade"] = "minorupgrade, minor, 3"
L["whisperkey_pvp"] = "pvp, 4"
L["you_are_not_in_instance"] = "You are not in the instance"
L["your_note"] = "Your note:"
L["x_unspecified_or_incorrect_type"] = "%s was not specified (or of incorrect type)"