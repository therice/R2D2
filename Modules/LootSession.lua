local _, AddOn = ...
local LootSession   = AddOn:NewModule("LootSession", "AceEvent-3.0", "AceTimer-3.0")
local ML            = AddOn:GetModule("MasterLooter")
local L             = AddOn.components.Locale
local Logging       = AddOn.components.Logging
local UI            = AddOn.components.UI
local ST            = AddOn.Libs.ScrollingTable

local ROW_HEIGHT = 40
local sessionActive = false
local loadingItems = false

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
    self:Show({})
end

function LootSession:OnDisable()
    Logging:Debug("OnDisable(%s)", self:GetName())
    self.frame:Hide()
    self.frame.rows = {}
end

function LootSession:Show(data)
    -- don't show another window if a session is active
    if sessionActive then return end

    self.frame = self:GetFrame()
    self.frame:Show()

    if data then
        loadingItems = false
        -- todo : sorting?
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
    for k,v in ipairs(data) do
        -- Don't add items we've already started a session with
        if not v.transmitted then
            -- no bonus text for classic
            tinsert(self.frame.rows, {
                session = k,
                texture = v.texture or nil,
                link = v.link,
                owner = v.owner,
                cols = {
                    { DoCellUpdate = self.SetCellDeleteBtn},
                    { DoCellUpdate = self.SetCellItemIcon},
                    { value = " "..v.ilvl},
                    { DoCellUpdate = self.SetCellText },
                },
            })
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

function LootSession:GetFrame()
    if self.frame then return self.frame end
    local f = UI:CreateFrame("R2D2_LootSession", "LootSession", L["r2d2_loot_session_frame"], 260)

    -- start button
    local start = UI:CreateButton(_G.START, f.content)
    start:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    f.startBtn = start

    -- Cancel button
    local cancel = UI:CreateButton(_G.CANCEL, f.content)
    cancel:SetPoint("LEFT", start, "RIGHT", 15, 0)
    cancel:SetScript("OnClick", function()
        ML.lootTable = {}
        self:Disable()
    end)
    f.closeBtn = cancel

    f.lootStatus = UI:New("Text", f.content, " ")
    f.lootStatus:SetTextColor(1,1,1,1) -- White for now
    f.lootStatus:SetHeight(20)
    f.lootStatus:SetWidth(75)
    f.lootStatus:SetPoint("LEFT", f.closeBtn, "RIGHT", 13, 1)
    f.lootStatus:SetScript("OnLeave", UI.HideTooltip)
    f.lootStatus.text:SetJustifyH("LEFT")

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