local addonName, ns = ...

-- ====================================================
-- LEFTPANEL — colonne gauche : recherche + liste des mascottes
-- (portrait, niveau, nom, breed, icone de type). Liste defilante
-- (FauxScrollFrame) alimentee par C_PetJournal, filtree par la
-- recherche et par TypeBar (via ROSTER_REFRESH).
-- ====================================================

ns.RegisterModule("LeftPanel", {})

local ROW_H = 34
local rows, scroll, search = {}, nil, nil

-- Liste ordonnee (indices), mise en cache. Recalculee seulement quand le roster,
-- la recherche ou un filtre change (pas a chaque scroll) : tri de tout le roster.
local orderedCache, orderedDirty = nil, true

-- Construit la liste : applique les filtres (niveau ns.LevelFilter + doublons
-- ns.DupeFilter) puis trie : FAVORIES d'abord, ensuite par niveau DECROISSANT
-- (25 -> 0) puis nom. Les non-possedees (sans niveau) comptent comme 0.
-- Un seul parcours du journal : les comptes de doublons se tallient dans la meme
-- passe (le filtre est applique apres coup, comptes complets connus).
-- Comparateur selon l'ordre choisi (ns.Options). Favoris toujours en tete ;
-- si nonBattleLast, les non-combattantes passent apres tout le reste.
local function MakeComparator(sortMode, nbLast)
    return function(a, b)
        if nbLast and a.canBattle ~= b.canBattle then return a.canBattle end
        if a.fav ~= b.fav then return a.fav end
        if sortMode == "name" then
            return a.name < b.name
        elseif sortMode == "rarity_name" then
            if a.rarity ~= b.rarity then return a.rarity > b.rarity end
            return a.name < b.name
        elseif sortMode == "level_rarity_name" then
            if a.level ~= b.level then return a.level > b.level end
            if a.rarity ~= b.rarity then return a.rarity > b.rarity end
            return a.name < b.name
        else -- level_name (defaut)
            if a.level ~= b.level then return a.level > b.level end
            return a.name < b.name
        end
    end
end

local function BuildOrdered()
    local total = C_PetJournal.GetNumPets() or 0
    local lf, df = ns.LevelFilter, ns.DupeFilter
    local sortMode = (ns.Options and ns.Options.Get("sort")) or "level_name"
    local nbLast = (ns.Options and ns.Options.Get("nonBattleLast")) or false
    -- Rarete lue seulement si l'ordre choisi en depend (evite un GetPetStats
    -- par mascotte quand ce n'est pas necessaire).
    local needRarity = (sortMode == "rarity_name" or sortMode == "level_rarity_name")
    local dupe = df and {} or nil
    local list = {}
    for i = 1, total do
        -- Retours 1..15 de GetPetInfoByIndex : canBattle est le 15e (comme le
        -- journal Blizzard). name = 8e ; icone/type/... ignores jusqu'a canBattle.
        local petID, speciesID, isOwned, _, level, favorite, _, name, _, _, _, _, _, _, canBattle =
            C_PetJournal.GetPetInfoByIndex(i)
        if df and isOwned and speciesID then dupe[speciesID] = (dupe[speciesID] or 0) + 1 end
        local ok = true
        if lf then
            if not isOwned or not level then ok = false
            elseif lf == "max" then ok = level >= ns.MAX_PET_LEVEL
            else ok = level < ns.MAX_PET_LEVEL end
        end
        if ok then
            local rarity = 0
            if needRarity and isOwned and petID then
                rarity = select(5, C_PetJournal.GetPetStats(petID)) or 0
            end
            list[#list + 1] = { idx = i, species = speciesID, owned = isOwned,
                level = level or 0, name = name or "", rarity = rarity,
                fav = (favorite and isOwned) and true or false,
                canBattle = canBattle and true or false }
        end
    end
    if df then
        local kept = {}
        for _, e in ipairs(list) do
            if e.owned and e.species and (dupe[e.species] or 0) > 1 then kept[#kept + 1] = e end
        end
        list = kept
    end
    table.sort(list, MakeComparator(sortMode, nbLast))
    local out = {}
    for k, v in ipairs(list) do out[k] = v.idx end
    return out
end

local function OrderedIndices()
    if orderedDirty or not orderedCache then
        orderedCache = BuildOrdered()
        orderedDirty = false
    end
    return orderedCache
end

local function UpdateList()
    if not scroll then return end
    local list = OrderedIndices()
    local num = #list
    local offset = FauxScrollFrame_GetOffset(scroll)

    -- Nombre de lignes qui tiennent VRAIMENT dans la zone : evite qu'une
    -- ligne deborde sous l'inset (sur le bouton Invoquer).
    local h = scroll:GetHeight()
    local maxRows = (h and h > 0) and math.max(1, math.floor(h / ROW_H)) or #rows
    if maxRows > #rows then maxRows = #rows end

    for line = 1, #rows do
        local row = rows[line]
        local pos = offset + line
        if line <= maxRows and pos <= num then
            local idx = list[pos]
            local petID, speciesID, isOwned, customName, level, favorite, _, name, icon, petType =
                C_PetJournal.GetPetInfoByIndex(idx)
            row.icon:SetTexture(icon)
            row.icon:SetDesaturated(not isOwned)
            row.fav:SetShown(favorite and isOwned)
            row.name:SetText(ns.Options.DisplayName(customName, name) or "")
            -- Couleur du nom par rarete (rare bleu, inhabituel vert, etc.).
            local q
            if isOwned then
                local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID)
                q = rarity and ITEM_QUALITY_COLORS[rarity - 1]
            end
            if q then row.name:SetTextColor(q.r, q.g, q.b)
            else row.name:SetTextColor(isOwned and 0.9 or 0.5, isOwned and 0.9 or 0.5, isOwned and 0.9 or 0.5) end
            local selOn = (ns.selectedPetID ~= nil and petID == ns.selectedPetID)
                or (ns.selectedSpecies ~= nil and not petID and speciesID == ns.selectedSpecies)
            row:SetBackdropBorderColor(selOn and 1 or 0, selOn and 0.82 or 0, 0, selOn and 1 or 0)
            row.level:SetText(level and ("|cffffd200" .. level .. "|r") or "")
            local typeTex = ns.TypeIcon(petType)
            if typeTex then
                row.typeIcon:SetTexture(typeTex)
                row.typeIcon:Show()
            else
                row.typeIcon:Hide()
            end
            local breed = isOwned and ns.Breed and ns.Breed.GetForPetID(petID)
            row.breed:SetText(breed and ("|cff8fd3ff" .. breed .. "|r") or "")
            row.team:SetPetID(isOwned and petID or nil)
            row.petID = petID
            row.species = speciesID
            row.owned = isOwned
            row:Show()
        else
            row:Hide()
        end
    end

    FauxScrollFrame_Update(scroll, num, maxRows, ROW_H)
