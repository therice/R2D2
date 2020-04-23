local name, AddOn = ...
local ML = AddOn:NewModule("MasterLooter", "AceEvent-3.0", "AceBucket-3.0", "AceComm-3.0", "AceTimer-3.0", "AceHook-3.0")
local L = AddOn.components.Locale
local Logging = AddOn.components.Logging
local Util = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local Models = AddOn.components.Models
local UI = AddOn.components.UI
local COpts = UI.ConfigOptions
local CANDIDATE_SEND_COOLDOWN, LOOT_TIMEOUT = 10, 3

-- these are the defaults for DB
ML.defaults = {
    profile = {
        -- various types of usage for add-on
        usage = {
            never  = false,
            ml     = false,
            ask_ml = true,
            state  = "ask_ml",
        },
        -- should it only be enabled in raids
        onlyUseInRaids = true,
        -- is 'out of raid' support enabled (specifies auto-responses when user not in instance, but in raid)
        outOfRaid = false,
        -- should a session automatically be started with all eligibile items
        autoStart  = false,
        -- automatically add all eligible equipable items from loot to session frame
        autoLootEquipable = true,
        -- automatically add all eligible non-equipable items from loot to session frame (e.g. mounts)
        autoLootNonEquipable = true,
        -- automatically add all BOE items from loot to session frame
        autoLootBoe = true,
        -- how long does a candidate have to respond
        timeout = 60,
        -- are whispers supported for candidate responses
        acceptWhispers = true,
        -- are awards announced via specified channel
        announceAwards = true,
        -- where awards are announced, channel + message
        announceAwardText =  {
            { channel = "group", text = "&p was awarded &i for &r (&g GP)"},
        },
        -- are items under consideration announced via specified channel
        announceItems = true,
        -- the prefix/preamble to use for announcing items
        announceItemPrefix = "Items under consideration:",
        -- where items are announced, channel + message
        announceItemText = { channel = "group", text = "&s: &i"},
        
        buttons = {
            -- dynamically constructed in the do/end loop below
            -- example data left behind for illustration
            default = {
                --[[
                numButtons = 4,
                { text = L["ms_need"],          whisperKey = L["whisperkey_ms_need"], },
                { text = L["os_greed"],         whisperKey = L["whisperkey_os_greed"], },
                { text = L["minor_upgrade"],    whisperKey = L["whisperkey_minor_upgrade"], },
                { text = L["pvp"],              whisperKey = L["whisperkey_pvp"], },
                --]]
            },
        },
        responses = {
            default = {
                AWARDED         =   { color = {1,1,1,1},		sort = 0.1,	text = L["awarded"], },
                NOTANNOUNCED    =   { color = {1,0,1,1},		sort = 501,	text = L["not_annouced"], },
                ANNOUNCED		=   { color = {1,0,1,1},		sort = 502,	text = L["announced_awaiting_answer"], },
                WAIT			=   { color = {1,1,0,1},		sort = 503,	text = L["candidate_selecting_response"], },
                TIMEOUT			=   { color = {1,0,0,1},		sort = 504,	text = L["candidate_no_response_in_time"], },
                REMOVED			=   { color = {0.8,0.5,0,1},	sort = 505,	text = L["candidate_removed"], },
                NOTHING			=   { color = {0.5,0.5,0.5,1},	sort = 506,	text = L["offline_or_not_installed"], },
                PASS		    =   { color = {0.7, 0.7,0.7,1},	sort = 800,	text = _G.PASS, },
                AUTOPASS		=   { color = {0.7,0.7,0.7,1},	sort = 801,	text = L["auto_pass"], },
                DISABLED		=   { color = {0.3,0.35,0.5,1},	sort = 802,	text = L["disabled"], },
                NOTINRAID		=   { color = {0.7,0.6,0,1}, 	sort = 803, text = L["not_in_instance"]},
                DEFAULT	        =   { color = {1,0,0,1},		sort = 899,	text = L["response_unavailable"] },
                -- dynamically constructed in the do/end loop below
                -- example data left behind for illustration
                --[[
                                    { color = {0,1,0,1},        sort = 1,   text = L["ms_need"], },         [1]
                                    { color = {1,0.5,0,1},	    sort = 2,	text = L["os_greed"], },        [2]
                                    { color = {0,0.7,0.7,1},    sort = 3,	text = L["minor_upgrade"], },   [3]
                                    { color = {1,0.5,0,1},	    sort = 4,	text = L["pvp"], },             [4]
                --]]
            }
        }
    }
}

ML.AwardStringsDesc = {
    L["announce_&s_desc"],
    L["announce_&p_desc"],
    L["announce_&i_desc"],
    L["announce_&r_desc"],
    L["announce_&n_desc"],
    L["announce_&l_desc"],
    L["announce_&t_desc"],
    L["announce_&o_desc"],
    L["announce_&m_desc"],
    L["announce_&g_desc"],
}


ML.AnnounceItemStringsDesc = {
    L["announce_&s_desc"],
    L["announce_&i_desc"],
    L["announce_&l_desc"],
    L["announce_&t_desc"],
    L["announce_&o_desc"],
}

