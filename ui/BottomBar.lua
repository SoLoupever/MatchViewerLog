local addonName, ns = ...

-- ====================================================
-- BOTTOMBAR — barre du bas : Invoquer / Discord / Enregistrer / Remplacer /
-- Trouver un combat. Actions branchees progressivement ; pour
-- l'instant elles diffusent un event (sauf Trouver un combat et Discord).
-- ====================================================

ns.RegisterModule("BottomBar", {})

local built

-- Style du bouton "Equipes scriptees" du panneau droit : fond + contour
-- violet, texte clair, contour jaune au survol.
local function MakeButton(parent, label, w)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0.16, 0.10, 0.22, 1)
    b:SetBackdropBorderColor(0.55, 0.35, 0.85, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER"); b.text:SetText(label)
    -- SetText compatible avec le code appelant (bascule Invoquer/Renvoyer).
    b.SetText = function(self, t) self.text:SetText(t) end
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.55, 0.35, 0.85, 1) end)
    return b
end

local function Build()
    if built then return end
    local frame = ns.Frame and ns.Frame.frame
    if not frame then return end
    built = true

    local invoke = MakeButton(frame, ns.L("BTN_SUMMON"), 110)
    invoke:SetPoint("BOTTOMLEFT", 12, 8)
    local function UpdateSummon()
        local summoned = C_PetJournal.GetSummonedPetGUID and C_PetJournal.GetSummonedPetGUID()
        invoke:SetText(summoned and ns.L("BTN_DISMISS") or ns.L("BTN_SUMMON"))
    end
    invoke:SetScript("OnClick", function()
        local summoned = C_PetJournal.GetSummonedPetGUID and C_PetJournal.GetSummonedPetGUID()
        if summoned then
            C_PetJournal.SummonPetByGUID(summoned)          -- renvoie la mascotte active
        elseif ns.selectedPetID then
            C_PetJournal.SummonPetByGUID(ns.selectedPetID)  -- invoque la selectionnee
        end
        C_Timer.After(0.1, UpdateSummon)
    end)
    ns.RegisterWowEvent("COMPANION_UPDATE", UpdateSummon)
    ns.On("MVL_FRAME_SHOW", UpdateSummon)
    ns.On("PET_SELECTED", UpdateSummon)
    UpdateSummon()

    local discord = MakeButton(frame, ns.L("BTN_DISCORD"), 90)
    -- Centre pile sur la gouttiere de 6px entre le panneau gauche et le
    -- panneau du milieu (BOTTOMRIGHT de "left" + moitie de la gouttiere),
    -- aligne sur la meme ligne que les autres boutons du bas (meme ecart
    -- de 26px deja utilise entre le haut des panneaux et la rangee "Total/
    -- Uniques" : ici en miroir, entre le bas des panneaux et cette rangee).
    discord:SetPoint("BOTTOM", ns.Frame.left, "BOTTOMRIGHT", 3, -26)
    discord:SetScript("OnClick", function()
        if ns.DiscordDialog then ns.DiscordDialog.Open() end
    end)

    local find = MakeButton(frame, ns.L("BTN_FIND_BATTLE"), 150)
    find:SetPoint("BOTTOMRIGHT", -12, 8)
    find:SetScript("OnClick", function()
        if C_PetBattles and C_PetBattles.StartPVPMatchmaking then C_PetBattles.StartPVPMatchmaking() end
    end)

    local replace = MakeButton(frame, ns.L("BTN_REPLACE"), 110)
    replace:SetPoint("RIGHT", find, "LEFT", -6, 0)
    replace:SetScript("OnClick", function() if ns.Teams then ns.Teams.Replace() end end)

    local save = MakeButton(frame, ns.L("BTN_SAVE"), 110)
    save:SetPoint("RIGHT", replace, "LEFT", -6, 0)
    save:SetScript("OnClick", function()
        if ns.Teams and ns.Teams.HasPets() and ns.TeamDialog then ns.TeamDialog.OpenSave() end
    end)
end

ns.On("MVL_FRAME_READY", Build)
