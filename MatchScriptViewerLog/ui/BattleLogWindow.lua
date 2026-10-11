local addonName, ns = ...

-- ====================================================
-- BATTLELOGWINDOW — fenetre qui s'ouvre pendant un combat enregistre :
-- journal en direct, puis proposition de conversion en script a la fin.
-- Deplacable par la barre du haut uniquement.
-- ====================================================

ns.RegisterModule("BattleLogWindow", {})

local W, H = 360, 440
local PAD = 10
local dlg, session

local function Build()
    if dlg then return end
    dlg = CreateFrame("Frame", "MatchScriptViewerLogBattleLog", UIParent, "BackdropTemplate")
    dlg:SetSize(W, H)
    dlg:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
    dlg:SetFrameStrata("HIGH"); dlg:SetToplevel(true)
    dlg:SetMovable(true); dlg:SetClampedToScreen(true); dlg:EnableMouse(true)
    dlg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.96); dlg:SetBackdropBorderColor(0.63, 0.38, 1, 1)

    local bar = CreateFrame("Frame", nil, dlg)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(26)
    bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() dlg:StartMoving() end)
    bar:SetScript("OnDragStop", function() dlg:StopMovingOrSizing() end)

    dlg.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("LEFT", PAD, 0)
    dlg.title:SetText(ns.L("REC_WIN_TITLE"))

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local log = CreateFrame("ScrollingMessageFrame", nil, dlg)
    log:SetPoint("TOPLEFT", PAD, -32)
    log:SetPoint("BOTTOMRIGHT", -PAD, 78)
    log:SetFontObject(ChatFontNormal)
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(1000)
    log:SetIndentedWordWrap(true)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    dlg.log = log

    -- Zone de proposition (visible a la fin du combat).
    local ask = CreateFrame("Frame", nil, dlg)
    ask:SetPoint("BOTTOMLEFT", PAD, 8); ask:SetPoint("BOTTOMRIGHT", -PAD, 8)
    ask:SetHeight(64)
    dlg.ask = ask

    ask.text = ask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ask.text:SetPoint("TOPLEFT"); ask.text:SetPoint("TOPRIGHT")
    ask.text:SetJustifyH("LEFT"); ask.text:SetWordWrap(true)

    ask.convert = ns.Widgets.SmallBtn(ask, 110, "")
    ask.convert:SetPoint("BOTTOMLEFT", 0, 0)
    ask.convert:SetBackdropColor(0.10, 0.20, 0.14, 1); ask.convert:SetBackdropBorderColor(0.35, 0.7, 0.45, 1)

    ask.dismiss = ns.Widgets.SmallBtn(ask, 90, ns.L("REC_DISMISS"))
    ask.dismiss:SetPoint("LEFT", ask.convert, "RIGHT", 6, 0)

    ask.dismiss:SetScript("OnClick", function() ask:Hide() end)
    ask.convert:SetScript("OnClick", function()
        local ok, err = ns.Recorder.Convert(session)
        if ok then
            ask.text:SetText("|cff40ff40" .. ns.L("REC_CONVERTED"):format(ns.MVL.GetTeam(session.teamID).name, #session.actions) .. "|r")
        else
            ask.text:SetText("|cffff6060" .. ns.L("REC_CONVERT_ERR"):format(err or ns.L("CODE_ERROR")) .. "|r")
        end
        ask.convert:Hide(); ask.dismiss:Hide()
    end)
    ask:Hide()
    dlg:Hide()
end

local function ShowAsk(s)
    local ask = dlg.ask
    local team = s.teamID and ns.MVL.GetTeam(s.teamID)
    ask.convert:Show(); ask.dismiss:Show()

    if not team then
        ask.text:SetText("|cffff8080" .. ns.L("REC_NO_TEAM") .. "|r")
        ask.convert:Hide()
    elseif #s.actions == 0 then
        ask.text:SetText("|cffff8080" .. ns.L("REC_NO_ACTION") .. "|r")
        ask.convert:Hide()
    else
        local replace = ns.Scripts.Has(s.teamID)
        ask.text:SetText(ns.L(replace and "REC_ASK_REPLACE" or "REC_ASK"):format(team.name))
        ask.convert.text:SetText(ns.L(replace and "REC_REPLACE" or "REC_CONVERT"))
    end
    ask:Show()
end

ns.On("MSVL_RECORD_START", function(s)
    Build()
    session = s
    dlg.log:Clear()
    dlg.ask:Hide()
    dlg:Show()
end)

ns.On("MSVL_LOG_LINE", function(text)
    if dlg and dlg:IsShown() then dlg.log:AddMessage(text) end
end)

ns.On("MSVL_RECORD_END", function(s)
    if not dlg then return end
    session = s
    ShowAsk(s)
    dlg:Show()
end)

-- Desarmer en plein combat : on ferme la fenetre du journal en direct.
ns.On("MSVL_RECORD_STATE", function(on)
    if on or not dlg or dlg.ask:IsShown() then return end
    dlg:Hide()
end)
