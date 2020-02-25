local _, AddOn = ...
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Tables    = AddOn.components.Util.Tables
local Config    = {}

AddOn.components.Config = Config
AddOn.Libs.AceConfigDialog:SetDefaultSize("R2D2",  810, 550)

function Config.SetupOptions()
    local Options = AddOn.Options

    Options.args = {
        -- General configuration options header
        R2D2_Header = {
            order = 1,
            type = "header",
            name = L["version"] .. format(": |cff99ff33%s|r", AddOn.version),
            width = "full"
        },
    }

    AddOn.Libs.AceConfig:RegisterOptionsTable("R2D2", Options)

    local moduleTable = {}
    for name, module in AddOn:IterateModules() do
        moduleTable[name] = module
    end

    -- Setup options for each module that defines them.
    for name, m in Tables.Iterate(moduleTable, nil) do
        Logging:Debug("Config.SetupOptions() : Examining Module Entry '%s'", name)
        -- If the module has an options instance
        if m.options then
            if m.options.args and (not m.options.ignore_enable_disable) then
                -- Set all options under this module as disabled when the module is disabled.
                for n, o in pairs(m.options.args) do
                    Logging:Debug("Config.SetupOptions() : Modifying 'disabled' property for argument %s.%s", name, n)
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
                Logging:Debug("Config:SetupOptions() : Adding 'enable' option to arguments %s", name)
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
                Logging:Debug("Config:SetupOptions() : Registering option arguments with name %s",  name)
                Options.args[name]= {
                    handler = m,
                    order = 100,
                    type = 'group',
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