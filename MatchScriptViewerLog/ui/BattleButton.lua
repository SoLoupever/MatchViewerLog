local addonName, ns = ...

-- ====================================================
-- BATTLEBUTTON — bouton greffe dans l'interface de combat de
-- mascottes. Une pression = une etape (via Runner.ExecuteNext,
-- appele sur le clic materiel). La touche (defaut "A") est posee
-- en OVERRIDE uniquement pendant le combat, quand un script est
-- arme : hors combat, la touche garde son role normal (deplacement).
-- ====================================================

ns.RegisterModule("BattleButton", {})

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BTN_NAME = "MatchScriptViewerLogBattleButton"

local btn, icon, label, keyFS, stepFS
local battleActive = false

-- ClearOverrideBindings / SetOverrideBindingClick sont proteges : bloques sous
-- verrou de combat. On (re)pose la touche hors verrou ; sinon on marque un
-- rappel traite a la sortie de combat (PLAYER_REGEN_ENABLED).
local overridePending = false
local function ApplyOverride()
    if not btn then return end
    if InCombatLockdown() then overridePending = true; return end
    overridePending = false
    ClearOverrideBindings(btn)
    if battleActive and ns.Runner.IsArmed() then
        local key = (ns.DB and ns.DB.settings.key) or "A"
        SetOverrideBindingClick(btn, true, key, BTN_NAME, "LeftButton")
    end
end

local function Refresh()
    if not btn then return end
    if not battleActive then btn:Hide(); return end
    btn:Show()

    local key = (ns.DB and ns.DB.settings.key) or "A"
    keyFS:SetText(key)

    local info = ns.Runner.NextStepInfo()
    if ns.Runner.IsArmed() and info then
        btn:Enable()
        icon:SetDesaturated(false)
        icon:SetTexture(info.icon or FALLBACK_ICON)
        label:SetText(info.label or "")
        if info.i and info.n then
            stepFS:SetText((info.repeated and "» " or "") .. info.i .. "/" .. info.n)
        else
            stepFS:SetText("")   -- script "code" : pas de compteur d'etape
        end
    else
        btn:Disable()
        icon:SetDesaturated(true)
        icon:SetTexture(FALLBACK_ICON)
        label:SetText(ns.L("BTN_NO_SCRIPT"))
        stepFS:SetText("")
    end
    ApplyOverride()
end

-- Le bouton "Passer" (Skip) de Blizzard est sous TurnTimer, pas directement
-- sous BottomFrame (repli sur les deux noms au cas ou).
local function SkipBtn()
    local bf = PetBattleFrame and PetBattleFrame.BottomFrame
    if not bf then return nil end
    return (bf.TurnTimer and bf.TurnTimer.SkipButton) or bf.SkipButton
end

local function Anchor()
    btn:ClearAllPoints()
    local skip = SkipBtn()
    if skip then
        -- A droite du bouton "Passer", meme hauteur que lui.
        local h = skip:GetHeight()
        if h and h > 0 then btn:SetHeight(h) end
        btn:SetPoint("LEFT", skip, "RIGHT", 6, 0)
    else
        local bf = PetBattleFrame and PetBattleFrame.BottomFrame
        if bf then
            btn:SetPoint("BOTTOM", bf, "TOP", 0, 6)
        else
            btn:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
        end
    end
end

local function Build()
    if btn then return end
    btn = CreateFrame("Button", BTN_NAME, UIParent, "BackdropTemplate")
    btn:SetSize(150, 22)   -- hauteur ajustee sur "Passer" dans Anchor
    btn:SetFrameStrata("FULLSCREEN_DIALOG")
    btn:SetToplevel(true)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    btn:SetBackdropColor(0.08, 0.06, 0.12, 0.95)
    btn:SetBackdropBorderColor(0.63, 0.38, 1, 1)

    -- Disposition sur une seule rangee (tient dans la hauteur de "Passer") :
    -- icone | libelle | etape (i/n) | touche.
    icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    keyFS = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    keyFS:SetPoint("RIGHT", -5, 0)

    stepFS = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stepFS:SetPoint("RIGHT", keyFS, "LEFT", -5, 0)

    label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    label:SetPoint("RIGHT", stepFS, "LEFT", -4, 0)
    label:SetJustifyH("LEFT"); label:SetWordWrap(false)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        ns.Runner.ExecuteNext()   -- appel materiel : action protegee autorisee
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns.L("BTN_TOOLTIP_TITLE"), 0.8, 0.5, 1)
        GameTooltip:AddLine(ns.L("BTN_TOOLTIP_LEFT"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    btn:Hide()
end

Build()

ns.RegisterWowEvent("PET_BATTLE_OPENING_START", function()
    battleActive = true
    Anchor()
    Refresh()
end)
ns.RegisterWowEvent("PET_BATTLE_OPENING_DONE", function()
    battleActive = true
    Anchor()
    Refresh()
end)
ns.RegisterWowEvent("PET_BATTLE_CLOSE", function()
    battleActive = false
    if btn then btn:Hide() end
    ApplyOverride()   -- retire la touche (differe si encore en verrou)
end)

-- Sortie de verrou : traite la pose/retrait de touche mise en attente.
ns.RegisterWowEvent("PLAYER_REGEN_ENABLED", function()
    if overridePending then ApplyOverride() end
end)

ns.On("MSVL_RUNNER_CHANGED", Refresh)
ns.On("MSVL_KEY_CHANGED", Refresh)