-- these are the options displayed in configuration UI (probably want to move this out of the module into
-- a location which manages all configuration options)
ML.options = {
    name = L['ml'],
    type = 'group',
    --childGroups = 'tab',
    ignore_enable_disable = true,
    args = {
        description = COpts.Description(L["ml_desc"]),
        general = {
            order = 1,
            type = 'group',
            name = _G.GENERAL,
            args = {
                usageOptions = {
                    order = 1,
                    type = 'group',
                    name = L['usage_options'],
                    inline = true,
                    args = {
                        usage = COpts.Select(
                                L['usage'], 1, L['usage_desc'],
                                {
                                    ml     = L["usage_ml"],
                                    ask_ml = L["usage_ask_ml"],
                                    never  = L["usage_never"]
                                },
                                function() return ML:DbValue('usage.state') end,
                                function(_, key)
                                    for k in pairs(ML.db.profile.usage) do
                                        if k == key then
                                            ML.db.profile.usage[k] = true
                                        else
                                            ML.db.profile.usage[k] = false
                                        end
                                    end
                                    ML.db.profile.usage.state = key
                                    AddOn:ConfigTableChanged(ML:GetName(), 'usage.state')
                                end,
                                { width = 'double' }
                        ),
                        spacer = COpts.Header("", nil, 2),
                        -- a toggle that has special requirements in regards to setup
                        -- so don't use COpts.Toggle() and emit directly
                        leaderUsage = {
                            order = 3,
                            name = function()
                                return ML.db.profile.usage.ml and L["usage_leader_always"] or L["usage_leader_ask"]
                            end,
                            desc = L["usage_leader_desc"],
                            type = 'toggle',
                            get = function()
                                return ML.db.profile.usage.leader or ML.db.profile.usage.ask_leader
                            end,
                            set = function(_, val)
                                ML.db.profile.usage.leader, ML.db.profile.usage.ask_leader = false, false
                                if ML.db.profile.usage.ml then
                                    ML.db.profile.usage.leader = val
                                    AddOn:ConfigTableChanged(ML:GetName(), 'usage.leader')
                                end
                                if ML.db.profile.usage.ask_ml then
                                    ML.db.profile.usage.ask_leader = val
                                    AddOn:ConfigTableChanged(ML:GetName(), 'usage.ask_leader')
                                end
                            end,
                            disabled = function()
                                return ML.db.profile.usage.never
                            end
                        },
                        onlyUseInRaids = COpts.Toggle(L['only_use_in_raids'], 4, L['only_use_in_raids_desc']),
                        outOfRaid = COpts.Toggle(L['out_of_raid'], 5, L['out_of_raid_desc']),
                    }
                },
                lootOptions = {
                    order = 2,
                    name = L['loot_options'],
                    type = 'group',
                    inline = true,
                    args = {
                        autoStart = COpts.Toggle(L['auto_start'], 1, L['auto_start_desc']),
                        spacer = COpts.Header("", nil, 2),
                        autoLootEquipable = COpts.Toggle( _G.AUTO_LOOT_DEFAULT_TEXT .. ' ' .. L['equipable'], 3, L['auto_loot_equipable_desc']),
                        autoLootNonEquipable = COpts.Toggle( _G.AUTO_LOOT_DEFAULT_TEXT .. ' ' .. L['equipable_not'], 4, L['auto_loot_non_equipable_desc'], function() return not ML.db.profile.autoLootEquipable end),
                        autoLootBoe = COpts.Toggle( _G.AUTO_LOOT_DEFAULT_TEXT .. ' BOE', 5, L['auto_loot_boe_desc'], function() return not ML.db.profile.autoLootEquipable end),
                    }
                }
            },
        },
        announcements = {
            order = 2,
            type = 'group',
            name = L["announcements"],
            args = {
                awards = {
                    order = 1,
                    name = L["awards"],
                    type = 'group',
                    inline = true,
                    args = {
                        announceAwards = COpts.Toggle(L["announce_awards"], 1, L["announce_awards_desc"], false, {width='full'}),
                        description = COpts.Description(
                                function () return L["announce_awards_desc_detail"] .. '\n' .. Util.Strings.Join("\n", unpack(ML.AwardStringsDesc)) end,
                                "medium",
                                2,
                                {
                                    hidden = function() return not ML.db.profile.announceAwards end
                                }
                        ),
                        -- additional arguments are added dynamically below
                    }
                },
                considerations = {
                    order = 2,
                    name = L["considerations"],
                    type = 'group',
                    inline = true,
                    args = {
                        announceItems = COpts.Toggle(L["announce_items"], 1, L["announce_items_desc"], false , {width='full'}),
                        description = COpts.Description(
                                L["announce_items_desc_detail"], "medium", 2,
                                {
                                    hidden = function() return not ML.db.profile.announceItems end
                                }
                        ),
                        announceItemChannel = {
                            order = 3,
                            name = L["channel"],
                            desc = L["channel_desc"],
                            type = "select",
                            style = "dropdown",
                            values = {
                                NONE         = _G.NONE,
                                SAY          = _G.CHAT_MSG_SAY,
                                YELL         = _G.CHAT_MSG_YELL,
                                PARTY        = _G.CHAT_MSG_PARTY,
                                GUILD        = _G.CHAT_MSG_GUILD,
                                OFFICER      = _G.CHAT_MSG_OFFICER,
                                RAID         = _G.CHAT_MSG_RAID,
                                RAID_WARNING = _G.CHAT_MSG_RAID_WARNING,
                                group        = _G.GROUP,
                                chat         = L["chat"],
                            },
                            get = function() return ML.db.profile.announceItemText.channel end,
                            set = function(_, v)  ML.db.profile.announceItemText.channel = v end,
                            hidden = function() return not ML.db.profile.announceItems end,
                        },
                        announceItemPrefix = COpts.Input(
                                L["message_header"], 4,
                                {
                                    desc = L["message_header_desc"],
                                    width = "double",
                                    hidden = function() return not ML.db.profile.announceItems end,
                                }
                        ),
                        announceItemMessageDesc = COpts.Description(
                                function () return L["announce_items_desc_detail2"] .. '\n' .. Util.Strings.Join("\n", unpack(ML.AnnounceItemStringsDesc)) end,
                                "medium",
                                5,
                                {
                                    hidden = function() return not ML.db.profile.announceItems end,
                                }
                        ),
                        announceItemMessage = COpts.Input(
                                L["message_for_each_item"], 6,
                                {
                                    width = "double",
                                    get = function() return ML.db.profile.announceItemText.text end,
                                    set = function(_, v)  ML.db.profile.announceItemText.text = v end,
                                    hidden = function() return not ML.db.profile.announceItems end,
                                }
                        ),
                    }
                }
            }
        },
        responses = {
            order = 3,
            type = 'group',
            name = L["responses"],
            args = {
                timeout = {
                    order = 1,
                    name = L["timeout"],
                    type = 'group',
                    inline = true,
                    args = {
                        enable = {
                            order = 1,
                            name = L["timeout_enable"],
                            desc = L["timeout_enable_desc"],
                            type = "toggle",
                            set = function()
                                if ML.db.profile.timeout then
                                    ML.db.profile.timeout = false
                                else
                                    ML.db.profile.timeout = ML.defaults.profile.timeout
                                end
                            end,
                            get = function()
                                return ML.db.profile.timeout
                            end
                        },
                        timeout = COpts.Range(L["timeout_duration"], 2, 0, 200, 5, {
                            disabled = function() return not ML.db.profile.timeout end,
                            desc = L["timeout_duration_desc"]
                        })
                    }
                },
                whisperResponses = {
                    order = 2,
                    name = L["responses_from_chat"],
                    type = 'group',
                    inline = true,
                    args = {
                        acceptWhispers = COpts.Toggle(L['accept_whispers'], 1, L['accept_whispers_desc']),
                        desc = COpts.Description(L["responses_from_chat_desc"], nil, 2)
                        -- additional arguments are added dynamically below
                    }
                }
            }
        }
    }
}


-- Copy defaults from GearPoints into our defaults for buttons/responses
-- This actually should be done via the AddOn's DB once it's initialized, but we currently
-- don't allow users to change these values (either here or from GearPoints) so we can
-- do it before initialization. If we allow for these to be configured by user, then will
-- need to copy from DB
do
    local DefaultButtons = ML.defaults.profile.buttons.default
    local DefaultResponses = ML.defaults.profile.responses.default
    local GP = AddOn:GetModule("GearPoints")
    -- these are the responses available to player when presented with a loot decision
    -- we only select ones that are "user visible", as others are only available to
    -- master looter (e.g. 'Free', 'Disenchant', 'Bank', etc.)
    local UserVisibleAwards =
        Util(GP.defaults.profile.award_scaling)
                :CopyFilter(function (v) return v.user_visible end, true, nil, true)()

    DefaultButtons.numButtons = Util.Tables.Count(UserVisibleAwards)
    local index = 1
    for award, value in pairs(UserVisibleAwards) do
        -- these are entries that represent buttons available to player at time of loot decision
        Util.Tables.Push(DefaultButtons, {text = L[award], whisperKey = L['whisperkey_' .. award], award_scale=award})
        -- the are entries of the universe of possible responses, which are a super set of ones
        -- presented to the player
        Util.Tables.Push(DefaultResponses, { color = value.color, sort = index, text = L[award], award_scale=award})
        index = index + 1
    end
    
   
end

-- sets up configuration options that rely upon DB settings
local function ConfigureOptionsFromDb(db)
    -- setup the whisper keys for various responses
    for i = 1, db.buttons.default.numButtons do
        local button = db.buttons.default[i] --DefaultButtons[i]
        ML.options.args.responses.args.whisperResponses.args["whisperkey_" .. i] = {
            order = i + 3,
            name = button.text,
            desc = format(L["whisperkey_for_x"], button.text),
            type = "input",
            width = "double",
            get = function() return db.buttons.default[i].whisperKey end,
            set = function(k, v) db.buttons.default[i].whisperKey = tostring(v) end,
            hidden = function()
                return not db.acceptWhispers or db.buttons.default.numButtons < i
            end,
        }
    end
    
    -- sets up options for channel and messages for award announcements
    for i = 1, #db.announceAwardText do
        ML.options.args.announcements.args.awards.args["awardChannel" .. i] = {
            order = i + 3,
            name = L["channel"],
            desc = L["channel_desc"],
            type = "select",
            style = "dropdown",
            values = {
                NONE         = _G.NONE,
                SAY          = _G.CHAT_MSG_SAY,
                YELL         = _G.CHAT_MSG_YELL,
                PARTY        = _G.CHAT_MSG_PARTY,
                GUILD        = _G.CHAT_MSG_GUILD,
                OFFICER      = _G.CHAT_MSG_OFFICER,
                RAID         = _G.CHAT_MSG_RAID,
                RAID_WARNING = _G.CHAT_MSG_RAID_WARNING,
                group        = _G.GROUP,
                chat         = L["chat"],
            },
            get = function() return db.announceAwardText[i].channel end,
            set = function(_, v)  db.announceAwardText[i].channel = v end,
            hidden = function() return not db.announceAwards end,
        }
        ML.options.args.announcements.args.awards.args["awardMessage" .. i] = {
            order = i + 3.1,
            name = L["message"],
            desc = L["message_desc"],
            type = "input",
            width = "double",
            get = function() return db.announceAwardText[i].text end,
            set = function(_, v) db.announceAwardText[i].text = v end,
            hidden = function() return not db.announceAwards end,
        }
    end
end

