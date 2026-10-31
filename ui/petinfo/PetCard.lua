local addonName, ns = ...

-- ====================================================
-- PETCARD — carte d'une mascotte (colonne gauche) : nom, pastille
-- type/niveau, description (bouton livre), rendu 3D, qualite/breed,
-- stats, breeds possibles, collecte, source, et les 6 sorts en 2
-- colonnes (numero + icone + type). Reste ouverte quand la mascotte
-- est selectionnee ; sinon s'affiche au survol et se ferme a la sortie.
-- ====================================================

ns.RegisterModule("PetCard", {})
local PetCard = ns.PetCard or {}
ns.PetCard = PetCard

local Style = ns.Style
local COL = Style.COL

local W, PAD = 270, 10
local HEADER_Y, HEADER_H = 20, 24
local MID_H, PORTRAIT_W = 104, 96
local CELL_H, CELL_GAP = 32, 4
local CELL_W = (W - PAD * 2 - 6) / 2
local ROW_LABEL_W = 100
local DIM = "|cff9e9eab"

local card
local showDesc = false

local function Num(n)
    if not n then return "?" end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
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

local function SetTypeIcon(tex, petType)
    if petType and GetPetTypeTexture then
        tex:SetTexture(GetPetTypeTexture(petType))
        tex:SetTexCoord(unpack(Style.TYPE_COORDS))
        tex:Show()
    else
        tex:Hide()
    end
end

local function MakeSep(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1); t:SetColorTexture(unpack(COL.edge))
    return t
end

-- Ligne "libelle a gauche / valeur alignee a droite".
local function MakeRow(parent)
    local r = {}
    r.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.label:SetJustifyH("LEFT")
    r.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.value:SetJustifyH("RIGHT"); r.value:SetJustifyV("TOP"); r.value:SetWordWrap(true)
    r.value:SetWidth(W - PAD * 2 - ROW_LABEL_W)
    return r
end

local function MakeCell(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(CELL_W, CELL_H)
    Style.Paint(b, COL.card, COL.edge, true)

    local grp = CreateFrame("Frame", nil, b)
    grp:SetSize(68, 24); grp:SetPoint("CENTER")

    b.num = grp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.num:SetPoint("LEFT")
    b.tex = grp:CreateTexture(nil, "ARTWORK")
    b.tex:SetSize(24, 24); b.tex:SetPoint("LEFT", 14, 0); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Sort verrouille (niveau insuffisant) : cadenas + niveau requis.
    b.lock = grp:CreateTexture(nil, "OVERLAY")
    b.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    b.lock:SetSize(16, 16); b.lock:SetPoint("CENTER", b.tex); b.lock:Hide()
    b.req = grp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.req:SetPoint("BOTTOMRIGHT", b.tex, 1, 0); b.req:SetTextColor(1, 0.2, 0.2); b.req:Hide()
    b.type = grp:CreateTexture(nil, "ARTWORK")
    b.type:SetSize(20, 20); b.type:SetPoint("LEFT", b.tex, "RIGHT", 6, 0)

    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COL.gold))
        if self.abilityID and PetJournal_ShowAbilityTooltip then
            PetJournal_ShowAbilityTooltip(card, self.abilityID, card.speciesID, card.petID)
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self.baseBorder or COL.edge))
        if PetJournalPrimaryAbilityTooltip then PetJournalPrimaryAbilityTooltip:Hide() end
    end)
    return b
end

local Refresh   -- defini plus bas (le bouton description la rappelle)

