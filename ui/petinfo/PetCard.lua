local addonName, ns = ...

-- ====================================================
-- PETCARD — carte d'une mascotte (colonne gauche) : rendu 3D, nom,
-- type, niveau, stats PvP, breed, breeds possibles, collecte, et les
-- 6 sorts (infobulle au survol). Reste ouverte quand la mascotte est
-- selectionnee ; sinon s'affiche au survol et se ferme a la sortie.
-- ====================================================

ns.RegisterModule("PetCard", {})
local PetCard = ns.PetCard or {}
ns.PetCard = PetCard

local card

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function PossibleBreeds(speciesID)
    if not BPBID_Arrays or not BPBID_Arrays.BreedsPerSpecies then return nil end
    local list = BPBID_Arrays.BreedsPerSpecies[speciesID]
    if not list then return nil end
    local names = {}
    for _, bid in ipairs(list) do names[#names + 1] = ns.BREED_NAMES[bid] or tostring(bid) end
    return names
end

local collectedCache = {}
local function CollectedBreeds(speciesID)
    if collectedCache[speciesID] then return collectedCache[speciesID] end
    local breeds, total = {}, 0
    local num = C_PetJournal.GetNumPets() or 0
    for i = 1, num do
        local pid, sp = C_PetJournal.GetPetInfoByIndex(i)
        if sp == speciesID and pid then
            total = total + 1
            local b = ns.Breed and ns.Breed.GetForPetID(pid)
            if b then breeds[b] = (breeds[b] or 0) + 1 end
        end
    end
    collectedCache[speciesID] = { breeds = breeds, total = total }
    return collectedCache[speciesID]
end

local function EnsureCard()
    if card then return card end
    card = CreateFrame("Frame", "MatchViewerLogPetCard", UIParent, "BackdropTemplate")
    card:SetFrameStrata("TOOLTIP")
    card:SetWidth(240)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    card:SetBackdropColor(0.03, 0.03, 0.05, 0.98); card:SetBackdropBorderColor(0.5, 0.42, 0.12, 1)

    card.model = CreateFrame("PlayerModel", nil, card)
    card.model:SetSize(84, 84); card.model:SetPoint("TOPLEFT", 10, -10)

    -- Pastille "deja dans une team" : coin bas-droit du modele, au-dessus de lui.
    card.team = ns.PetTeamBadge.Create(card, 18, "ANCHOR_RIGHT")
    card.team:SetPoint("BOTTOMRIGHT", card.model, "BOTTOMRIGHT", -2, 2)
    card.team:SetFrameLevel(card.model:GetFrameLevel() + 5)

    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card.model, "TOPRIGHT", 8, -2)
    card.name:SetJustifyH("LEFT"); card.name:SetWordWrap(true)

    card.typeIcon = card:CreateTexture(nil, "OVERLAY")
    card.typeIcon:SetSize(22, 22); card.typeIcon:SetPoint("TOPRIGHT", -48, -8)
    -- Nom borne a gauche de l'icone de type : il ne passe plus sous le type/niveau.
    card.name:SetPoint("RIGHT", card.typeIcon, "LEFT", -6, 0)

    -- Bouton fermer (visible seulement en mode epingle/selection).
    card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    card.close:SetSize(26, 26); card.close:SetPoint("TOPRIGHT", 2, 2)
    card.close:SetScript("OnClick", function() card.closed = true; card:Hide() end)
    card.close:Hide()

    -- Niveau : a droite de l'icone de type, en jaune.
    card.level = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.level:SetPoint("LEFT", card.typeIcon, "RIGHT", 4, 0)

    card.body = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.body:SetPoint("TOPLEFT", card.model, "BOTTOMLEFT", 0, -8)
    card.body:SetPoint("RIGHT", -10, 0); card.body:SetJustifyH("LEFT"); card.body:SetSpacing(2)

    -- 6 sorts (2 rangees de 3), cliquables/survolables.
    card.abil = {}
    for a = 1, 6 do
        local b = CreateFrame("Button", nil, card)
        b:SetSize(26, 26)
        b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.3)
        -- Sort verrouille (niveau de la mascotte insuffisant) : cadenas + niveau requis.
        b.lock = b:CreateTexture(nil, "OVERLAY")
        b.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
        b.lock:SetSize(18, 18); b.lock:SetPoint("CENTER"); b.lock:Hide()
        b.req = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.req:SetPoint("BOTTOMRIGHT", 1, 0); b.req:SetTextColor(1, 0.2, 0.2); b.req:Hide()
        b:SetScript("OnEnter", function(self)
            if self.abilityID and PetJournal_ShowAbilityTooltip then
                -- Toujours ancree a droite du 3e sort de la 1re ligne.
                local anchor = (card.abil[3] and card.abil[3]:IsShown()) and card.abil[3] or self
                PetJournal_ShowAbilityTooltip(anchor, self.abilityID, card.speciesID, card.petID)
            end
        end)
        b:SetScript("OnLeave", function()
            if PetJournalPrimaryAbilityTooltip then PetJournalPrimaryAbilityTooltip:Hide() end
        end)
        card.abil[a] = b
    end
    return card