function ML:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.db = AddOn.db:RegisterNamespace(self:GetName(), ML.defaults)
    -- setup the addiitonal configuraiton options once DB has been established
    ConfigureOptionsFromDb(self.db.profile)
    
    -- Logging:Debug("OnInitialize(%s)", Util.Objects.ToString(self.db.namespaces, 2))
    -- Logging:Debug("OnInitialize(%s)", Util.Objects.ToString(ML.defaults, 6))
    --[[
        {profile =
            {responses =
                {default =
                    {
                        NOTINRAID = {color = {0.7, 0.6, 0, 1}, text = Candidate is not in the instance, sort = 803},
                        TIMEOUT = {color = {1, 0, 0, 1}, text = Candidate didn't respond in time, sort = 504},
                        1 = {color = {0, 1, 0.59, 1}, text = Main-Spec (Need), sort = 1},
                        NOTHING = {color = {0.5, 0.5, 0.5, 1}, text = Offline or R2D2 not installed, sort = 505},
                        WAIT = {color = {1, 1, 0, 1}, text = Candidate is selecting response, please wait, sort = 503},
                        ANNOUNCED = {color = {1, 0, 1, 1}, text = Loot announced, waiting for answer, sort = 502},
                        4 = {color = {0.77, 0.12, 0.23, 1}, text = PVP, sort = 4},
                        DISABLED = {color = {0.3, 0.35, 0.5, 1}, text = Candidate has disabled R2D2, sort = 802},
                        PASS = {color = {0.7, 0.7, 0.7, 1}, text = Pass, sort = 800},
                        2 = {color = {1, 0.96, 0.41, 1}, text = Off-Spec (Greed), sort = 2},
                        DEFAULT = {color = {1, 0, 0, 1}, text = Response isn't available. Please upgrade R2D2., sort = 899},
                        3 = {color = {0.96, 0.55, 0.73, 1}, text = Minor Upgrade, sort = 3},
                        NOTANNOUNCED = {color = {1, 0, 1, 1}, text = Not announced, sort = 501},
                        AUTOPASS = {color = {0.7, 0.7, 0.7, 1}, text = Autopass, sort = 801},
                        AWARDED = {color = {1, 1, 1, 1}, text = Awarded, sort = 0.1
                    }
                },
                buttons =
                    {default =
                        {
                            {whisperKey = mainspec, ms, need, 1, text = Main-Spec (Need)},
                            {whisperKey = offspec, os, greed, 2, text = Off-Spec (Greed)},
                            {whisperKey = minorupgrade, minor, 3, text = Minor Upgrade},
                            {whisperKey = pvp, 4, text = PVP}, numButtons = 4}
                        }
                    }
                }
                
    --]]
end

function ML:EnableOnStartup()
    return false
end

function ML:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    -- mapping of candidateName = { class, role, rank }
    -- entrie will be of type Candidate.Candidate
    self.candidates = {}
    -- the master looter's loot table (entries will be of type Item.ItemEntry)
    self.lootTable = {}
    -- for keeping a backup for existing loot table on session end
    self.oldLootTable = {}
    -- items master looter has attempted to give out and waiting
    self.lootQueue = {}
    -- table of timer references, with key being timer name and value being timer id
    self.timers = {}
    -- is a session in flight
    self.running = false
    self:RegisterComm(name, "OnCommReceived")
    self:RegisterEvent(AddOn.Constants.Events.ChatMessageWhisper, "OnEvent")
    self:RegisterEvent(AddOn.Constants.Events.PlayerRegenEnabled, "OnEvent")
    self:RegisterBucketEvent(AddOn.Constants.Events.GroupRosterUpdate, 10, "UpdateCandidates")
    self:RegisterBucketMessage(AddOn.Constants.Messages.ConfigTableChanged, 5, "ConfigTableChanged")
end

function ML:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self:UnregisterAllEvents()
    self:UnregisterAllBuckets()
    self:UnregisterAllComm()
    self:UnregisterAllMessages()
    self:UnhookAll()
end

-- when the db was changed, need to check if we must broadcast the new MasterLooter Db
-- the msg will be in the format of 'ace serialized message' = 'count of event'
-- where the deserialized message will be a tuple of 'module of origin' (e.g MasterLooter), 'db key name' (e.g. outOfRaid)
function ML:ConfigTableChanged(msg)
    -- Logging:Debug("ConfigTableChanged() : %s", Util.Objects.ToString(msg))
    if not AddOn.mlDb then return ML:UpdateDb() end
    for serializedMsg, _ in pairs(msg) do
        local success, module, val = AddOn:Deserialize(serializedMsg)
        --Logging:Debug("ConfigTableChanged(%s) : %s",  Util.Objects.ToString(module), Util.Objects.ToString(val))
        if success and self:GetName() == module then
            for key in pairs(AddOn.mlDb) do
                if key == val then return ML:UpdateDb() end
            end
        end
    end
end

-- @return the 'db' value at specified path
-- intentionally not named 'Get'DbValue to avoid conflict with default module prototype as specified
-- in Init.lua
function ML:DbValue(...)
    local path = Util.Strings.Join('.', ...)
    -- Logging:Debug('ML:DbValue(%s)', path)
    return Util.Tables.Get(self.db.profile, path)
end

-- @return the 'default' value at specified path
function ML:DefaultDbValue(...)
    local path = Util.Strings.Join('.', ...)
    -- Logging:Debug('ML:DefaultDbValue(%s)', path)
    return Util.Tables.Get(ML.defaults, path)
end

function ML:BuildDb()
    local db = self.db.profile
    -- iterate through the responses and capture any changes
    local changedResponses = {}
    for type, responses in pairs(db.responses) do
        for i,_ in ipairs(responses) do
            -- don't capture more than number of buttons
            if i > self:DbValue('buttons', type, 'numButtons') then break end

            local defaultResponses = self:DefaultDbValue('profile.responses', type)
            local defaultResponse = defaultResponses and defaultResponses[i] or nil
            local dbResponse = self:DbValue('responses', type)[i]
            -- look at type, text and color
            if not defaultResponse
                or (dbResponse.text ~= defaultResponse.text)
                or (unpack(dbResponse.color) ~= unpack(defaultResponse.color)) then
                if not changedResponses[type] then changedResponses[type] = {} end
                changedResponses[type][i] = dbResponse
            end
        end
    end

    -- iterate through the buttons and capture any changes
    local changedButtons = {default = {}}
    for type, buttons in pairs(db.buttons) do
        for i in ipairs(buttons) do
            -- don't capture more than number of buttons
            if i > self:DbValue('buttons', type, 'numButtons') then break end

            local defaultResponses = self:DefaultDbValue('profile.buttons', type)
            local defaultResponse = defaultResponses and defaultResponses[i] or nil

            local dbResponse = self:DbValue('buttons', type)[i]

            -- look a type and text
            if not defaultResponse
                or (dbResponse.text ~= defaultResponse.text) then
                if not changedButtons[type] then changedButtons[type] = {} end
                changedButtons[type][i] = {text = dbResponse.text}
            end
        end
    end

    changedButtons.default.numButtons = db.buttons.default.numButtons

    local Db = {
        buttons     =   changedButtons,
        responses   =   changedResponses,
        outOfRaid   =   db.outOfRaid,
        timeout     =   db.timeout,
    }

    --[[
        mlDb = {
            responses = {
                default = {
                }
            },
            buttons = {
                default = {
                    numButtons = 4
                }
            },
            ...
        }
    --]]
    AddOn:SendMessage(AddOn.Constants.Messages.MasterLooterBuildDb, Db)

    return Db
end

function ML:UpdateDb()
    Logging:Trace("UpdateDb()")
    local C = AddOn.Constants
    AddOn:OnMasterLooterDbReceived(self:BuildDb())
    AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
end

function ML:AddCandidate(name, class, rank, enchant, lvl, ilvl)
    Logging:Trace("AddCandidate(%s, %s, %s, %s, %s, %s)",
            name, class, rank or 'nil', tostring(enchant),
            tostring(lvl or 'nil'), tostring(ilvl or 'nil')
    )
    Util.Tables.Insert(self.candidates, name, Models.Candidate:new(name, class, rank, enchant, lvl, ilvl))
end

function ML:RemoveCandidate(name)
    Logging:Trace("RemoveCandidate(%s)", name)
    Util.Tables.Remove(self.candidates, name)
end

function ML:GetCandidate(name)
    return self.candidates[name]
end

function ML:UpdateCandidates(ask)
    Logging:Trace("UpdateCandidates(%s)", tostring(ask))
    if type(ask) ~= "boolean" then ask = false end

    local C = AddOn.Constants
    -- Util.Tables.Copy(self.candidates, function() return true end)
    local candidates_copy = Util(self.candidates):Copy()()
    local updates = false

    for i = 1, GetNumGroupMembers() do
        -- https://wow.gamepedia.com/API_GetRaidRosterInfo
        --
        -- in classic, combat role will always be NONE (so no need to check against it)
        --
        -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole
        --      = GetRaidRosterInfo(raidIndex)
        local name, _, _, _, _, class, _, _, _, _, _, _  = GetRaidRosterInfo(i)
        if name then
            name = AddOn:UnitName(name)
            if candidates_copy[name] then
                -- No need to check for a role change, classic doesn't have it
                Util.Tables.Remove(candidates_copy, name)
            else
                -- ask for their player information
                if ask then
                    AddOn:SendCommand(name, C.Commands.PlayerInfoRequest)
                end
                self:AddCandidate(name, class)
                updates = true
            end
        else
            Logging:Warn("GetRaidRosterInfo() returned nil for index = %s, retrying after a pause", i)
            return self:ScheduleTimer("UpdateCandidates", 1, ask)
        end
    end

    -- these folks no longer around (in raid)
    for n, v in pairs(candidates_copy) do
        if v then
            self:RemoveCandidate(n)
            updates = true
        end
    end

    -- send updates to candidate list and db
    if updates then
        AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
        self:SendCandidates()
    end
end

local function SendCandidates()
    local C = AddOn.Constants
    AddOn:SendCommand(C.group, C.Commands.Candidates, ML.candidates)
    ML.timers.send_candidates = nil
end

local function OnCandidatesCooldown()
    ML.timers.cooldown_candidates = nil
end

-- sends candidates to the group no more than every CANDIDATE_SEND_INTERVAL seconds
function ML:SendCandidates()
    local C = AddOn.Constants
    -- recently sent one
    if self.timers.cooldown_candidates then
        -- we've queued a new one
        if self.timers.send_candidates then
            -- do nothing, once current timer expires it will be sent
            return
        -- send the candidates once interval has expired
        else
            local timeRemaining = self:TimeLeft(self.timers.cooldown_candidates)
            self.timers.send_candidates = self:ScheduleTimer(SendCandidates, timeRemaining)
            return
        end
    -- no cooldown, send immediately and start the cooldown
    else
        self.timers.cooldown_candidates = self:ScheduleTimer(OnCandidatesCooldown, CANDIDATE_SEND_COOLDOWN)
        AddOn:SendCommand(C.group, C.Commands.Candidates, self.candidates)
    end
end

function ML:NewMasterLooter(ml)
    Logging:Debug("NewMasterLooter(%s)", ml)
    local C = AddOn.Constants
    -- Are we are the the ML?
    if AddOn:UnitIsUnit(ml,C.player) then
        AddOn:SendCommand(C.group, C.Commands.PlayerInfoRequest)
        self:UpdateDb()
        self:UpdateCandidates(true)
    else
        -- don't use this module if we're not the ML
        self:Disable()
    end
end

function ML:Timer(type, ...)
    Logging:Trace("Timer(%s)", type)
    local C = AddOn.Constants
    if type == "AddItem" then
        self:AddItem(...)
    elseif type == "LootSend" then
        AddOn:SendCommand(C.group, C.Commands.OfflineTimer)
    end
end

function ML:GetItemInfo(item)
    return Models.Item:FromGetItemInfo(item)
end

-- adds an item to the loot table
-- @param Any: ItemID|itemString|itemLink
-- @param bagged the item as represented in storage, nil if not bagged
-- @param lootSlot Index of the item within the loot table
-- @param owner the owner of the item (if any). Defaults to 'BossName'
-- @param index the index at which to add the entry, only needed on callbacks where item info was not available prev.
function ML:AddItem(item, bagged, lootSlot, owner, index)
    Logging:Trace("AddItem(%s)", item)
    -- todo : determine type code (as needed)
    index = index or nil
    local entry = Models.ItemEntry:new(item, bagged, lootSlot, false, owner or AddOn.encounter.name, false, "default")

    -- Need to insert entry regardless of fully populated (IsValid) as the
    -- session frame needs each of them to start and will update as entries are
    -- populated
    if not index then
        Util.Tables.Push(self.lootTable, entry)
        -- capture the index in case we need for callback
        index = #self.lootTable
    -- callback, update the previous index to populated entry
    else
        self.lootTable[index] = entry
    end

    if not entry:IsValid() then
        self:ScheduleTimer("Timer", 0, "AddItem", item, bagged, lootSlot, owner, index)
        Logging:Trace("AddItem() : Started timer %s for %s (%s)", "AddItem", item, tostring(index))
    else
        AddOn:SendMessage(AddOn.Constants.Messages.MasterLooterAddItem, item, entry)
    end
end

function ML:RemoveItem(session)
    Util.Tables.Remove(self.lootTable, session)
end

-- @return ItemEntry for passed session
function ML:GetItem(session)
    return self.lootTable[session]
end

function ML:GetLootTableForTransmit()
    Logging:Trace("GetLootTableForTransmit(PRE) : %s", Util.Objects.ToString(self.lootTable))
    local ltTransmit = Util(self.lootTable)
        :Copy()
        :Map(
            -- update the items as needed
            function(entry)
                if entry.isSent then
                    return nil
                else
                    return entry:UpdateForTransmit()
                end
            end
    )()
    Logging:Trace("GetLootTableForTransmit(POST) : %s", Util.Objects.ToString(ltTransmit))
    return ltTransmit
end

-- Do we have free space in our bags to hold this item?
function ML:HaveFreeSpaceForItem(item)
    local itemFamily = GetItemFamily(item)
    local equipSlot = select(4, GetItemInfoInstant(item))
    if equipSlot == "INVTYPE_BAG" then itemFamily = 0 end
    
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local freeSlots, bagFamily = GetContainerNumFreeSlots(bag)
        if freeSlots and freeSlots > 0 and (bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0) then
            return true
        end
    end
    
    return false
end

ML.AwardReasons = {
    Failure = {
        Bagged                    = "Bagged",
        BaggedItemCannotBeAwarded = "BaggedItemCannotBeAwarded",
        BaggingAwardedItem        = "BaggingAwardedItem",
        Locked                    = "Locked",
        LootGone                  = "LootGone",
        LootNotOpen               = "LootNotOpen",
        ManuallyBagged            = "ManuallyBagged",
        MLInventoryFull           = "MLInventoryFull",
        MLNotInInstance           = "MLNotInInstance",
        NotBop                    = "NotBop",
        NotInGroup                = "NotInGroup",
        NotMLCandidate            = "NotMLCandidate",
        Offline                   = "Offline",
        OutOfInstance             = "OutOfInstance",
        QualityBelowThreshold     = "QualityBelowThreshold",
        Timeout                   = "Timeout",
        UnLootedItemInBag         = "UnLootedItemInBag",
    },
    Success = {
        Indirect      = "Indirect",
        ManuallyAdded = "ManuallyAdded",
        Normal        = "Normal",
    },
    Neutral = {
        TestMode = "TestMode",
    }
}

function ML:CanGiveLoot(slot, item, winner)
    local lootSlotInfo = AddOn:GetLootSlotInfo(slot)
    
    if not AddOn.lootOpen then
        return false, ML.AwardReasons.Failure.LootNotOpen
    elseif not lootSlotInfo or (not AddOn:ItemIsItem(lootSlotInfo.link, item)) then
        return false, ML.AwardReasons.Failure.LootGone
    elseif lootSlotInfo.locked then
        return false, ML.AwardReasons.Failure.Locked
    elseif AddOn:UnitIsUnit(winner, "player") and not self:HaveFreeSpaceForItem(item.link) then
        return false, ML.AwardReasons.Failure.MLInventoryFull
    elseif AddOn:UnitIsUnit(winner, "player") then
        if lootSlotInfo.quality < GetLootThreshold() then
            return false, ML.AwardReasons.Failure.QualityBelowThreshold
        end
        
        local shortName = Ambiguate(winner, "short"):lower()
        if not UnitIsInParty(shortName) and not UnitIsInRaid(shortName) then
            return false, ML.AwardReasons.Failure.NotInGroup
        end
    
        if not UnitIsConnected(shortName) then
            return false, ML.AwardReasons.Failure.Offline
        end
        
        local found = false
        for i = 1, MAX_RAID_MEMBERS do
            if AddOn:UnitIsUnit(GetMasterLootCandidate(slot, i), winner) then
                found = true
                break
            end
        end
    
        if not IsInInstance() then
            return false, ML.AwardReasons.Failure.MLNotInInstance
        end
    
        if select(4, UnitPosition(Ambiguate(winner, "short"))) ~= select(4, UnitPosition("player")) then
            return false, ML.AwardReasons.Failure.OutOfInstance
        end
        
        
        if not found then
            local bindType = select(14, GetItemInfo(item))
            if bindType ~= LE_ITEM_BIND_ON_ACQUIRE then
                return false, ML.AwardReasons.Failure.NotBop
            else
                return false, ML.NotMLCandidate
            end
        end
    end
    
    return true
end

function ML:PrintLootError(cause, slot, item, winner)
    Logging:Warn("PrintLootError() %s, %s, %s, %s", cause, tostring(slot), tostring(item), tostring(winner))
    
    if cause == ML.AwardReasons.Failure.LootNotOpen then
        AddOn:Print(L["unable_to_give_loot_without_loot_window_open"])
    elseif cause == ML.AwardReasons.Failure.Timeout then
        AddOn:Print(format(L["timeout_giving_item_to_player"], item, AddOn:GetUnitClassColoredName(winner)), " - ", _G.ERR_INV_FULL)
    elseif cause == ML.AwardReasons.Failure.Locked then
        AddOn:SessionError(format(L["no_permission_to_loot_item_at_x"], slot))
    else
        local prefix = format(L["unable_to_give_item_to_player'"], item, AddOn:GetUnitClassColoredName(winner)) .. "  - "
        if cause ==  ML.AwardReasons.Failure.LootGone then
            AddOn:Print(prefix, _G.LOOT_GONE)
        elseif cause == ML.AwardReasons.Failure.MLInventoryFull then
            AddOn:Print(prefix, _G.ERR_INV_FULL)
        elseif cause == ML.AwardReasons.Failure.QualityBelowThreshold then
            AddOn:Print(prefix, L["item_quality_below_threshold"])
        elseif cause == ML.AwardReasons.Failure.NotInGroup then
            AddOn:Print(prefix, L["player_not_in_group"])
        elseif cause == ML.AwardReasons.Failure.Offline then
            AddOn:Print(prefix, L["player_offline"])
        elseif cause == ML.AwardReasons.Failure.MLNotInInstance then
            AddOn:Print(prefix, L["you_are_not_in_instance"])
        elseif cause == ML.AwardReasons.Failure.OutOfInstance then
            AddOn:Print(prefix, L["player_not_in_instance"])
        elseif cause == ML.AwardReasons.Failure.NotMLCandidate then
            AddOn:Print(prefix, L["player_ineligible_for_item"])
        elseif cause == ML.AwardReasons.Failure.NotBop then
            AddOn:Print(prefix, L["item_only_able_to_be_looted_by_you_bop"])
        else
            AddOn:Print(prefix)
        end
    end
end

local function AwardFailed(session, winner, status, callback, ...)
    Logging:Debug("AwardFailed : %d, %s, %s, %s", session, winner, status. Util.Objects.ToString(callback))
    AddOn:SendMessage(AddOn.Constants.Messages.AwardFailed, session, winner, status)
    if callback then
        callback(false, session, winner, status, ...)
    end
    return false
end

local function AwardSuccess(session, winner, status, callback, ...)
    Logging:Debug("AwardSuccess : %d, %s, %s, %s", session, winner, status, Util.Objects.ToString(callback))
    AddOn:SendMessage(AddOn.Constants.Messages.AwardSuccess, session, winner, status)
    if callback then
        callback(true, session, winner, status, ...)
    end
    return true
end

local function RegisterAndAnnounceAward(session, winner, response, reason, itemAward)
    local C, self = AddOn.Constants, ML
    local itemEntry = self:GetItem(session)
    local previousWinner = itemEntry.awarded
    itemEntry.awarded = winner
    
    AddOn:SendCommand(C.group, C.Commands.Awarded, session, winner, itemEntry.owner)
    
    -- AnnounceAward(name, link, response, roll, session, changeAward, owner)
    self:AnnounceAward(winner, itemEntry.link, reason and reason.text or response,
                       AddOn:LootAllocateModule():GetCandidateData(session, winner, "roll"),
                       session, previousWinner, nil, itemAward)
    
    if self:HaveAllItemsBeenAwarded() then
        AddOn:Print(L["all_items_have_been_awarded"])
        self:ScheduleTimer("EndSession", 1)
    end
    
    return true
end

local function RegisterAndAnnounceBagged(session)
    local C, self = AddOn.Constants, ML
    local itemEntry = self:GetItem(session)
    
    -- important to emit this for now in case this code path is hit
    Logging:Warn("RegisterAndAnnounceBagged(%d) : Bagging an item, but support lacking for awarding later", session)
    
    -- todo : put item into storage
    -- todo: all of this is superfluous without that
    
    if itemEntry.lootSlot and self.running then
        self:AnnounceAward(L["loot_master"], itemEntry.link, L["store_in_bag_award_later"], nil, session)
    else
        AddOn:Print(format(L["item_added_to_award_later_list"], itemEntry.link))
    end
    
    self.lootTable[session].lootSlot = nil
    self.lootTable[session].bagged = {} -- todo : replace with actual item
    
    if self.running then
        AddOn:SendCommand(C.group, C.Commands.Bagged, session, AddOn.playerName)
    end
    
    return false
end

--@param session the session to award.
--@param winner	Nil/false if items should be stored in inventory and awarded later.
--@param response the candidates response, used for announcement.
--@param reason	entry in awardReasons (only populated if awarded for a reason other than response - e.g. Free)
--@param callback This function will be called as callback(awarded, session, winner, status, ...)
--@returns true if award is success. false if award is failed. nil if we don't know the result yet.
function ML:Award(session, winner, response, reason, callback, ...)
    Logging:Debug("Award(%s) : %s, %s, %s", tostring(session), tostring(winner), tostring(response), Util.Objects.ToString(reason))
    local args = {...}
    -- data is passed through in position #1
    local itemAward = args[1]
    
    if not self.lootTable or #self.lootTable == 0 then
        if self.oldLootTable and #self.oldLootTable > 0 then
            self.lootTable = self.oldLootTable
        else
            Logging:Error("Award() : Neither Loot Table or Old Loot Table populated")
            return false
        end
    end
    
    local itemEntry = self:GetItem(session)
    
    -- UnLootedItemInBag : an item that's currently in loot table is also bagged
    if itemEntry.lootSlot and itemEntry.bagged then
        AwardFailed(session, winner, ML.AwardReasons.Failure.UnLootedItemInBag, callback, ...)
        AddOn:SessionError("Session %d has an un-looted item in the bag?!", session)
        return false
    end
    
    -- BaggedItemCannotBeAwarded : an item was previously bagged, but cannot be awarded
    if itemEntry.bagged and not winner then
        AwardFailed(session, nil, ML.AwardReasons.Failure.BaggedItemCannotBeAwarded, callback, ...)
        Logging:Error("Award() : " .. L["item_bagged_cannot_be_awarded"])
        AddOn:Print(L["item_bagged_cannot_be_awarded"])
        return false
    end
    
    -- BaggingAwardedItem : an item has been previously awarded, but trying to award later
    if itemEntry.awarded and not winner then
        AwardFailed(session, nil, ML.AwardReasons.Failure.BaggingAwardedItem, callback, ...)
        Logging:Error("Award() " .. L["item_awarded_no_reaward"])
        AddOn:Print(L["item_awarded_no_reaward"])
        return false
    end
    
    -- already awarded, change to whom it was awarded
    if itemEntry.awarded then
        RegisterAndAnnounceAward(session, winner, response, reason, itemAward)
        if not itemEntry.lootSlot and not itemEntry.bagged then
            AwardSuccess(session, winner, AddOn:TestModeEnabled() and ML.AwardReasons.Neutral.TestMode or  ML.AwardReasons.Success.ManuallyAdded, callback, ...)
        elseif itemEntry.bagged then
            AwardSuccess(session, winner, ML.AwardReasons.Success.Indirect, callback, ...)
        else
            AwardSuccess(session, winner, ML.AwardReasons.Success.Normal, callback, ...)
        end
        return true
    end
    
    -- item has not yet been awarded
    if not itemEntry.lootSlot and not itemEntry.bagged then
        if winner then
            AwardSuccess(session, winner, AddOn:TestModeEnabled() and  ML.AwardReasons.Neutral.TestMode or  ML.AwardReasons.Success.ManuallyAdded, callback, ...)
            RegisterAndAnnounceAward(session, winner, response, reason, itemAward)
            return true
        else
            if AddOn:TestModeEnabled() then
                AwardFailed(session, nil, ML.AwardReasons.Neutral.TestMode, callback, ...)
                AddOn:Print(L["award_later_unsupported_when_testing"])
                return false
            else
                RegisterAndAnnounceBagged(session)
                AwardFailed(session, nil, ML.AwardReasons.Failure.ManuallyBagged, callback, ...)
                return false
            end
        end
    end
    
    -- awarding item from bag
    if itemEntry.bagged then
        RegisterAndAnnounceAward(session, winner, response, reason, itemAward)
        AwardSuccess(session, winner, ML.AwardReasons.Success.Indirect, callback, ...)
        return true
    end
    
    -- loot is open, make sure item didn't change
    if AddOn.lootOpen and not AddOn:ItemIsItem(itemEntry.link, GetLootSlotLink(itemEntry.lootSlot)) then
        Logging:Debug("Award(%d) - Loot slot changed before award completed", session)
        self:UpdateLootSlots()
    end
    
    local canGiveLoot, cause = self:CanGiveLoot(itemEntry.lootSlot, itemEntry.link, winner or AddOn.playerName)
    if not canGiveLoot then
        if cause == ML.AwardReasons.Failure.QualityBelowThreshold or cause == ML.AwardReasons.Failure.NotBop then
            self:PrintLootError(cause, itemEntry.lootSlot, itemEntry.link, winner or AddOn.playerName)
            AddOn:Print("Gave the item to you for distribution")
            return self:Award(session, nil, response, reason, callback, ...)
        else
            AwardFailed(session, winner, cause, callback, ...)
            self:PrintLootError(cause, itemEntry.lootSlot, itemEntry.link, winner or AddOn.playerName)
            return false
        end
    else
        if winner then
            self:GiveLoot(
                    itemEntry.lootSlot,
                    winner,
                    function(awarded, cause)
                        if awarded then
                            RegisterAndAnnounceAward(session, winner, response, reason, itemAward)
                            AwardSuccess(session, winner, ML.AwardReasons.Success.Normal, callback, unpack(args))
                            return true
                        else
                            AwardFailed(session, winner, cause, callback, unpack(args))
                            self:PrintLootError(cause, itemEntry.lootSlot, itemEntry.link, winner)
                            return false
                        end
                    end
            )
        else
            self:GiveLoot(
                    itemEntry.lootSlot,
                    AddOn.playerName,
                    function(awarded, cause)
                        if awarded then
                            RegisterAndAnnounceBagged(session)
                            AwardFailed(session, nil, ML.AwardReasons.Failure.Bagged, callback, unpack(args))
                        else
                            AwardFailed(session, nil, cause, callback, unpack(args))
                            self:PrintLootError(cause, itemEntry.lootSlot, itemEntry.link, AddOn.playerName)
                        end
                        return false
                    end
            )
        end
    end
end

local function OnGiveLootTimeout(entry)
    -- remove entry from queue
    for k, v in pairs(ML.lootQueue) do
        if v == entry then
            tremove(ML.lootQueue, k)
        end
    end
    
    if entry.callback then
        -- loot attempt failed
        entry.callback(false, ML.AwardReasons.Failure.Timeout, unpack(entry.cargs))
    end
end

function ML:GiveLoot(slot, winner, callback, ...)
    if AddOn.lootOpen then
        local entry = {slot = slot, callback = callback, args = {...}, }
        entry.timer = self:ScheduleTimer(OnGiveLootTimeout, LOOT_TIMEOUT, entry)
        Util.Tables.Push(self.lootQueue, entry)
    
        for i = 1, MAX_RAID_MEMBERS do
            if AddOn.UnitIsUnit(GetMasterLootCandidate(slot, i), winner) then
                Logging:Debug("GiveLoot(%d, %d)", slot, i)
                GiveMasterLoot(slot, i)
                break
            end
        end
    
        -- if the loot goes to ML, may need to self-loot
        -- won't hurt if previous block gave it out
        if AddOn:UnitIsUnit(winner, "player") then
            Logging:Debug("GiveLoot(%d) - Giving to ML", slot)
            LootSlot(slot)
        end
    end
end

function ML:UpdateLootSlots()
    if not AddOn.lootOpen then
        Logging:Warn("UpdateLootSlots() : Attempting to update loot slots without an open loot window")
        return
    end
    
    local updatedLootSlots = {}
    for i = 1, GetNumLootItems() do
        local item = GetLootSlotLink(i)
        for session = 1, #self.lootTable do
            local itemEntry = self:GetItem(session)
            if not itemEntry.awarded and not updatedLootSlots[session] then
                if AddOn:ItemIsItem(item, itemEntry.link) then
                    if i ~= itemEntry.lootSlot then
                        Logging:Debug("UpdateLootSlots(%d) : previously at %d, not at %d", itemEntry.lootSlot, i)
                    end
                    itemEntry.lootSlot = i
                    updatedLootSlots[session] = true
                    break
                end
            end
        end
    end
end

ML.AnnounceItemStrings = {
    ["&s"] = function(ses) return ses end,
    ["&i"] = function(...) return select(2,...) end,
    ["&l"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetLevelText() or "" end,
    ["&t"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetTypeText() or "" end,
    ["&o"] = function(_,_,v) return v.owner and AddOn.Ambiguate(v.owner) or "" end,
}

function ML:AnnounceItems(table)
    if not self.db.profile.announceItems then return end
    Logging:Trace("AnnounceItems()")
    
    local channel, text = self.db.profile.announceAwardText.channel,self.db.profile.announceAwardText.text
    AddOn:SendAnnouncement(self.db.profile.announceItemPrefix, channel)
    Util.Tables.Iter(table,
                     function(v, i)
                         local msg = text
                         for text, fn in pairs(self.AnnounceItemStrings) do
                             msg = gsub(msg, text, escapePatternSymbols(tostring(fn(v.session or i, v.link, v))))
                         end
                         if v.isRoll then
                             msg = _G.ROLL .. ": " .. msg
                         end
                         AddOn:SendAnnouncement(msg, channel)
                     end
    )
end

ML.AwardStrings = {
    ["&s"] = function(_, _, _, _, session) return session or "" end,
    ["&p"] = function(name) return AddOn.Ambiguate(name) end,
    ["&i"] = function(...) return select(2, ...) end,
    ["&r"] = function(...) return select(3, ...) or "" end,
    ["&n"] = function(...) return select(4, ...) or "" end,
    ["&l"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetLevelText() or "" end,
    ["&t"] = function(_, item)
        local t = ML:GetItemInfo(item)
        return t and t:GetTypeText() or "" end,
    ["&o"] = function(...)
        local session = select(5, ...)
        local owner = select(6, ...) or ML.lootTable[session] and  ML.lootTable[session].owner
        return owner and AddOn.Ambiguate(owner) or _G.UNKNOWN end,
    ["&m"] = function(...)
        return AddOn:LootAllocateModule():GetCandidateData(select(5,...), select(1,...), "note") or "<none>"
    end,
    ["&g"] = function(...)
        local gp = select(7, ...)
        return gp and tostring(gp) or "N/A"
    end,
}

function ML:AnnounceAward(name, link, response, roll, session, changeAward, owner, itemAward)
    if not self.db.profile.announceAwards then return end
    
    local gp = itemAward and itemAward:GetGp() or nil
    -- pretty up some texts (if able to
    if itemAward then
        local r = itemAward:NormalizedResponse()
        response = UI.ColoredDecorator(r.color):decorate(response)
        name = UI.ColoredDecorator(AddOn.GetClassColor(itemAward.class)):decorate(name)
    end
    
    for _, awardText in pairs(self.db.profile.announceAwardText) do
        local message = awardText.text
        for text, func in pairs(self.AwardStrings) do
            message = gsub(message, text, escapePatternSymbols(tostring(func(name, link, response, roll, session, owner, gp))))
        end
        if changeAward then
            message = "(" .. L["change_award"] .. ") " .. message
        end
        AddOn:SendAnnouncement(message, awardText.channel)
    end
end

function ML:StartSession()
    Logging:Debug("StartSession()")
    local C = AddOn.Constants

    if not AddOn.candidates[AddOn.playerName] then
        AddOn:Print(L["session_data_sync"])
        Logging:Debug("Session data not yet available")
        return
    end

    -- only sort if we not currently in-flight
    --if not self.running then
    --    self:SortLootTable(self.lootTable)
    --end

    -- if a session is already running, need to add any new items
    if self.running then
        AddOn:SendCommand(C.group, C.Commands.LootTableAdd, self:GetLootTableForTransmit())
    else
        AddOn:SendCommand(C.group, C.Commands.LootTable, self:GetLootTableForTransmit())
    end

    -- update the loot table to mark entries as having been transmitted
    Util.Tables.Call(self.lootTable, function(entry) entry.isSent = true end)

    self.running = true
    self:AnnounceItems(self.lootTable)
end

function ML:HaveAllItemsBeenAwarded()
    local moreItems = true
    for i = 1, #self.lootTable do
        if not self.lootTable[i].awarded then
            moreItems = false
        end
    end
    return moreItems
end

function ML:EndSession()
    Logging:Debug("EndSession()")
    local C = AddOn.Constants
    self.oldLootTable = self.lootTable
    self.lootTable = {}
    AddOn:SendCommand(C.group, C.Commands.LootSessionEnd)
    self.running = false
    self:CancelAllTimers()
    if AddOn:TestModeEnabled()  then
        AddOn:ScheduleTimer("NewMasterLooterCheck", 1)
    end
    AddOn.mode:Disable(AddOn.Constants.Modes.Test)
end

function ML:OnEvent(event, ...)
    Logging:Debug("OnEvent(%s)", event)
    
    if event == AddOn.Constants.Events.ChatMessageWhisper and AddOn.isMasterLooter and self:DbValue('acceptWhispers') then
        local msg, sender = ...
        if msg == '!help' then
            self:SendWhisperHelp(sender)
        elseif msg == '!items' then
            self:SendWhisperItems(sender)
        elseif Util.Strings.StartsWith(msg, "!item") and self.running then
            self:GetItemsFromMessage(gsub(msg, "!item", ""):trim(), sender)
        elseif Util.Strings.StartsWith(msg, "!standby") and self.running then
        
        end
    elseif event == AddOn.Constants.Events.PlayerRegenEnabled then
        -- todo : when award later is implemented, check if any items are low on trade time remaining
        -- todo : should i implement callbacks in case of combat to resume loot allocation?
    end
end

function ML:SendWhisperHelp(target)
    Logging:Debug("SendWhisperHelp(%s)", target)
    SendChatMessage(L["whisper_guide_1"], "WHISPER", nil, target)
    local msg, db = nil, self.db.profile
    for i = 1, db.buttons.default.numButtons do
        msg = "[R2D2]: ".. db.buttons.default[i]["text"] .. ":  "
        msg = msg .. "" .. db.buttons.default[i]["whisperKey"]
        SendChatMessage(msg, "WHISPER", nil, target)
    end
    SendChatMessage(L["whisper_guide_2"], "WHISPER", nil, target)
end

function ML:SendWhisperItems(target)
    Logging:Debug("SendWhisperHelp(%s)", target)
    SendChatMessage(L["whisper_items"], "WHISPER", nil, target)
    if #self.lootTable == 0 then
        SendChatMessage(L["whisper_items_none"], "WHISPER", nil, target)
    else
        for session, item in pairs(self.lootTable) do
            SendChatMessage(format("%d   %s", session, item.link), "WHISPER", nil, target)
        end
    end
end

function ML:GetItemsFromMessage(msg, sender)
    Logging:Debug("GetItemsFromMessage(%s) : %s", sender, msg)
    
    local C = AddOn.Constants
    if not AddOn.isMasterLooter then return end
   
    local sessionArg, responseArg = AddOn:GetArgs(msg, 2)
    sessionArg = tonumber(sessionArg)
    
    if not sessionArg or not Util.Objects.IsNumber(sessionArg) or sessionArg > #self.lootTable then return end
    if not responseArg then return end
    
    -- default to response #1 if not specified
    local response = 1
    local whisperKeys = {}
    for k, v in pairs(self.db.profile.buttons.default) do
        if k ~= 'numButtons' then
            -- extract the whisperKeys to a table
            gsub(v.whisperKey, '[%w]+', function(x) tinsert(whisperKeys, {key = x, num = k}) end)
        end
    end
    
    for _,v in ipairs(whisperKeys) do
        if strmatch(responseArg, v.key) then
            response = v.num
            break
        end
    end
    
    local toSend = {
        gear1 = nil,
        gear2 = nil,
        ilvl = nil,
        diff = nil,
        note = L["auto_extracted_from_whisper"],
        response = response
    }
    
    local count = 0
    local link = self.lootTable[sessionArg].link
    for s, v in ipairs(self.lootTable) do
        if AddOn:ItemIsItem(v.link, link) then
            AddOn:SendCommand(C.group, C.Commands.Response, s, sender, toSend)
            count = count + 1
        end
    end
    
    -- todo : could put stuff in here for current items they are using, but not for now
    local typeCode = self.lootTable[sessionArg].typeCode or self.lootTable[sessionArg].equipLoc
    AddOn:Print(format(L["item_response_ack_from_s"], link, AddOn.Ambiguate(sender)))
    SendChatMessage(
            format(L["whisper_item_ack"],
                   AddOn:GetItemTextWithCount(link, count),
                   AddOn:GetResponse(typeCode, response).text
            ), "WHISPER", nil, sender)
end

function ML:OnCommReceived(prefix, serializedMsg, dist, sender)
    Logging:Trace("OnCommReceived() : prefix=%s, via=%s, sender=%s", prefix, dist, sender)
    Logging:Trace("OnCommReceived() : %s", serializedMsg)
    
    local C = AddOn.Constants
    if prefix == C.name then
        local success, command, data = AddOn:Deserialize(serializedMsg)
        Logging:Debug("OnCommReceived() : success=%s, command=%s, from=%s, dist=%s, data=%s",
                      tostring(success), command, tostring(sender), tostring(dist),
                      Util.Objects.ToString(data, 3)
        )
        
        -- only ML receives these commands
        if success and AddOn.isMasterLooter then
            if command == C.Commands.PlayerInfo then
                self:AddCandidate(unpack(data))
                self:SendCandidates()
            elseif command == C.Commands.MasterLooterDbRequest then
                AddOn:SendCommand(C.group, C.Commands.MasterLooterDb, AddOn.mlDb)
            elseif command == C.Commands.CandidatesRequest then
                self:SendCandidates()
            elseif command == C.Commands.Reconnect and not AddOn:UnitIsUnit(sender, AddOn.playerName) then
                -- resend the master looter DB
                AddOn:SendCommand(sender, C.Commands.MasterLooterDb, AddOn.mlDb)
                -- resend the candidates
                AddOn:ScheduleTimer("SendCommand", 2, sender, C.Commands.Candidates, self.candidates)
                if self.running then
                    -- resend the loot table
                    AddOn:ScheduleTimer("SendCommand", 4, sender,  C.Commands.LootTable, self:GetLootTableForTransmit())
                end
            elseif command == C.Commands.LootTable and AddOn:UnitIsUnit(sender, AddOn.playerName) then
                self:ScheduleTimer("Timer", 11 + 0.5 * #self.lootTable, "LootSend")
            end
        end
    end
end

function ML:CanWeLootItem(item, quality)
    local ret = false
    -- item is set (AND)
    -- auto-loot is enabled (AND)
    -- item is equipable OR auto-loot non-equipable (AND)
    -- quality is set and >= our threshol
    if item and self.db.profile.autoLootEquipable and
        (IsEquippableItem(item) or self.db.profile.autoLootNonEquipable) and
        (quality and quality >= GetLootThreshold()) then
        return self.db.profile.autoLootBoe or not AddOn:IsItemBoe(item)
    end
    Logging:Debug("CanWeLootItem(%s, %s) = %s", item, tostring(quality), tostring(ret))
    return ret
end

function ML:LootOpened()
    if AddOn.isMasterLooter and GetNumLootItems() > 0 then
        local LS = AddOn:LootSessionModule()
        
        -- check if we need to update the existing session
        if self.running and LS:IsRunning() then
            self:UpdateLootSlots()
        -- not running, just add the loot
        else
            for i = 1, GetNumLootItems() do
                local item =  AddOn:GetLootSlotInfo(i)
                if item then
                    local link = item.link
                    local quantity = item.quantity
                    local quality = item.quality
                    -- todo : alt-click looting (maybe)
                    -- todo : auto-awarding of items (probably not)
                    -- check if we are allowed to loot item
                    if link and self:CanWeLootItem(link, quality) and quantity > 0 then
                        self:AddItem(link, false, i)
                    -- currency
                    elseif quantity == 0 then
                        LootSlot(i)
                    end
                end
            end
            
    
            if #self.lootTable > 0 and not self.running then
                if self.db.profile.autoStart and AddOn:GetCandidate(AddOn.playerName) then
                    self:StartSession()
                else
                    AddOn:CallModule(LS:GetName())
                    LS:Show(self.lootTable)
                end
            end
        end
    end
end

function ML:OnLootOpen()
    if AddOn.handleLoot then
        wipe(self.lootQueue)
        if not InCombatLockdown() then -- skip combat lock-down setting?
            self:LootOpened()
        else
            AddOn:Print("You can't start a loot session while in combat")
        end
    end
end

function ML:OnLootSlotCleared(slot, link)
    for i = #self.lootQueue, 1, -1 do
        local entry = self.lootQueue[i]
        -- loot success
        if entry and entry.slot == slot then
            self:CancelTimer(entry.timer)
            self.lootQueue[i] = nil
            if entry.callback then
                entry.callback(true, nil, unpack(entry.args))
            end
            break
        end
    end
end

function ML:Test(items)
    Logging:Debug("Test(%s)", Util.Tables.Count(items))
    local C = AddOn.Constants

    if not tContains(self.candidates, AddOn.playerName) then
        self:AddCandidate(AddOn.playerName, AddOn.playerClass, AddOn.guildRank)
    end
    AddOn:SendCommand(C.group, C.Commands.Candidates, self.candidates)
    for _, name in ipairs(items) do
        self:AddItem(name)
    end
    if self.db.profile.autoStart then
        AddOn:Print("Auto-start isn't supported when testing")
    end
    
    AddOn:CallModule("LootSession")
    AddOn:GetModule("LootSession"):Show(self.lootTable)
end

-- Award popup control functions
-- data is an instance of ItemAward
function ML.AwardPopupOnShow(frame, data)
    UI.DecoratePopup(frame)
    local awardTo =  AddOn.Ambiguate(data.winner)
    local c = AddOn.GetClassColor(data.class)
    frame:SetFrameStrata("FULLSCREEN")
    frame.text:SetText(format(L["confirm_award_item_to_player"], data.link, c:WrapTextInColorCode(awardTo)))
    frame.icon:SetTexture(data.texture)
end

function ML.AwardPopupOnClickYesCallback(awarded, session, winner, status, data, callback, ...)
    -- Logging:Debug("AwardPopupOnClickYesCallback(%s, %d, %s, %s)", tostring(awarded), session, winner, status)
    -- Logging:Debug("AwardPopupOnClickYesCallback(%d) : %s", session, Util.Objects.ToString(data))
    if callback and Util.Objects.IsFunction(callback) then
        callback(awarded, session, winner, status, data, ...)
    end
    
    if awarded then
        AddOn:GearPointsModule():OnAwardItem(data)
    end
end

function ML.AwardPopupOnClickYes(frame, data, callback, ...)
    -- Logging:Debug("AwardPopupOnClickYes() : %s, %s", Util.Objects.ToString(callback), Util.Objects.ToString(data, 3))
    -- todo : this could be collapsed entirely into passing data (ItemAward)
    ML:Award(
        data.session,
        data.winner,
        data:NormalizedResponse().text, -- todo: can't we do this later?
        data.reason,
        ML.AwardPopupOnClickYesCallback,
        data,
        callback,
        ...
    )
    -- we need to delay the test mode disabling so comms have a chance to be sent first
    if AddOn:TestModeEnabled() and ML:HaveAllItemsBeenAwarded() then ML:EndSession() end
end

function ML.AwardPopupOnClickNo(frame, data)
    -- Intentionally left empty
end


ML.EquipmentLocationSortOrder = {
    "INVTYPE_HEAD",
    "INVTYPE_NECK",
    "INVTYPE_SHOULDER",
    "INVTYPE_CLOAK",
    "INVTYPE_ROBE",
    "INVTYPE_CHEST",
    "INVTYPE_WRIST",
    "INVTYPE_HAND",
    "INVTYPE_WAIST",
    "INVTYPE_LEGS",
    "INVTYPE_FEET",
    "INVTYPE_FINGER",
    "INVTYPE_TRINKET",
    "", -- miscellaneous (tokens, relics, etc.)
    "INVTYPE_RELIC",
    "INVTYPE_QUIVER",
    "INVTYPE_RANGED",
    "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN",
    "INVTYPE_2HWEAPON",
    "INVTYPE_WEAPON",
    "INVTYPE_WEAPONMAINHAND",
    "INVTYPE_WEAPONMAINHAND_PET",
    "INVTYPE_WEAPONOFFHAND",
    "INVTYPE_HOLDABLE",
    "INVTYPE_SHIELD",
}
-- invert it with equipment location as index and prev. index as value
ML.EquipmentLocationSortOrder = tInvert(ML.EquipmentLocationSortOrder)
-- add robes at same index as chest
ML.EquipmentLocationSortOrder["INVTYPE_ROBE"] = ML.EquipmentLocationSortOrder["INVTYPE_CHEST"]

function ML:SortLootTable(lootTable)
    table.sort(lootTable, self.LootTableCompare)
end

local function GetItemStatsSum(link)
    local stats = GetItemStats(link)
    local sum = 0
    for _, value in pairs(stats or {}) do
        sum = sum + value
    end
    return sum
end

-- The loot table sort compare function
-- Sorted by:
-- 1. equipment slot: head, neck, ...
-- 2. trinket category name
-- 3. subType: junk(armor token), plate, mail, ...
-- 4. relicType: Arcane, Life, ..
-- 5. Item level from high to low
-- 6. The sum of item stats, to make sure items with bonuses(socket, leech, etc) are sorted first.
-- 7. Item name
--
-- @param a: an entry in the lootTable
-- @param b: The other entry in the looTable
-- @return true if a is sorted before b
function ML.LootTableCompare(a, b)
    if not a.link then return false end
    if not b.link then return true end

    -- todo : add support for item tokens
    local elA = ML.EquipmentLocationSortOrder[a.equipLoc] or math.huge
    local elB = ML.EquipmentLocationSortOrder[b.equipLoc] or math.huge
    if elA ~= elB then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.equipLoc, b.equipLoc, tostring(elA < elB))
        return elA < elB
    end

    -- todo : add support for trinkets
    --if a.equipLoc == "INVTYPE_TRINKET" and b.equipLoc == "INVTYPE_TRINKET" then
    --
    --end

    if a.typeId ~= b.typeId then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.typeId, b.typeId, tostring(a.typeId > b.typeId))
        return a.typeId > b.typeId
    end

    if a.subTypeId ~= b.subTypeId then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.subTypeId, b.subTypeId, tostring(a.subTypeId > b.subTypeId))
        return a.subTypeId > b.subTypeId
    end
    
    if a.ilvl ~= b.ilvl then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.ilvl, b.ilvl, tostring( a.ilvl > b.ilvl))
        return a.ilvl > b.ilvl
    end

    local statsA = GetItemStatsSum(a.link)
    local statsB = GetItemStatsSum(b.link)
    if statsA ~= statsB then
        Logging:Trace("LootTableCompare(%s, %s) : %s", a.link, b.link, tostring(  statsA > statsB))
        return statsA > statsB
    end

    local nameA = ItemUtil:ItemLinkToItemName(a.link)
    local nameB = ItemUtil:ItemLinkToItemName(b.link)
    Logging:Trace("LootTableCompare(%s, %s) : %s", a.link, b.link, tostring(  nameA < nameB))

    return nameA < nameB
end