local function EnsureCard()
    if card then return card end
    card = CreateFrame("Frame", "MatchViewerLogPetCard", UIParent, "BackdropTemplate")
    card:SetFrameStrata("TOOLTIP")
    card:SetWidth(W)
    Style.Paint(card, COL.bg, COL.border)

    -- En-tete : nom | pastille type+niveau | bouton description.
    card.book = Style.Button(card, "", HEADER_H, HEADER_H, {
        border = COL.border, hover = COL.gold, activeBg = Style.Tint(COL.gold, 0.2), activeBorder = COL.gold,
    })
    card.book:SetPoint("TOPRIGHT", -PAD, -HEADER_Y)
    card.book.icon = card.book:CreateTexture(nil, "ARTWORK")
    card.book.icon:SetSize(14, 14); card.book.icon:SetPoint("CENTER")
    card.book.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    card.book.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.book:SetScript("OnClick", function(self)
        showDesc = not showDesc
        self:SetActive(showDesc)
        Refresh()
    end)
    card.book:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L("CARD_DESC_TIP"), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    card.book:HookScript("OnLeave", function() GameTooltip:Hide() end)

    card.pill = CreateFrame("Frame", nil, card, "BackdropTemplate")
    card.pill:SetHeight(HEADER_H)
    Style.Paint(card.pill, COL.pill, COL.pillBd, true)
    card.pill:SetPoint("RIGHT", card.book, "LEFT", -6, 0)
    card.pill:EnableMouse(true)
    card.typeIcon = card.pill:CreateTexture(nil, "ARTWORK")
    card.typeIcon:SetSize(18, 18); card.typeIcon:SetPoint("LEFT", 4, 0)
    Style.Round(card.typeIcon, card.pill)
    card.level = card.pill:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.level:SetPoint("LEFT", card.typeIcon, "RIGHT", 5, 0)
    card.pill:SetScript("OnEnter", function(self)
        local n = self.petType and _G["BATTLE_PET_NAME_" .. self.petType]
        if not n then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(n, 1, 1, 1)
        GameTooltip:Show()
    end)
    card.pill:SetScript("OnLeave", function() GameTooltip:Hide() end)

    card.name = card:CreateFontString(nil, "OVERLAY", Style.TITLE_FONT)
    card.name:SetJustifyH("LEFT"); card.name:SetWordWrap(false)
    card.name:SetPoint("LEFT", card, "TOPLEFT", PAD, -(HEADER_Y + HEADER_H / 2))
    card.name:SetPoint("RIGHT", card.pill, "LEFT", -8, 0)

    -- Bouton fermer Blizzard (visible seulement en mode epingle/selection).
    card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    card.close:SetSize(26, 26); card.close:SetPoint("TOPRIGHT", 8, 8)
    card.close:SetScript("OnClick", function() card.closed = true; card:Hide() end)
    card.close:Hide()

    -- Description (bascule par le bouton livre).
    card.desc = Style.Box(card, COL.card, COL.edge)
    card.desc:SetWidth(W - PAD * 2)
    card.desc.text = card.desc:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.desc.text:SetPoint("TOPLEFT", 10, -9); card.desc.text:SetWidth(W - PAD * 2 - 20)
    card.desc.text:SetJustifyH("LEFT"); card.desc.text:SetJustifyV("TOP"); card.desc.text:SetWordWrap(true)
    card.desc:Hide()

    -- Bloc milieu : portrait 3D a gauche, qualite/breed + stats a droite.
    card.portrait = Style.Box(card, COL.card, COL.edge)
    card.portrait:SetSize(PORTRAIT_W, MID_H)
    card.model = CreateFrame("PlayerModel", nil, card.portrait)
    card.model:SetPoint("TOPLEFT", 1, -1); card.model:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Pastille "deja dans une team" : coin bas-droit du portrait.
    card.team = ns.PetTeamBadge.Create(card, 18, "ANCHOR_RIGHT")
    card.team:SetPoint("BOTTOMRIGHT", card.portrait, "BOTTOMRIGHT", -4, 4)
    card.team:SetFrameLevel(card.model:GetFrameLevel() + 5)

    card.stats = CreateFrame("Frame", nil, card)
    card.stats:SetSize(W - PAD * 2 - PORTRAIT_W - 12, MID_H)
    local half = card.stats:GetWidth() / 2
    card.qLabel = card.stats:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.qLabel:SetPoint("TOPLEFT", 0, 0); card.qLabel:SetText(ns.L("CARD_QUALITY"))
    card.bLabel = card.stats:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.bLabel:SetPoint("TOPLEFT", half, 0); card.bLabel:SetText(ns.L("CARD_BREED"))
    card.qValue = card.stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.qValue:SetPoint("TOPLEFT", card.qLabel, "BOTTOMLEFT", 0, -3)
    card.bValue = card.stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.bValue:SetPoint("TOPLEFT", card.bLabel, "BOTTOMLEFT", 0, -3)
    card.statSep = MakeSep(card.stats)
    card.statSep:SetPoint("TOPLEFT", 0, -34); card.statSep:SetPoint("TOPRIGHT", 0, -34)
    card.statRows = {}
    local keys = { "CARD_ATTACK", "CARD_SPEED", "CARD_HEALTH" }
    for i, key in ipairs(keys) do
        local lab = card.stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lab:SetPoint("TOPLEFT", 0, -(43 + (i - 1) * 20)); lab:SetText(ns.L(key))
        local val = card.stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        val:SetPoint("TOPRIGHT", 0, -(43 + (i - 1) * 20)); val:SetJustifyH("RIGHT")
        card.statRows[i] = { lab, val }
    end
    card.notOwned = card.stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.notOwned:SetPoint("TOPLEFT", 0, 0); card.notOwned:SetPoint("TOPRIGHT", 0, 0)
    card.notOwned:SetJustifyH("LEFT"); card.notOwned:SetJustifyV("TOP"); card.notOwned:SetWordWrap(true)
    card.notOwned:SetTextColor(1, 0.38, 0.38)

    card.sep1 = MakeSep(card)
    card.rowBreeds = MakeRow(card); card.rowBreeds.label:SetText(ns.L("CARD_POSSIBLE_BREEDS"))
    card.rowColl = MakeRow(card);   card.rowColl.label:SetText(ns.L("CARD_COLLECTED"))
    card.sep2 = MakeSep(card)

    card.srcLabel = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.srcLabel:SetText(ns.L("CARD_SOURCE"))
    card.srcText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.srcText:SetWidth(W - PAD * 2); card.srcText:SetJustifyH("LEFT"); card.srcText:SetJustifyV("TOP")
    card.srcText:SetWordWrap(true)

    card.abilLabel = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.abilLabel:SetText(ns.L("CARD_ABILITIES"))

    -- Sorts : colonne gauche = sorts 1-3, droite = 4-6 (meme numero de slot).
    card.abil = {}
    for a = 1, 6 do card.abil[a] = MakeCell(card) end

    card.book:SetActive(showDesc)
    return card