end

local function Fill(anchor, petID)
    -- Mascotte prise au curseur (drag vers un slot) : la carte gene, on la masque.
    if GetCursorInfo() == "battlepet" then PetCard.Hide(); return end
    local speciesID, customName, level, _, _, displayID, _, name, _, petType = C_PetJournal.GetPetInfoByPetID(petID)
    if not name then return end
    EnsureCard()
    card.speciesID, card.petID = speciesID, petID
    card.team:SetPetID(petID)

    if displayID and displayID > 0 then card.model:SetDisplayInfo(displayID); card.model:Show()
    else card.model:Hide() end

    local _, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID)
    local q = rarity and ITEM_QUALITY_COLORS[rarity - 1]
    card.name:SetText(customName or name)
    if q then card.name:SetTextColor(q.r, q.g, q.b) else card.name:SetTextColor(1, 1, 1) end
    if petType and GetPetTypeTexture then
        card.typeIcon:SetTexture(GetPetTypeTexture(petType))
        card.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625); card.typeIcon:Show()
    else
        card.typeIcon:Hide()
    end
    card.level:SetText(level and ("|cffffd200" .. level .. "|r") or "")

    -- Corps : stats (toujours), breed, breeds possibles, collecte.
    local L = {}
    local breed = ns.Breed and ns.Breed.GetForPetID(petID)
    L[#L + 1] = Hex(1, 0.82, 0) .. ns.L("CARD_ATTACK") .. "|r " .. (attack or "?")
        .. "   " .. Hex(1, 0.82, 0) .. ns.L("CARD_SPEED") .. "|r " .. (speed or "?")
        .. "   " .. Hex(1, 0.82, 0) .. ns.L("CARD_HEALTH") .. "|r " .. (maxHealth or "?")
    local qname = rarity and _G["ITEM_QUALITY" .. (rarity - 1) .. "_DESC"] or "?"
    local qhex = q and Hex(q.r, q.g, q.b) or "|cffffffff"
    L[#L + 1] = Hex(1, 0.82, 0) .. ns.L("CARD_QUALITY") .. "|r " .. qhex .. qname .. "|r"
        .. "   " .. Hex(1, 0.82, 0) .. ns.L("CARD_BREED") .. "|r " .. (breed or "?")
    local poss = PossibleBreeds(speciesID)
    if poss then L[#L + 1] = Hex(1, 0.82, 0) .. ns.L("CARD_POSSIBLE_BREEDS") .. "|r " .. table.concat(poss, ", ") end
    local col = CollectedBreeds(speciesID)
    if col then
        local parts = {}
        for b, n in pairs(col.breeds) do parts[#parts + 1] = b .. (n > 1 and (" x" .. n) or "") end
        local detail = #parts > 0 and ("  (" .. table.concat(parts, ", ") .. ")") or ""
        L[#L + 1] = Hex(1, 0.82, 0) .. ns.L("CARD_COLLECTED") .. "|r " .. col.total .. detail
    end
    card.body:SetText(table.concat(L, "\n"))

    -- 6 sorts (levelList = niveau de deblocage de chaque sort, donnee du jeu).
    local abilList, levelList = C_PetJournal.GetPetAbilityList(speciesID)
    local bodyBottom = 10 + 84 + 8 + (card.body:GetStringHeight() or 0)
    local base = bodyBottom + 8
    for a = 1, 6 do
        local aid = abilList and abilList[a]
        local b = card.abil[a]
        b:ClearAllPoints()
        local rowi, coli = math.floor((a - 1) / 3), (a - 1) % 3
        b:SetPoint("TOPLEFT", 10 + coli * 30, -(base + rowi * 30))
        if aid then
            b.abilityID = aid
            b.tex:SetTexture(select(2, C_PetJournal.GetPetAbilityInfo(aid)))
            local req = levelList and levelList[a]
            local locked = req and level and level < req
            b.tex:SetDesaturated(locked and true or false)
            if locked then
                b.lock:Show(); b.req:SetText(req); b.req:Show()
            else
                b.lock:Hide(); b.req:Hide()
            end
            b:Show()
        else
            b.abilityID = nil; b:Hide()
        end
    end
    card:SetHeight(base + 2 * 30 + 8)

    -- Bouton fermer visible uniquement quand c'est la mascotte selectionnee.
    card.close:SetShown(petID == ns.selectedPetID)

    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 4)
    card:SetClampedToScreen(true)
    card:Show()
end

-- Variante ESPECE : mascotte NON possedee (pas de petID). Meme carte, lue par
-- speciesID, avec une mention "non possedee" et les sorts (grisees) + leur
-- niveau de deblocage. Pas de stats/breed (mascotte absente de la collection).
local function FillSpecies(anchor, speciesID)
    if GetCursorInfo() == "battlepet" then PetCard.Hide(); return end
    local name, _, petType, _, _, _, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    if not name then return end
    EnsureCard()
    card.speciesID, card.petID = speciesID, nil
    card.team:SetPetID(nil)

    if displayID and displayID > 0 then card.model:SetDisplayInfo(displayID); card.model:Show()
    else card.model:Hide() end

    card.name:SetText(name); card.name:SetTextColor(0.7, 0.7, 0.7)
    if petType and GetPetTypeTexture then
        card.typeIcon:SetTexture(GetPetTypeTexture(petType))
        card.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625); card.typeIcon:Show()
    else
        card.typeIcon:Hide()
    end
    card.level:SetText("")

    local L = { "|cffff6060" .. ns.L("CARD_NOT_OWNED") .. "|r" }
    local poss = PossibleBreeds(speciesID)
    if poss then L[#L + 1] = Hex(1, 0.82, 0) .. ns.L("CARD_POSSIBLE_BREEDS") .. "|r " .. table.concat(poss, ", ") end
    card.body:SetText(table.concat(L, "\n"))

    local abilList, levelList = C_PetJournal.GetPetAbilityList(speciesID)
    local base = 10 + 84 + 8 + (card.body:GetStringHeight() or 0) + 8
    for a = 1, 6 do
        local aid = abilList and abilList[a]
        local b = card.abil[a]
        b:ClearAllPoints()
        local rowi, coli = math.floor((a - 1) / 3), (a - 1) % 3
        b:SetPoint("TOPLEFT", 10 + coli * 30, -(base + rowi * 30))
        if aid then
            b.abilityID = aid
            b.tex:SetTexture(select(2, C_PetJournal.GetPetAbilityInfo(aid)))
            b.tex:SetDesaturated(true)
            b.lock:Hide()
            local req = levelList and levelList[a]
            if req then b.req:SetText(req); b.req:Show() else b.req:Hide() end
            b:Show()
        else
            b.abilityID = nil; b:Hide()
        end
    end
    card:SetHeight(base + 2 * 30 + 8)
    -- Bouton fermer visible quand cette espece est celle epinglee.
    card.close:SetShown(speciesID == ns.selectedSpecies)

    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 4)
    card:SetClampedToScreen(true)
    card:Show()
end

-- Survol.
function PetCard.ShowFor(anchor, petID)
    if type(petID) == "string" then Fill(anchor, petID) end
end

-- Survol d'une mascotte non possedee (par speciesID).
function PetCard.ShowForSpecies(anchor, speciesID)
    if type(speciesID) == "number" then FillSpecies(anchor, speciesID) end
end

-- Sortie de survol : revient a la mascotte selectionnee, sinon ferme.
-- Sortie de survol : revient a la mascotte selectionnee (mode epingle),
-- sauf si l'utilisateur a ferme la carte ; sinon ferme.
function PetCard.OnLeave()
    if not (card and card.closed) and ns.Frame and ns.Frame.left then
        if ns.selectedPetID then Fill(ns.Frame.left, ns.selectedPetID); return
        elseif ns.selectedSpecies then FillSpecies(ns.Frame.left, ns.selectedSpecies); return end
    end
    PetCard.Hide()
end

function PetCard.Hide()
    if card then card:Hide() end
end

-- La selection change : (re)ouvre en mode epingle.
ns.On("PET_SELECTED", function()
    if card then card.closed = false end
    if ns.selectedPetID and ns.Frame and ns.Frame.left then
        Fill(ns.Frame.left, ns.selectedPetID)
    elseif ns.selectedSpecies and ns.Frame and ns.Frame.left then
        FillSpecies(ns.Frame.left, ns.selectedSpecies)
    elseif card then
        card:Hide()
    end
end)

-- Fermeture du Codex : ferme la carte.
ns.On("MVL_FRAME_HIDE", function() PetCard.Hide() end)

-- Pendant un drag de mascotte (vers un slot du centre), la carte epinglee
-- recouvre le slot du haut : on la masque tant qu'une mascotte est au curseur,
-- puis on restaure l'epingle au lacher.
local dragHid = false
local function RestorePinned()
    if not (ns.Frame and ns.Frame.left) or (card and card.closed) then return end
    if ns.selectedPetID then Fill(ns.Frame.left, ns.selectedPetID)
    elseif ns.selectedSpecies then FillSpecies(ns.Frame.left, ns.selectedSpecies) end
end
ns.RegisterWowEvent("CURSOR_CHANGED", function()
    if GetCursorInfo() == "battlepet" then
        if card and card:IsShown() then card:Hide(); dragHid = true end
    elseif dragHid then
        dragHid = false
        RestorePinned()
    end
end)

ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", function() wipe(collectedCache) end)
