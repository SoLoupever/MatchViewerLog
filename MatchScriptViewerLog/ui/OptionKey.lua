local addonName, ns = ...

-- ====================================================
-- OPTIONKEY — controle d'options (injecte dans le panneau Options de
-- MVL) pour choisir la touche qui declenche l'action du script en
-- combat. Clic = ecoute la prochaine touche pressee. Ecrit
-- ns.DB.settings.key et diffuse MSVL_KEY_CHANGED (le BattleButton se
-- rebranche). Aucun systeme parallele : on passe par le point
-- d'extension RegisterOptionControl de MVL.
-- ====================================================

ns.RegisterModule("OptionKey", {})

local DEFAULT_KEY = "A"
-- Modificateurs seuls : on attend la vraie touche (on ne les capture pas).
local IGNORE = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}

local frame, keyBtn, listening

local function CurrentKey()
    return (ns.DB and ns.DB.settings and ns.DB.settings.key) or DEFAULT_KEY
end

local function ShowKey()
    if not keyBtn then return end
    keyBtn.fs:SetText(listening and ns.L("OPTKEY_PRESS") or CurrentKey())
    keyBtn:SetBackdropBorderColor(listening and 1 or 0.4, listening and 0.82 or 0.3, listening and 0 or 0.55, 1)
end

local function StopListening()
    listening = false
    if keyBtn then
        keyBtn:EnableKeyboard(false)
        keyBtn:SetPropagateKeyboardInput(true)
    end
    ShowKey()
end

local function SetKey(key)
    if not (ns.DB and ns.DB.settings) then return end
    ns.DB.settings.key = key
    ns.Fire("MSVL_KEY_CHANGED")
end

local function Build(parent)
    if frame then return frame end
    frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(44)

    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 2, 0); lbl:SetText(ns.L("OPTKEY_LABEL"))

    keyBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    keyBtn:SetHeight(22)
    keyBtn:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    keyBtn:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    keyBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    keyBtn:SetBackdropColor(0.12, 0.12, 0.16, 1)
    -- Etat de repos : aucune capture clavier (Echap doit fermer la fenetre).
    keyBtn:EnableKeyboard(false)
    keyBtn:SetPropagateKeyboardInput(true)
    keyBtn.fs = keyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keyBtn.fs:SetPoint("CENTER")

    keyBtn:SetScript("OnClick", function(self)
        if listening then StopListening(); return end
        listening = true
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)
        ShowKey()
    end)
    keyBtn:SetScript("OnKeyDown", function(self, key)
        if not listening then self:SetPropagateKeyboardInput(true); return end
        if key == "ESCAPE" then
            -- Annule l'ecoute ET laisse Echap fermer la fenetre (propage).
            self:SetPropagateKeyboardInput(true)
            listening = false
            ShowKey()
            C_Timer.After(0, function() if keyBtn then keyBtn:EnableKeyboard(false) end end)
            return
        end
        if IGNORE[key] then return end
        -- Ordre des modificateurs attendu par les liaisons WoW : ALT-CTRL-SHIFT-.
        local combo = ""
        if IsAltKeyDown() then combo = combo .. "ALT-" end
        if IsControlKeyDown() then combo = combo .. "CTRL-" end
        if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
        SetKey(combo .. key)
        StopListening()
    end)
    keyBtn:SetScript("OnHide", function() if listening then StopListening() end end)
    keyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L("OPTKEY_LABEL"), 0.8, 0.5, 1)
        GameTooltip:AddLine(ns.L("OPTKEY_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    keyBtn:SetScript("OnLeave", GameTooltip_Hide)

    ShowKey()
    return frame
end

-- Enregistrement dans le panneau Options de MVL (point d'extension existant).
if ns.MVL and ns.MVL.RegisterOptionControl then
    ns.MVL.RegisterOptionControl({ build = Build, sync = ShowKey })
end
