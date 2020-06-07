local _, AddOn = ...
local LootSession   = AddOn:NewModule("LootSession", "AceEvent-3.0", "AceTimer-3.0")
local L             = AddOn.components.Locale
local Logging       = AddOn.components.Logging
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable
local Util          = AddOn.Libs.Util

local ML
local ROW_HEIGHT = 40
local sessionActive, loadingItems, showPending = false, false, false


function LootSession:OnInitialize()
    Logging:Debug("OnInitialize(%s)", self:GetName())
    self.scrollCols = {
        { name = "", width = 30},           -- remove item, sort by session number.
        { name = "", width = ROW_HEIGHT},	-- item icon
        { name = "", width = 50,}, 	        -- item lvl
        { name = "", width = 160}, 			-- item link
    }
end

function LootSession:OnEnable()
    Logging:Debug("OnEnable(%s)", self:GetName())
    ML = AddOn:GetModule("MasterLooter")
end

function LootSession:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:Hide()
    self.frame.rows = {}
end

function LootSession:EnableOnStartup()
    return false
end

function LootSession:Show(data)
    -- don't show another window if a session is active
    if sessionActive then return end

    self.frame = self:GetFrame()
    self.frame:Show()
    showPending = false

    if data then
        loadingItems = false
        --if not ML.running then
        --    ML:SortLootTable(data)
        --end
        self:ExtractData(data)
        self.frame.st:SetData(self.frame.rows)
        self:Update()
    end
end

function LootSession:Hide()
    self.frame:Hide()
end

function LootSession:IsRunning()
    return self.frame and self.frame:IsVisible()
end


function LootSession:ExtractData(data)
    self.frame.rows = {}

    for sess, entry in ipairs(data) do
        -- Don't add items we've already started a session with
        if not entry.isSent then
            Util.Tables.Push(self.frame.rows, entry:ToRow(sess,
                    {
                        { DoCellUpdate = LootSession.SetCellDeleteButton },
                        { DoCellUpdate = LootSession.SetCellItemIcon },
                        { value = " " .. (entry.ilvl or "") },
                        { DoCellUpdate = LootSession.SetCellText },
                    }
                )
            )
        end
    end
end

function LootSession:Update()
    if ML.running then
        self.frame.startBtn:SetText(_G.ADD)
    else
        self.frame.startBtn:SetText(_G.START)
    end
end

function LootSession:DeleteItem(session, row)
    Logging:Debug("DeleteItem(session=%s, row=%s)", session, row)
    ML:RemoveItem(session)
    self:Show(ML.lootTable)
end

function LootSession.SetCellText(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    if frame.text:GetFontObject() ~= _G.GameFontNormal then
        frame.text:SetFontObject("GameFontNormal")
    end

    if not data[realrow].link then
        frame.text:SetText("--".._G.RETRIEVING_ITEM_INFO.."--")
        loadingItems = true
        if not showPending then
            showPending = true
            LootSession:ScheduleTimer("Show", 0, ML.lootTable)
        end
    else
        -- .. (data[realrow].owner and addon.candidates[data[realrow].owner] and "\n" .. addon:GetUnitClassColoredName(data[realrow].owner) or ""
        frame.text:SetText(data[realrow].link)
    end
end

function LootSession.SetCellDeleteButton(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    frame:SetNormalTexture("Interface/BUTTONS/UI-GroupLoot-Pass-Up.png")
    frame:SetScript("OnClick", function() LootSession:DeleteItem(data[realrow].session, realrow) end)
    frame:SetSize(20,20)
end

function LootSession.SetCellItemIcon(rowFrame, frame, data, cols, row, realrow, column, fShow, table, ...)
    local texture = data[realrow].texture or "Interface/ICONS/INV_Sigil_Thorim.png"
    local link = data[realrow].link
    frame:SetNormalTexture(texture)
    frame:SetScript("OnEnter", function() UI:CreateHypertip(link) end)
    frame:SetScript("OnLeave", function() UI:HideTooltip() end)
    frame:SetScript("OnClick", function()
        if IsModifiedClick() then
            HandleModifiedItemClick(link);
        end
    end)
end

function LootSession:GetFrame()
    if self.frame then return self.frame end
    local f = UI:CreateFrame("R2D2_LootSession", "LootSession", L["r2d2_loot_session_frame"], 260, 325, false)

    -- start button
    local start = UI:CreateButton(_G.START, f.content)
    start:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    start:SetScript("OnClick", function()
        if loadingItems then
            return AddOn:Print(L["session_items_not_loaded"])
        end

        if not ML.lootTable or Util.Tables.Count(ML.lootTable) == 0 then
            AddOn:Print(L["session_no_items"])
            return Logging:Debug("Session cannot be started as there are no items")
        end

        if not AddOn.candidates[AddOn.playerName] then
            AddOn:Print(L["session_data_sync"])
            return Logging:Debug("Session data not yet available")
        elseif InCombatLockdown() then
            return AddOn:Print(L["session_in_combat"])
        else
            ML:StartSession()
        end

        self:Disable()
    end)
    f.startBtn = start

    -- cancel button
    local cancel = UI:CreateButton(_G.CANCEL, f.content)
    cancel:SetPoint("LEFT", start, "RIGHT", 15, 0)
    cancel:SetScript("OnClick", function()
        ML.lootTable = {}
        self:Disable()
    end)
    f.cancel = cancel

    --f.lootStatus = UI:New("Text", f.content, " ")
    --f.lootStatus:SetTextColor(1,1,1,1) -- White for now
    --f.lootStatus:SetHeight(20)
    --f.lootStatus:SetWidth(75)
    --f.lootStatus:SetPoint("LEFT", f.cancel, "RIGHT", 13, 1)
    --f.lootStatus:SetScript("OnLeave", UI.HideTooltip)
    --f.lootStatus.text:SetJustifyH("LEFT")

    local st = ST:CreateST(self.scrollCols, 5, ROW_HEIGHT, nil, f.content)
    st.frame:SetPoint("TOPLEFT",f,"TOPLEFT",10,-20)
    st:RegisterEvents({
        ["OnClick"] = function(_, _, _, _, row, realrow)
            if not (row or realrow) then
                return true
            end
        end
    })
    f:SetWidth(st.frame:GetWidth()+20)
    f:SetHeight(305)
    f.rows = {}
    f.st = st

    return f
end