end

-- Pose une ligne libelle/valeur a y, retourne sa hauteur.
local function PlaceRow(r, y)
    r.label:ClearAllPoints(); r.label:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    r.value:ClearAllPoints(); r.value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    r.label:Show(); r.value:Show()
    return math.max(16, (r.value:GetStringHeight() or 0) + 3)
end

local function HideRow(r)
    r.label:Hide(); r.value:Hide()
end

local function PlaceSep(sep, y)
    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    sep:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    sep:Show()
end

-- d : donnees deja calculees (voir Render).
local function Layout(d)
    local y = HEADER_Y + HEADER_H + 8

    if showDesc then
        local has = d.description ~= ""
        local c = has and COL.text or COL.dim
        card.desc.text:SetText(has and d.description or ns.L("CARD_DESC_NONE"))
        card.desc.text:SetTextColor(c[1], c[2], c[3])
        local h = (card.desc.text:GetStringHeight() or 14) + 18
        card.desc:SetHeight(h)
        card.desc:ClearAllPoints(); card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        card.desc:Show()
        y = y + h + 8
    else
        card.desc:Hide()
    end

    card.portrait:ClearAllPoints(); card.portrait:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    card.stats:ClearAllPoints(); card.stats:SetPoint("TOPLEFT", card.portrait, "TOPRIGHT", 12, 0)
    y = y + MID_H + 8

    PlaceSep(card.sep1, y); y = y + 6

    -- Breeds possibles (valeur multi-ligne possible).
    if d.breeds then
        card.rowBreeds.value:SetText(d.breeds)
        y = y + PlaceRow(card.rowBreeds, y)
    else
        HideRow(card.rowBreeds)
    end
    if d.collected then
        card.rowColl.value:SetText(d.collected)
        y = y + PlaceRow(card.rowColl, y)
    else
        HideRow(card.rowColl)
    end

    if d.source then
        y = y + 4
        PlaceSep(card.sep2, y); y = y + 8
        card.srcLabel:ClearAllPoints(); card.srcLabel:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        card.srcLabel:Show(); y = y + 16
        card.srcText:SetText(d.source)
        card.srcText:ClearAllPoints(); card.srcText:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        card.srcText:Show()
        y = y + (card.srcText:GetStringHeight() or 14) + 8
    else
        card.sep2:Hide(); card.srcLabel:Hide(); card.srcText:Hide()
    end

    -- Sorts.
    local any = false
    for a = 1, 6 do
        local b = card.abil[a]
        local aid = d.abilList and d.abilList[a]
        if aid then
            any = true
            local rowi, coli = (a - 1) % 3, math.floor((a - 1) / 3)
            b.abilityID = aid
            b.num:SetText(rowi + 1)
            local _, icon, atype = C_PetJournal.GetPetAbilityInfo(aid)
            b.tex:SetTexture(icon)
            SetTypeIcon(b.type, atype)
            b.baseBorder = Style.TYPE_COL[atype] or COL.edge
            b:SetBackdropBorderColor(unpack(b.baseBorder))
            local req = d.levelList and d.levelList[a]
            if d.owned then
                local locked = req and d.level and d.level < req
                b.tex:SetDesaturated(locked and true or false)
                b.lock:SetShown(locked and true or false)
                if locked then b.req:SetText(req); b.req:Show() else b.req:Hide() end
            else
                b.tex:SetDesaturated(true); b.lock:Hide()
                if req then b.req:SetText(req); b.req:Show() else b.req:Hide() end
            end
            b.layoutRow, b.layoutCol = rowi, coli
            b:Show()
        else
            b.abilityID = nil; b:Hide()
        end
    end
    if any then
        y = y + 2
        card.abilLabel:ClearAllPoints(); card.abilLabel:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        card.abilLabel:Show(); y = y + 18
        for a = 1, 6 do
            local b = card.abil[a]
            if b:IsShown() then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", card, "TOPLEFT",
                    PAD + b.layoutCol * (CELL_W + 6), -(y + b.layoutRow * (CELL_H + CELL_GAP)))
            end
        end
        y = y + 3 * CELL_H + 2 * CELL_GAP
    else
        card.abilLabel:Hide()
    end

    card:SetHeight(y + PAD)
