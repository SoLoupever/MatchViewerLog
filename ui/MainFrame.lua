local addonName, ns = ...

-- ====================================================
-- MAINFRAME — fenetre MatchViewerLog (code maison + textures
-- Blizzard). Sans portrait. Cree la fenetre, ses 3 colonnes et
-- expose ns.Frame + ns.EnsureFrame, puis diffuse MVL_FRAME_READY.
-- Le mode "prise en charge du journal" est gere par
-- hook/JournalTakeover.lua ; ce fichier ne fait que la fenetre.
-- ====================================================

ns.RegisterModule("MainFrame", {})

local WIDTH, HEIGHT = 886, 560
local frame

ns.Frame = ns.Frame or {}

local function Darken(inset)
    if not inset then return end
    local t = inset:CreateTexture(nil, "BACKGROUND", nil, 6)
    t:SetAllPoints(inset)
    t:SetColorTexture(0.04, 0.04, 0.05, 0.94)
end

local function Build()
    if frame then return frame end

    -- Si un compagnon a injecte des modes dans le panneau droit (ex:
    -- MatchScriptViewerLog), on elargit pour laisser respirer ses boutons.
    local extraModes = ns.rightPanelExtraModes and #ns.rightPanelExtraModes or 0
    local width = WIDTH + (extraModes > 0 and 170 or 0)

    frame = CreateFrame("Frame", "MatchViewerLogFrame", UIParent, "ButtonFrameTemplate")
    frame.__journalMode = true   -- toujours une surcouche du Codex (pas de mode autonome)
    frame:SetSize(width, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    -- Zone de drag = uniquement la barre du haut (pas toute la fenetre).
    -- Inset a droite pour laisser le CloseButton du template cliquable.
    local dragBar = CreateFrame("Frame", nil, frame)
    dragBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    dragBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -4)
    dragBar:SetHeight(18)
    dragBar:EnableMouse(true)
    dragBar:RegisterForDrag("LeftButton")
    -- Deplacement : en mode journal la fenetre est ancree a CollectionsJournal,
    -- on bouge donc le Codex (MVL suit). Hors journal, on bouge la fenetre.
    dragBar:SetScript("OnDragStart", function()
        if frame.__journalMode then
            if CollectionsJournal then
                CollectionsJournal:SetMovable(true)
                CollectionsJournal:SetClampedToScreen(true)
                CollectionsJournal:StartMoving()
            end
        else
            frame:StartMoving()
        end
    end)
    dragBar:SetScript("OnDragStop", function()
        if frame.__journalMode then
            if CollectionsJournal then CollectionsJournal:StopMovingOrSizing() end
        else
            frame:StopMovingOrSizing()
        end
    end)
    -- Pas dans UISpecialFrames : la fenetre est une SURCOUCHE du Codex (elle ne
    -- masque pas PetJournal). Echap ferme le Codex nativement, et notre fenetre
    -- suit via JournalTakeover (Update sur la visibilite de PetJournal).

    -- Sans portrait, sans l'inset interne du template (on a les notres).
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
    if frame.Inset then frame.Inset:Hide() end
    if frame.SetTitle then
        frame:SetTitle("|cff4da6ff" .. ns.L("ADDON_NAME") .. "|r |cffff40a0" .. ns.L("BY_AUTHOR") .. "|r")
    end

    -- Fermer : en mode journal on ferme la fenetre des collections.
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            if frame.__journalMode and CollectionsJournal then
                HideUIPanel(CollectionsJournal)
            else
                frame:Hide()
            end
        end)
    end

    -- Fond sombre general.
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 6, -22)
    bg:SetPoint("BOTTOMRIGHT", -6, 6)
    bg:SetColorTexture(0.03, 0.03, 0.04, 1)

    -- "Total Pets 1255".
    local totalBox = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    totalBox:SetSize(150, 20)
    totalBox:SetPoint("TOPLEFT", 10, -26)
    local totalFS = totalBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalFS:SetPoint("CENTER")
    frame.totalFS = totalFS

    -- "Uniques 900" : especes distinctes possedees, a droite du total.
    local uniqueBox = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    uniqueBox:SetSize(150, 20)
    uniqueBox:SetPoint("LEFT", totalBox, "RIGHT", 6, 0)
    local uniqueFS = uniqueBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    uniqueFS:SetPoint("CENTER")
    frame.uniqueFS = uniqueFS
    frame.uniqueBox = uniqueBox

    -- 3 colonnes.
    -- Largeurs rééquilibrées : gauche et centre plus fins pour laisser
    -- respirer la colonne de droite (teams), qui prend tout le reste.
    local left = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    left:SetPoint("TOPLEFT", 10, -52)
    left:SetPoint("BOTTOMLEFT", 10, 34)
    left:SetWidth(284)

    local center = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
    center:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 6, 0)
    center:SetWidth(236)

    local right = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    right:SetPoint("TOPLEFT", center, "TOPRIGHT", 6, 0)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -52)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 34)

    Darken(left); Darken(center); Darken(right)

    -- Hauts faits : au milieu de la rangee du haut (rempli par AchievementButton).
    local achievBox = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    achievBox:SetSize(64, 20)
    achievBox:SetPoint("TOP", frame, "TOP", 0, -26)
    frame.achievBox = achievBox

    -- Zone des boutons utilitaires : au-dessus du panneau droit.
    local util = CreateFrame("Frame", nil, frame)
    util:SetHeight(26)
    util:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 0, 2)
    util:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", 0, 2)
    frame.utilityAnchor = util

    ns.Frame.frame  = frame
    ns.Frame.left   = left
    ns.Frame.center = center
    ns.Frame.right  = right

    frame:HookScript("OnShow", function() ns.Fire("MVL_FRAME_SHOW") end)
    frame:HookScript("OnHide", function() ns.Fire("MVL_FRAME_HIDE") end)
    ns.Fire("MVL_FRAME_READY")
    frame:Hide()  -- masquee tant qu'on ne l'ouvre pas
    return frame
end

-- Construit (si besoin) et renvoie la fenetre.
function ns.EnsureFrame()
    return Build()
end

local function UpdateTotal()
    if not frame or not frame.totalFS then return end
    -- Un seul passage sur le journal : total possede (doublons compris) +
    -- especes distinctes possedees (aucune API dediee cote Blizzard).
    local numPets, numOwned = C_PetJournal.GetNumPets()
    frame.totalFS:SetText(ns.L("TOTAL_PETS") .. " |cffffffff" .. (numOwned or 0) .. "|r")
    if frame.uniqueFS then
        local seen, unique = {}, 0
        for i = 1, (numPets or 0) do
            local _, speciesID, isOwned = C_PetJournal.GetPetInfoByIndex(i)
            if isOwned and speciesID and not seen[speciesID] then
                seen[speciesID] = true
                unique = unique + 1
            end
        end
        frame.uniqueFS:SetText(ns.L("UNIQUE_PETS") .. " |cffffffff" .. unique .. "|r")
    end
end

ns.On("MVL_FRAME_SHOW", UpdateTotal)
