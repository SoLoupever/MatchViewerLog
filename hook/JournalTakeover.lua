local addonName, ns = ...

-- ====================================================
-- JOURNALTAKEOVER — superpose la fenetre MatchViewerLog PAR-DESSUS le journal
-- Blizzard (approche PetMatch), sans JAMAIS masquer PetJournal ni toucher a
-- l'ouverture/fermeture du Codex.
--
-- Notre fenetre est un ENFANT de PetJournal : sa visibilite suit donc
-- AUTOMATIQUEMENT celle du Codex (onglet mascotte actif). Aucun Show/Hide
-- differe : c'est ce qui evitait naguere le flash d'une image du Codex Blizzard
-- avant l'apparition de la surcouche. Maj+P natif marche du premier coup, Echap
-- ferme le Codex normalement, et changer d'onglet cache/affiche la surcouche
-- sans effet de bord.
-- ====================================================

ns.RegisterModule("JournalTakeover", {})

local EXTRA_RIGHT = 90   -- la colonne teams deborde a droite du Codex
local COVER = 6          -- recouvre le cadre recolore par un skin (Elsmere)

local installed = false

-- Ancre + affiche notre fenetre une seule fois, dans un contexte sur (hors pile
-- securisee du gestionnaire de panneaux) : ensuite la visibilite suit le parent.
local function Install()
    if installed or not (PetJournal and CollectionsJournal) then return end

    local f = ns.EnsureFrame()
    if not f then return end
    installed = true

    -- Enfant de PetJournal (visible seulement sur l'onglet mascotte), ancree sur
    -- le cadre exterieur pour la position/taille, au-dessus du contenu Blizzard.
    f:SetParent(PetJournal)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT",     CollectionsJournal, "TOPLEFT",     -COVER, COVER)
    f:SetPoint("BOTTOMRIGHT", CollectionsJournal, "BOTTOMRIGHT", EXTRA_RIGHT, -COVER)
    f:SetFrameStrata(CollectionsJournal:GetFrameStrata())
    f:SetFrameLevel(CollectionsJournal:GetFrameLevel() + 600)
    f.__journalMode = true

    -- Affichee une seule fois : la visibilite effective suit desormais PetJournal.
    f:Show()
end

if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_Collections") and _G.PetJournal then
    C_Timer.After(0, Install)
else
    ns.RegisterWowEvent("ADDON_LOADED", function(loaded)
        if loaded == "Blizzard_Collections" then C_Timer.After(0, Install) end
    end)
end