end
ns.MVL_UpdateRoster = UpdateList

-- Amene une mascotte dans la zone visible et rafraichit (utilise quand une
-- selection vient de l'exterieur, ex: clic sur le toast Blizzard).
function ns.MVL_RevealPet(petID)
    if not scroll or type(petID) ~= "string" then return end
    local list = OrderedIndices()
    local num = #list
    local pos
    for p = 1, num do
        if C_PetJournal.GetPetInfoByIndex(list[p]) == petID then pos = p; break end
    end
    if not pos then return end
    local h = scroll:GetHeight()
    local maxRows = (h and h > 0) and math.max(1, math.floor(h / ROW_H)) or #rows
    local offset = FauxScrollFrame_GetOffset(scroll)
    if pos <= offset or pos > offset + maxRows then
        local newOffset = math.min(math.max(0, pos - 1), math.max(0, num - maxRows))
        FauxScrollFrame_SetOffset(scroll, newOffset)
    end
    UpdateList()
end

local function Build()
    local left = ns.Frame and ns.Frame.left
    if not left or scroll then return end

    search = ns.Widgets.MakeSearchBox(left, ns.L("SEARCH_PETS"), function(text)
        ns.petSearchText = text   -- memorise pour restaurer apres un scan complet
        C_PetJournal.SetSearchFilter(text)
    end)
    search:SetHeight(22)
    search:SetPoint("TOPLEFT", 8, -6)
    search:SetPoint("TOPRIGHT", -8, -6)

    scroll = CreateFrame("ScrollFrame", "MatchViewerLogRosterScroll", left, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -88)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    scroll:SetScript("OnVerticalScroll", function(self, o)
        FauxScrollFrame_OnVerticalScroll(self, o, ROW_H, UpdateList)
    end)
    ns.ScrollSkin.Apply(scroll)

    local visible = math.floor(430 / ROW_H) + 1
    for i = 1, visible do
        local row = CreateFrame("Button", nil, left, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row:SetBackdropBorderColor(0, 0, 0, 0)
        if i == 1 then
            row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", rows[i - 1], "BOTTOMRIGHT", 0, 0)
        end

        local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        -- Clic gauche : selectionne. Clic droit : menu (invoquer/favori/cage/renommer).
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if not self.petID then
                -- Mascotte non possedee : clic gauche epingle sa carte "espece"
                -- (on peut alors survoler les sorts pour lire ce qu'ils font).
                if button ~= "RightButton" and self.species then ns.SetSelectedSpecies(self.species) end
                return
            end
            -- Une pierre/un bandage est en cours de ciblage (bouton de l'addon
            -- OU objet du sac) : clic gauche = l'appliquer a cette mascotte.
            if button ~= "RightButton" and SpellIsTargeting() and self.owned
               and C_PetJournal.SpellTargetBattlePet then
                C_PetJournal.SpellTargetBattlePet(self.petID)
                return
            end
            if button == "RightButton" then
                if ns.PetMenu then ns.PetMenu.Open(self, self.petID) end
            else
                ns.SetSelectedPet(self.petID)
            end
        end)

        -- Survol : carte perso (rendu 3D + infos).
        row:SetScript("OnEnter", function(self)
            if self.petID and ns.PetCard then
                ns.PetCard.ShowFor(self, self.petID)
            elseif self.species and ns.PetCard then
                ns.PetCard.ShowForSpecies(self, self.species)   -- mascotte non possedee
            end
        end)
        row:SetScript("OnLeave", function() if ns.PetCard then ns.PetCard.OnLeave() end end)

        -- Glisser une mascotte vers un slot du centre.
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart", function(self)
            if self.petID and C_PetJournal.PickupPet then C_PetJournal.PickupPet(self.petID) end
        end)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28); row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Etoile favori (meme atlas que le journal Blizzard), en badge sur le portrait.
        row.fav = row:CreateTexture(nil, "OVERLAY")
        row.fav:SetAtlas("PetJournal-FavoritesIcon")
        row.fav:SetSize(14, 14)
        row.fav:SetPoint("CENTER", row.icon, "TOPLEFT", 3, -3)
        row.fav:Hide()

        -- Niveau : a droite du type (element le plus a droite de la ligne).
        row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.level:SetWidth(22); row.level:SetJustifyH("CENTER")
        row.level:SetPoint("RIGHT", -4, 0)

        row.typeIcon = row:CreateTexture(nil, "OVERLAY")
        row.typeIcon:SetSize(20, 20)
        row.typeIcon:SetPoint("RIGHT", row.level, "LEFT", -2, 0)
        -- Icone nette : sous-region de l'atlas PetIcon-* (memes TexCoords
        -- que la carte de mascotte Blizzard). Sans ca, tout l'atlas s'affiche.
        row.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)

        -- Largeur fixe : la pastille "team" reste alignee d'une ligne a l'autre.
        row.breed = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.breed:SetWidth(26); row.breed:SetJustifyH("RIGHT")
        row.breed:SetPoint("RIGHT", row.typeIcon, "LEFT", -4, 0)

        -- Pastille "deja dans une team" ; relaie le survol a la ligne (PetCard).
        row.team = ns.PetTeamBadge.Create(row, 14, "ANCHOR_LEFT",
            function() local f = row:GetScript("OnEnter"); if f then f(row) end end,
            function() local f = row:GetScript("OnLeave"); if f then f(row) end end)
        row.team:SetPoint("RIGHT", row.breed, "LEFT", -3, 0)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        -- Borne a gauche de la pastille team : les noms longs sont tronques
        -- ("...") au lieu de deborder par-dessus.
        row.name:SetPoint("RIGHT", row.team, "LEFT", -3, 0)
        row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)

        rows[i] = row
    end

    UpdateList()
end

-- L'ordre/les filtres/la recherche ont change : on invalide le cache d'ordre
-- puis on rafraichit. (PET_SELECTED ne change que la surbrillance : pas d'invalidation.)
-- Coalesce : la recherche declenche PET_JOURNAL_LIST_UPDATE a chaque frappe, et un
-- changement de type declenche ROSTER_REFRESH + PET_JOURNAL_LIST_UPDATE. On regroupe
-- ces rafales en un seul re-tri complet au lieu d'un par event.
local invalidatePending = false
local function Invalidate()
    if invalidatePending then return end
    invalidatePending = true
    C_Timer.After(0.1, function()
        invalidatePending = false
        orderedDirty = true
        UpdateList()
    end)
end

ns.On("MVL_FRAME_READY", Build)
ns.On("MVL_FRAME_SHOW", UpdateList)
ns.On("ROSTER_REFRESH", Invalidate)
ns.On("PET_SELECTED", UpdateList)
ns.On("TEAMS_CHANGED", UpdateList)
ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", Invalidate)
