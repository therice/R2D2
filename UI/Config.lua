local _, AddOn = ...
local L         = AddOn.components.Locale
local Logging   = AddOn.components.Logging
local Util      = AddOn.Libs.Util
local Objects   = Util.Objects
local COpts     = AddOn.components.UI.ConfigOptions
local Config    = {}

AddOn.components.Config = Config
-- name, width, height
AddOn.Libs.AceConfigDialog:SetDefaultSize("R2D2",  900, 600)

function Config.SetupOptions()
    local Options = AddOn.Options
    Options.args = {
        -- General configuration options header
        R2D2_Header = COpts.Header(L["version"] .. format(": |cff99ff33%s|r", AddOn.version), 'full')
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
                Logging:Trace("Config:SetupOptions() : Registering option arguments with name %s", name)
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