local name, AddOn = ...
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Objects   = Util.Objects
local COpts     = AddOn.components.UI.ConfigOptions
local Config    = {}

AddOn.components.Config = Config
-- name, width, height
AddOn.Libs.AceConfigDialog:SetDefaultSize("R2D2",  850, 600)

function Config.SetupOptions()
    local Options = Util.Tables.Copy(AddOn.Options)
    -- setup some basic configuration options that don't belong to any module (but the add-on itself)
    Options.args = {
        -- General configuration options header
        R2D2_Header = COpts.Header(L["version"] .. format(": |cff99ff33%s|r", tostring(AddOn.version)), 'full'),
        general = {
            order = 1,
            type = "group",
            name = _G.GENERAL,
            args = {
                generalOptions = {
                    name = L["general_options"],
                    type = "group",
                    inline = true,
                    args = {
                        enable = {
                            order = 1,
                            name  = L["active"],
                            desc  = L["active_desc"],
                            type  = "toggle",
                            set   = function()
                                AddOn.enabled = not AddOn.enabled
                                if not AddOn.enabled and AddOn.isMasterLooter then
                                    AddOn.isMasterLooter = false
                                    AddOn.masterLooter = nil
                                    AddOn:MasterLooterModule():Disable()
                                else
                                    AddOn:NewMasterLooterCheck()
                                end
                            end,
                            get   = function() return AddOn.enabled end,
                        },
                        minimizeInCombat = COpts.Toggle(L["minimize_in_combat"], 2, L["minimize_in_combat_desc"]),
                        spacer = COpts.Header("", nil, 3),
                        test = COpts.Execute(L["Test"], 4, L["test_desc"],
                                             function()
                                                 AddOn.Libs.AceConfigDialog:Close(name)
                                                 AddOn:Test(4)
                                             end
                        ),
                        verCheck = COpts.Execute(L['version_check'], 5, L["version_check_desc"],
                                                 function()
                                                     AddOn.Libs.AceConfigDialog:Close(name)
                                                     AddOn:CallModule('VersionCheck')
                                                 end),
                        sync = COpts.Execute(L["sync"], 6, L["sync_desc"], function() end),
                    }
                }
            }
        }
    }

    AddOn.Libs.AceConfig:RegisterOptionsTable("R2D2", Options)

    local moduleTable = {}
    for name, module in AddOn:IterateModules() do
        moduleTable[name] = module
    end

    -- Setup options for each module that defines them.
    for name, m in Objects.Each(moduleTable) do
        Logging:Debug("Config.SetupOptions() : Examining Module Entry '%s'", name)
        -- If the module has an options instance
        if m.options then
            if m.options.args and (not m.options.ignore_enable_disable) then
                -- Set all options under this module as disabled when the module is disabled.
                for n, o in pairs(m.options.args) do
                    Logging:Trace("Config.SetupOptions() : Modifying 'disabled' property for argument %s.%s", name, n)
                    if o.disabled then
                        local old_disabled = o.disabled
                        o.disabled = function(i)
                            return old_disabled(i) or m:IsDisabled()
                        end
                    else
                        o.disabled = "IsDisabled"
                    end
                end

                -- Add the enable/disable option
                Logging:Trace("Config:SetupOptions() : Adding 'enable' option to arguments %s", name)
                m.options.args.enabled = {
                    order = 1,
                    type = "toggle",
                    width = "full",
                    name = ENABLE,
                    get = "IsEnabled",
                    set = "SetEnabled",
                }
            end

            if m.options.name then
                local childGroups = m.options.childGroups and m.options.childGroups or 'tree'
                Logging:Debug("Config:SetupOptions() : Registering option arguments with name %s", name)
                Options.args[name]= {
                    handler = m,
                    order = 100,
                    type = 'group',
                    childGroups = childGroups,
                    name = m.options.name,
                    desc = m.options.desc,
                    args = m.options.args,
                    get = "GetDbValue",
                    set = "SetDbValue",
                }
            end
        end
    end
end