local addonName, ns = ...

-- ====================================================
-- BOTTOMBAR — barre du bas : Invoquer / Discord / Enregistrer / Remplacer /
-- Trouver un combat, en une rangee pleine largeur (maquette).
-- ====================================================

ns.RegisterModule("BottomBar", {})

local built

local COL = ns.Style.COL
local H = 22

-- Bouton plat : fond sombre, contour dore discret, texte creme.
local function MakeButton(parent, label)
    return ns.Style.Button(parent, label, 100, H, {
        bg = COL.bg, border = COL.edge, text = { 0.93, 0.90, 0.80 }, font = "GameFontNormal",
    })
end

local function Build()
    if built then return end
    local frame = ns.Frame and ns.Frame.frame
    if not frame then return end
    built = true

    local invoke = MakeButton(frame, ns.L("BTN_SUMMON"))
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

    local discord = MakeButton(frame, ns.L("BTN_DISCORD"))
    discord:SetScript("OnClick", function()
        if ns.DiscordDialog then ns.DiscordDialog.Open() end
    end)

    local save = MakeButton(frame, ns.L("BTN_SAVE"))
    save:SetScript("OnClick", function()
        if ns.Teams and ns.Teams.HasPets() and ns.TeamDialog then ns.TeamDialog.OpenSave() end
    end)

    local replace = MakeButton(frame, ns.L("BTN_REPLACE"))
    replace:SetScript("OnClick", function() if ns.Teams then ns.Teams.Replace() end end)

    local find = MakeButton(frame, ns.L("BTN_FIND_BATTLE"))
    find:SetPoint("BOTTOMRIGHT", -12, 8)
    find:SetScript("OnClick", function()
        if C_PetBattles and C_PetBattles.StartPVPMatchmaking then C_PetBattles.StartPVPMatchmaking() end
    end)

    -- Les 5 boutons se partagent la largeur a parts egales.
    local group = { invoke, discord, save, replace, find }
    local GAP = 6
    local function Layout()
        local w = (frame:GetWidth() - 24 - GAP * (#group - 1)) / #group
        if w < 40 then return end
        local prev
        for _, b in ipairs(group) do
            b:SetWidth(w)
            if prev then b:ClearAllPoints(); b:SetPoint("LEFT", prev, "RIGHT", GAP, 0) end
            prev = b
        end
    end
    frame:HookScript("OnSizeChanged", Layout)
    Layout()
end

ns.On("MVL_FRAME_READY", Build)
