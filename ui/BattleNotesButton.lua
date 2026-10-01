local addonName, ns = ...

-- ====================================================
-- BATTLENOTESBUTTON — bouton "Notes de la team" dans l'interface de combat
-- de mascottes. Ouvre NotesDialog (equipe chargee). Ancre a droite du
-- bouton script du compagnon s'il est present (trouve par son nom de frame,
-- aucun appel a son code), sinon a droite du bouton "Passer" de Blizzard.
-- Bouton non securise : utilisable en combat.
-- ====================================================

ns.RegisterModule("BattleNotesButton", {})

local ICON = "Interface\\Icons\\INV_Icon_Daily_Mission_Scroll"
local SCRIPT_BTN = "MatchScriptViewerLogBattleButton"
local BTN_NAME   = "MatchViewerLogBattleNotesButton"

local btn, icon
local active = false

local function CurrentNotes()
    local id = ns.Teams and ns.Teams.current.sourceTeamID
    return (id and ns.Teams.GetNotes(id)) or ""
end

-- Grise l'icone quand la team n'a pas de notes.
local function Refresh()
    if not (btn and active) then return end
    icon:SetDesaturated(CurrentNotes() == "")
end

local function SkipBtn()
    local bf = PetBattleFrame and PetBattleFrame.BottomFrame
    if not bf then return nil end
    return (bf.TurnTimer and bf.TurnTimer.SkipButton) or bf.SkipButton
end

local hooked
local Anchor
Anchor = function()
    btn:ClearAllPoints()
    local skip = SkipBtn()
    local h = skip and skip:GetHeight()
    if h and h > 0 then btn:SetSize(h, h) end
    local script = _G[SCRIPT_BTN]
    -- Le bouton script re-pose ses ancres a chaque combat : on se recale
    -- quand il s'affiche (une seule fois le hook).
    if script and not hooked then
        hooked = true
        script:HookScript("OnShow", function() if active then Anchor() end end)
    end
    local ref = script or skip
    if ref then
        btn:SetPoint("LEFT", ref, "RIGHT", 6, 0)
    else
        local bf = PetBattleFrame and PetBattleFrame.BottomFrame
        if bf then btn:SetPoint("BOTTOM", bf, "TOP", 0, 6)
        else btn:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200) end
    end
end

local function Build()
    if btn then return end
    btn = CreateFrame("Button", BTN_NAME, UIParent, "BackdropTemplate")
    btn:SetSize(22, 22)
    btn:SetFrameStrata("FULLSCREEN_DIALOG")
    btn:SetToplevel(true)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    btn:SetBackdropColor(0.08, 0.06, 0.12, 0.95)
    btn:SetBackdropBorderColor(0.63, 0.38, 1, 1)

    icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2); icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); icon:SetTexture(ICON)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.2)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function() if ns.NotesDialog then ns.NotesDialog.Toggle() end end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns.L("NOTES_BTN_TIP"), 1, 1, 1)
        local notes = CurrentNotes()
        if notes ~= "" then GameTooltip:AddLine(notes:sub(1, 400), 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:Hide()
end

local function OnBattleStart()
    active = true
    Build()
    Anchor()
    btn:Show()
    Refresh()
    -- Recale apres les handlers du meme event (le bouton script s'ancre apres nous).
    C_Timer.After(0, function() if active and btn then Anchor() end end)
end

ns.RegisterWowEvent("PET_BATTLE_OPENING_START", OnBattleStart)
ns.RegisterWowEvent("PET_BATTLE_OPENING_DONE", OnBattleStart)
ns.RegisterWowEvent("PET_BATTLE_CLOSE", function()
    active = false
    if btn then btn:Hide() end
end)
ns.On("TEAM_LOADED", Refresh)
ns.On("TEAM_NOTES_CHANGED", Refresh)
