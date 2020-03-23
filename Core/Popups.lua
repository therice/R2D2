local _, AddOn = ...
local Dialog    = AddOn.Libs.Dialog
local Logging   = AddOn.Libs.Logging
local L         = AddOn.components.Locale

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
        self:SetFrameStrata("FULLSCREEN")
    end,
    buttons = {
        {
            text = _G.YES,
            on_click = function(self)
                Logging:Debug("Master Looter aborted session")
                AddOn:MasterLooterModule():EndSession()
                CloseLoot()
                AddOn:GetModule("LootAllocate"):EndSession(true)
            end,
        },
        {
            text = _G.NO,
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})
