local _, AddOn = ...
local Dialog = AddOn.Libs.Dialog
local Logging = AddOn.Libs.Logging
local L = AddOn.components.Locale
local UI = AddOn.components.UI

Dialog:Register(AddOn.Constants.Popups.ConfirmUsage, {
    text = L["confirm_usage_text"],
    on_show = function(self)
        UI.DecoratePopup(self)
    end,
    buttons = {
        {
            text = _G.YES,
            on_click = function()
                AddOn:StartHandleLoot()
            end,
        },
        {
            text = _G.NO,
            on_click = function()
                AddOn:Print(L["is_not_active_in_this_raid"])
            end,
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})

Dialog:Register(AddOn.Constants.Popups.ConfirmAward, {
    text = "something_went_wrong",
    icon = "",
    on_show = AddOn:MasterLooterModule().AwardPopupOnShow,
    buttons = {
        {
            text = _G.YES,
            on_click = AddOn:MasterLooterModule().AwardPopupOnClickYes
        },
        {
            text = _G.NO,
            on_click = AddOn:MasterLooterModule().AwardPopupOnClickNo
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})

Dialog:Register(AddOn.Constants.Popups.ConfirmAbort, {
    text = L["confirm_abort"],
    on_show = function(self)
        UI.DecoratePopup(self)
    end,
    buttons = {
        {
            text = _G.YES,
            on_click = function(self)
                Logging:Debug("Master Looter aborted session")
                AddOn:MasterLooterModule():EndSession()
                CloseLoot()
                AddOn:LootAllocateModule():EndSession(true)
            end,
        },
        {
            text = _G.NO,
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})

Dialog:Register(AddOn.Constants.Popups.ConfirmReannounceItems, {
    text = "something_went_wrong",
    on_show = function(self, data)
        UI.DecoratePopup(self)
        if data.isRoll then
            self.text:SetText(format(L["confirm_rolls"], data.text))
        else
            self.text:SetText(format(L["confirm_unawarded"], data.text))
        end
    end,
    buttons = {
        {
            text = _G.YES,
            on_click = function(self, data)
                data.func()
            end,
        },
        {
            text = _G.NO,
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})

Dialog:Register(AddOn.Constants.Popups.ConfirmAdjustPoints, {
    text = "something_went_wrong",
    on_show = AddOn:PointsModule().AdjustPointsOnShow,
    buttons = {
        {
            text = _G.YES,
            on_click = AddOn:PointsModule().AwardPopupOnClickYes,
        },
        {
            text = _G.NO,
            on_click = AddOn:PointsModule().AwardPopupOnClickNo
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})

Dialog:Register(AddOn.Constants.Popups.ConfirmDecayPoints, {
    text = "something_went_wrong",
    on_show = AddOn:PointsModule().DecayOnShow,
    buttons = {
        {
            text = _G.YES,
            on_click = AddOn:PointsModule().DecayOnClickYes,
        },
        {
            text = _G.NO,
            on_click = AddOn:PointsModule().DecayOnClickNo
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})