end

-- Rend la carte pour une espece ; petID nil = mascotte non possedee.
local function Render(anchor, speciesID, petID)
    if GetCursorInfo() == "battlepet" then PetCard.Hide(); return end

    local sName, _, sType, _, sSource, description, _, _, _, _, _, sDisplay = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    local name, customName, level, displayID, petType, sourceText = sName, nil, nil, sDisplay, sType, sSource
    if petID then
        local _, cn, lv, _, _, did, _, nm, _, pt, _, src = C_PetJournal.GetPetInfoByPetID(petID)
        name, customName, level, displayID, petType, sourceText = nm, cn, lv, did, pt, src
    end
    if not name then return end

    EnsureCard()
    card.anchor, card.speciesID, card.petID = anchor, speciesID, petID
    card.team:SetPetID(petID)

    if displayID and displayID > 0 then card.model:SetDisplayInfo(displayID); card.portrait:Show()
    else card.model:ClearModel() end

    card.name:SetText(customName or name)
    card.pill.petType = petType
    SetTypeIcon(card.typeIcon, petType)
    card.level:SetText(level and tostring(level) or "")
    card.pill:SetWidth(level and 54 or 28)

    local d = {
        owned = petID ~= nil, level = level, description = description or "",
        source = (sourceText and sourceText ~= "") and sourceText:gsub("|c%x%x%x%x%x%x%x%x", DIM) or nil,
    }
    d.abilList, d.levelList = C_PetJournal.GetPetAbilityList(speciesID)

    local poss = PossibleBreeds(speciesID)
    d.breeds = poss and table.concat(poss, ", ") or nil

    if petID then
        local _, maxHealth, attack, speed, rarity = C_PetJournal.GetPetStats(petID)
        local q = rarity and ITEM_QUALITY_COLORS[rarity - 1]
        if q then card.name:SetTextColor(q.r, q.g, q.b) else card.name:SetTextColor(1, 1, 1) end
        card.notOwned:Hide()
        card.qLabel:Show(); card.bLabel:Show(); card.qValue:Show(); card.bValue:Show(); card.statSep:Show()
        card.qValue:SetText(rarity and _G["ITEM_QUALITY" .. (rarity - 1) .. "_DESC"] or "?")
        if q then card.qValue:SetTextColor(q.r, q.g, q.b) else card.qValue:SetTextColor(1, 1, 1) end
        card.bValue:SetText((ns.Breed and ns.Breed.GetForPetID(petID)) or "?")
        local vals = { attack, speed, maxHealth }
        for i, r in ipairs(card.statRows) do r[1]:Show(); r[2]:Show(); r[2]:SetText(Num(vals[i])) end

        local col = CollectedBreeds(speciesID)
        local parts = {}
        for b, n in pairs(col.breeds) do parts[#parts + 1] = b .. (n > 1 and (" x" .. n) or "") end
        table.sort(parts)
        d.collected = col.total .. (#parts > 0 and (" " .. DIM .. "(" .. table.concat(parts, ", ") .. ")|r") or "")
    else
        card.name:SetTextColor(0.7, 0.7, 0.7)
        card.qLabel:Hide(); card.bLabel:Hide(); card.qValue:Hide(); card.bValue:Hide(); card.statSep:Hide()
        for _, r in ipairs(card.statRows) do r[1]:Hide(); r[2]:Hide() end
        card.notOwned:SetText(ns.L("CARD_NOT_OWNED")); card.notOwned:Show()
    end

    Layout(d)

    -- Bouton fermer visible uniquement quand c'est la selection epinglee.
    card.close:SetShown(petID and petID == ns.selectedPetID or (not petID and speciesID == ns.selectedSpecies))

    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 4)
    card:SetClampedToScreen(true)
    card:Show()
end

Refresh = function()
    if card and card.speciesID then Render(card.anchor, card.speciesID, card.petID) end
end

local function Fill(anchor, petID)
    local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
    if speciesID then Render(anchor, speciesID, petID) end
end

local function FillSpecies(anchor, speciesID)
    Render(anchor, speciesID, nil)
end

-- Survol.
function PetCard.ShowFor(anchor, petID)
    if type(petID) == "string" then Fill(anchor, petID) end
end

-- Survol d'une mascotte non possedee (par speciesID).
function PetCard.ShowForSpecies(anchor, speciesID)
    if type(speciesID) == "number" then FillSpecies(anchor, speciesID) end
end

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
end, true)

ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", function() wipe(collectedCache) end)
