local addonName, ns = ...

-- ====================================================
-- RIGHTPANEL — colonne droite : en-tete [+ Tous][recherche][Teams],
-- liste defilante des categories (fleche + nom colore + compteur),
-- DEPLIABLES : clic sur une categorie -> affiche ses equipes.
-- Boutons de mode en bas : Teams / Cibles / File.
-- ====================================================

ns.RegisterModule("RightPanel", {})

-- Confirmation de suppression d'une categorie.
StaticPopupDialogs["MATCHVIEWERLOG_DELCAT"] = {
    text = ns.L("DELCAT_CONFIRM"),
    button1 = YES, button2 = NO,
    OnAccept = function(self, data) if data and ns.Cats then ns.Cats.Delete(data) end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Confirmation de suppression d'une equipe.
StaticPopupDialogs["MATCHVIEWERLOG_DELTEAM"] = {
    text = ns.L("DELTEAM_CONFIRM"),
    button1 = YES, button2 = NO,
    OnAccept = function(self, data) if data and ns.Teams then ns.Teams.Delete(data) end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local PAD, ROW_H = 8, 22
local accent = { 0.30, 0.55, 0.90 }

local built
local scroll, rows = nil, {}
local expanded = {}          -- [catID] = true si depliee
local mode = "teams"
local listShown = true
local searchText = ""        -- filtre de la barre "rechercher une team"

-- ---- modele d'items a plat (categories/cibles + equipes depliees) ----
local function BuildItems()
    local items = {}
    if mode == "target" then
        local targets = ns.Teams and ns.Teams.AllTargets() or {}
        for _, tg in ipairs(targets) do
            items[#items + 1] = { type = "target", target = tg }
            if expanded["tgt:" .. tg.npcID] then
                for _, team in ipairs(tg.teams) do
                    items[#items + 1] = { type = "team", team = team }
                end
            end
        end
        return items
    end
    if mode == "queue" then
        -- File d'XP : file manuelle + mascottes des equipes sous niveau max.
        local pets = ns.Teams and ns.Teams.QueuePets() or {}
        for _, pid in ipairs(pets) do
            items[#items + 1] = { type = "pet", petID = pid }
        end
        return items
    end
    local cats = ns.Cats and ns.Cats.List() or {}
    -- Recherche active : liste a plat des equipes dont le nom correspond
    -- (toutes categories confondues), sans les en-tetes de categorie.
    if searchText ~= "" then
        local q = searchText:lower()
        for _, cat in ipairs(cats) do
            for _, team in ipairs(ns.Cats.TeamsIn(cat.id)) do
                if (team.name or ""):lower():find(q, 1, true) then
                    items[#items + 1] = { type = "team", team = team }
                end
            end
        end
        return items
    end
    for _, cat in ipairs(cats) do
        items[#items + 1] = { type = "cat", cat = cat }
        if expanded[cat.id] then
            for _, team in ipairs(ns.Cats.TeamsIn(cat.id)) do
                items[#items + 1] = { type = "team", team = team }
            end
        end
    end
    return items
end

local Update  -- fwd

-- Cache les visuels "mascotte" (row reutilisee entre types d'items).
local function HidePetBits(row)
    if row.petIcon then row.petIcon:Hide(); row.petLevel:SetText(""); row.petBreed:SetText(""); row.petType:Hide() end
end

local function SetRow(row, item)
    row.name:ClearAllPoints()
    HidePetBits(row)
    if row.scriptIcon then row.scriptIcon:Hide() end
    if item.type == "cat" then
        row.arrow:Show()
        row.arrow:SetAtlas(expanded[item.cat.id] and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
        row.name:SetPoint("LEFT", row.arrow, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
        row.name:SetText("|cff" .. (item.cat.color or "ffd200") .. (item.cat.name or "?") .. "|r")
        row.count:SetText(tostring(ns.Cats.CountTeams(item.cat.id)))
        row.count:Show()
        row._type, row.catID, row.team, row.tgtKey, row.petID = "cat", item.cat.id, nil, nil, nil
    elseif item.type == "target" then
        row.arrow:Show()
        row.arrow:SetAtlas(expanded["tgt:" .. item.target.npcID] and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
        row.name:SetPoint("LEFT", row.arrow, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
        row.name:SetText("|cffffd200" .. (item.target.name or "?") .. "|r")
        row.count:SetText(tostring(#item.target.teams))
        row.count:Show()
        row._type, row.catID, row.team, row.tgtKey, row.petID = "target", nil, nil, "tgt:" .. item.target.npcID, nil
    elseif item.type == "pet" then
        row.arrow:Hide(); row.count:Hide()
        local pid = item.petID
        local _, customName, level, _, _, _, _, name, icon, petType = C_PetJournal.GetPetInfoByPetID(pid)
        row.petIcon:SetTexture(icon); row.petIcon:Show()
        row.petLevel:SetText(level and ("|cffffd200" .. level .. "|r") or "")
        local _, _, _, _, rarity = C_PetJournal.GetPetStats(pid)
        local q = rarity and ITEM_QUALITY_COLORS[rarity - 1]
        row.name:SetPoint("LEFT", row.petIcon, "RIGHT", 6, 0)
        -- Borne a gauche du breed (et non du type) : le nom ne deborde plus dessus.
        row.name:SetPoint("RIGHT", row.petBreed, "LEFT", -4, 0)
        row.name:SetText((ns.Options and ns.Options.DisplayName(customName, name)) or customName or name or "")
        if q then row.name:SetTextColor(q.r, q.g, q.b) else row.name:SetTextColor(0.9, 0.9, 0.9) end
        local typeTex = ns.TypeIcon(petType)
        if typeTex then
            row.petType:SetTexture(typeTex)
            row.petType:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
            row.petType:Show()
        end
        local breed = ns.Breed and ns.Breed.GetForPetID(pid)
        row.petBreed:SetText(breed and ("|cff8fd3ff" .. breed .. "|r") or "")
        row._type, row.catID, row.team, row.tgtKey, row.petID = "pet", nil, nil, nil, pid
    else
        row.arrow:Hide()
        row.name:SetPoint("LEFT", row, "LEFT", 28, 0)
        -- Team scriptee : icone draconien a droite, le nom s'arrete avant.
        local scriptTex = ns.TeamHasScript and ns.TeamHasScript(item.team.id) and ns.TypeIcon(ns.DRAGONKIN_TYPE or 2)
        if scriptTex then
            row.scriptIcon:SetTexture(scriptTex)
            row.scriptIcon:Show()
            row.name:SetPoint("RIGHT", row.scriptIcon, "LEFT", -4, 0)
        else
            row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
        row.name:SetText("|cffbfe0ff" .. (item.team.name or "?") .. "|r")
        row.name:SetTextColor(1, 1, 1)
        row.count:Hide()
        row._type, row.catID, row.team, row.tgtKey, row.petID = "team", nil, item.team, nil, nil
    end
end

Update = function()
    if not scroll then return end
    local items = BuildItems()
    local n = #items
    local h = scroll:GetHeight()
    local maxRows = (h and h > 0) and math.max(1, math.floor(h / ROW_H)) or #rows
    if maxRows > #rows then maxRows = #rows end
    local offset = FauxScrollFrame_GetOffset(scroll)

    for line = 1, #rows do
        local row = rows[line]
        local idx = offset + line
        if listShown and line <= maxRows and idx <= n then
            SetRow(row, items[idx])
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(scroll, n, maxRows, ROW_H)
end

local function AcquireRow(parent, i)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)

    row.arrow = row:CreateTexture(nil, "OVERLAY")
    row.arrow:SetSize(14, 14); row.arrow:SetPoint("LEFT", 6, 0)
    row.arrow:SetAtlas("housing-floor-arrow-up-default")

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -10, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)

    -- Visuels "mascotte" (mode File) : icone, niveau, type, breed. Caches
    -- par defaut, montres seulement pour les lignes de type "pet".
    row.petIcon = row:CreateTexture(nil, "ARTWORK")
    row.petIcon:SetSize(26, 26); row.petIcon:SetPoint("LEFT", 4, 0)
    row.petIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92); row.petIcon:Hide()
    -- Niveau : a droite du type (element le plus a droite de la ligne pet).
    row.petLevel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.petLevel:SetWidth(22); row.petLevel:SetJustifyH("CENTER")
    row.petLevel:SetPoint("RIGHT", -6, 0)
    row.petType = row:CreateTexture(nil, "OVERLAY")
    row.petType:SetSize(18, 18); row.petType:SetPoint("RIGHT", row.petLevel, "LEFT", -2, 0); row.petType:Hide()
    row.petBreed = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.petBreed:SetPoint("RIGHT", row.petType, "LEFT", -4, 0)

    -- Marqueur "cette team a un script" : icone de type draconien a droite.
    row.scriptIcon = row:CreateTexture(nil, "OVERLAY")
    row.scriptIcon:SetSize(16, 16); row.scriptIcon:SetPoint("RIGHT", -6, 0)
    row.scriptIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
    row.scriptIcon:Hide()

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(accent[1] * 0.25, accent[2] * 0.25, accent[3] * 0.25, 0.35)
        if self._type == "cat" then self:SetBackdropBorderColor(1, 0.82, 0, 1) end
        if self._type == "pet" and self.petID and ns.PetCard then ns.PetCard.ShowFor(self, self.petID) end
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0); self:SetBackdropBorderColor(0, 0, 0, 0)
        if self._type == "pet" and ns.PetCard then ns.PetCard.OnLeave() end
    end)
    -- Menu clic droit : deux choix (Modifier / Supprimer).
    local function CatMenu(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_CAT_ROWMENU")
            root:CreateButton(ns.L("MENU_EDIT_CAT"), function()
                if ns.CategoryDialog then ns.CategoryDialog.Open(self.catID) end
            end)
            -- Comptes ayant renomme Favoris/Aucune categorie avant le verrou
            -- de nom : option dediee pour revenir au nom par defaut.
            if ns.Cats and ns.Cats.IsNameLocked(self.catID) then
                root:CreateButton(ns.L("MENU_RESET_CAT_NAME"), function()
                    ns.Cats.ResetName(self.catID)
                end)
            end
            -- Importer une team directement dans cette categorie (pre-remplie).
            root:CreateButton(ns.L("MENU_IMPORT_TEAM"), function()
                if ns.TeamShare then ns.TeamShare.OpenImport(self.catID) end
            end)
            root:CreateButton(ns.L("MENU_EXPORT_CAT"), function()
                if ns.TeamShare then ns.TeamShare.OpenExportCategory(self.catID) end
            end)
            root:CreateButton(ns.L("MENU_DELETE_CAT"), function()
                StaticPopup_Show("MATCHVIEWERLOG_DELCAT", nil, nil, self.catID)
            end)
        end)
    end
    local function TeamMenu(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local team = self.team
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_TEAM_ROWMENU")
            -- Modifier = charger l'equipe au centre pour changer ses attaques.
            root:CreateButton(ns.L("MENU_EDIT_TEAM"), function()
                if ns.Teams then ns.Teams.Load(team) end
            end)
            -- Renommer / changer de categorie (sans charger la compo).
            root:CreateButton(ns.L("MENU_RENAME_TEAM"), function()
                if ns.TeamDialog then ns.TeamDialog.OpenEdit(team.id) end
            end)
            -- Favoris : flag independant de la categorie (voir Categories.TeamsIn).
            root:CreateButton(team.favorite and ns.L("MENU_FAV_REMOVE") or ns.L("MENU_FAV_ADD"), function()
                if ns.Teams then ns.Teams.ToggleFavorite(team.id) end
            end)
            -- Exporter : charge la team (comme Modifier) puis ouvre le code.
            root:CreateButton(ns.L("MENU_EXPORT_TEAM"), function()
                if ns.Teams and ns.TeamShare then ns.Teams.Load(team); ns.TeamShare.OpenExport() end
            end)
            root:CreateButton(ns.L("MENU_DELETE_TEAM"), function()
                StaticPopup_Show("MATCHVIEWERLOG_DELTEAM", nil, nil, team.id)
            end)
        end)
    end

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if self._type == "cat" then
            if button == "RightButton" then
                CatMenu(self)
            else
                expanded[self.catID] = (not expanded[self.catID]) or nil
                Update()
            end
        elseif self._type == "target" then
            expanded[self.tgtKey] = (not expanded[self.tgtKey]) or nil
            Update()
        elseif self._type == "team" then
            if button == "RightButton" then
                TeamMenu(self)
            elseif ns.Teams then
                ns.Teams.Load(self.team)
            end
        elseif self._type == "pet" then
            -- Pierre/bandage en cours de ciblage : l'appliquer a cette mascotte.
            if button ~= "RightButton" and SpellIsTargeting() and C_PetJournal.SpellTargetBattlePet then
                C_PetJournal.SpellTargetBattlePet(self.petID)
                return
            end
            if button == "RightButton" then
                if ns.PetMenu then ns.PetMenu.Open(self, self.petID) end
            else
                ns.SetSelectedPet(self.petID)
            end
        end
    end)

    -- Reordonner les categories (drag cat) ou glisser une mascotte vers un slot.
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if self._type == "cat" or (self._type == "team" and self.team) then
            ns.RightPanelDnD.Start(self)
        elseif self._type == "pet" and self.petID and C_PetJournal.PickupPet then
            C_PetJournal.PickupPet(self.petID)
        end
    end)
    row:SetScript("OnDragStop", ns.RightPanelDnD.Finish)
    return row
end

local function BuildHeader(panel)
    local teamsBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    teamsBtn:SetSize(56, 22); teamsBtn:SetPoint("TOPRIGHT", -PAD, -PAD)
    teamsBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    teamsBtn:SetBackdropColor(0.12, 0.12, 0.16, 1); teamsBtn:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    local tt = teamsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tt:SetPoint("CENTER"); tt:SetText(ns.L("RIGHT_TEAMS_BTN") .. " |cffffffff>|r")
    teamsBtn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_TEAMS_MENU")
            root:CreateButton(ns.L("MENU_NEW_CAT"), function()
                if ns.CategoryDialog then ns.CategoryDialog.Open(nil) end
            end)
            root:CreateButton(ns.L("MENU_IMPORT_TEAM"), function()
                if ns.TeamShare then ns.TeamShare.OpenImport() end
            end)
            root:CreateButton(ns.L("MENU_EXPORT_TEAM"), function()
                if ns.TeamShare then ns.TeamShare.OpenExport() end
            end)
            root:CreateButton(ns.L("MENU_IMPORT_CAT"), function()
                if ns.TeamShare then ns.TeamShare.OpenImportCategory() end
            end)
        end)
    end)

    -- Barre "rechercher une team" : bordure carree violette (style demande),
    -- fonctionnelle (filtre les equipes par nom).
    local s = ns.Widgets.MakeSearchBox(panel, ns.L("RIGHT_SEARCH_TEAMS"), function(text)
        searchText = text
        if built then Update() end
    end)
    s:SetHeight(22)
    s:SetPoint("TOPLEFT", PAD, -PAD)
    s:SetPoint("RIGHT", teamsBtn, "LEFT", -4, 0)
end

local function Build()
    if built then return end
    local panel = ns.Frame and ns.Frame.right
    if not panel then return end
    built = true

    BuildHeader(panel)

    scroll = CreateFrame("ScrollFrame", "MatchViewerLogTeamsScroll", panel, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -PAD - 30)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 20, 34)
    scroll:SetScript("OnVerticalScroll", function(self, o)
        FauxScrollFrame_OnVerticalScroll(self, o, ROW_H, Update)
    end)
    ns.ScrollSkin.Apply(scroll)

    local visible = math.floor(460 / ROW_H) + 1
    for i = 1, visible do
        local row = AcquireRow(panel, i)
        if i == 1 then
            row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", rows[i - 1], "BOTTOMRIGHT", 0, 0)
        end
        rows[i] = row
    end

    ns.RightPanelDnD.Init(rows, ROW_H)

    local placeholder = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    placeholder:SetPoint("CENTER", scroll)
    placeholder:Hide()

    -- ---- Boutons de mode en bas ----
    -- Modes de base + modes injectes par un compagnon (ns.rightPanelExtraModes).
    -- Un mode "custom" masque la liste et delegue son contenu a onShow/onHide.
    local baseModes = {
        { key = "teams",  label = ns.L("RIGHT_MODE_TEAMS"),  col = { 0.45, 0.25, 0.75 } },
        { key = "target", label = ns.L("RIGHT_MODE_TARGET"), col = { 0.80, 0.45, 0.15 } },
        { key = "queue",  label = ns.L("RIGHT_MODE_QUEUE"),  col = { 0.80, 0.35, 0.55 } },
    }
    local modeBtns = {}
    local modeDefs = {}          -- key -> def (pour retrouver onShow/onHide)
    local activeCustom           -- def custom actuellement affichee

    -- Mode "Options" natif, toujours en dernier : a droite de Script quand le
    -- compagnon est present, sinon a la place de Script. Delegue son contenu a
    -- ns.OptionsPanel (pas de dependance dure : garde si le module manque).
    local optionsMode = {
        key = "options", label = ns.L("RIGHT_MODE_OPTIONS"),
        col = { 0.30, 0.55, 0.90 }, custom = true,
        onShow = function(p) if ns.OptionsPanel then ns.OptionsPanel.OnShow(p) end end,
        onHide = function(p) if ns.OptionsPanel then ns.OptionsPanel.OnHide(p) end end,
    }

    local function AllModes()
        local out = {}
        for _, m in ipairs(baseModes) do out[#out + 1] = m end
        for _, m in ipairs(ns.rightPanelExtraModes or {}) do out[#out + 1] = m end
        out[#out + 1] = optionsMode
        return out
    end

    local function SetMode(key)
        mode = key
        for _, b in ipairs(modeBtns) do
            b:SetBackdropBorderColor(b.key == key and 1 or 0.15, b.key == key and 0.82 or 0.15, b.key == key and 0 or 0.18, 1)
        end
        local def = modeDefs[key]
        -- On quitte un mode custom : on le referme proprement.
        if activeCustom and activeCustom ~= def and activeCustom.onHide then
            activeCustom.onHide(panel)
        end
        if def and def.custom then
            activeCustom = def
            listShown = false
            placeholder:Hide()
            wipe(expanded); Update()
            if def.onShow then def.onShow(panel) end
        else
            activeCustom = nil
            listShown = true
            wipe(expanded); Update()
            -- File vide : petit message.
            if key == "queue" and #BuildItems() == 0 then
                placeholder:SetText(ns.L("QUEUE_EMPTY")); placeholder:Show()
            else
                placeholder:Hide()
            end
        end
    end

    local function BuildModeBar()
        for _, b in ipairs(modeBtns) do b:Hide() end
        wipe(modeBtns); wipe(modeDefs)
        for i, m in ipairs(AllModes()) do
            modeDefs[m.key] = m
            local b = CreateFrame("Button", nil, panel, "BackdropTemplate")
            b.key = m.key; b:SetHeight(24)
            b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            local col = m.col or { 0.3, 0.3, 0.35 }
            b:SetBackdropColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6, 1)
            b:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)
            if i == 1 then b:SetPoint("BOTTOMLEFT", PAD, 6)
            else b:SetPoint("BOTTOMLEFT", modeBtns[i - 1], "BOTTOMRIGHT", 4, 0) end
            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("CENTER"); t:SetText(m.label)
            b:SetScript("OnClick", function() SetMode(m.key) end)
            modeBtns[i] = b
        end
    end

    local function LayoutModeBtns()
        local n = #modeBtns
        if n == 0 then return end
        local w = (panel:GetWidth() - 2 * PAD - (n - 1) * 4) / n
        if w and w > 10 then for _, b in ipairs(modeBtns) do b:SetWidth(w) end end
    end

    BuildModeBar()
    panel:HookScript("OnSizeChanged", LayoutModeBtns)
    LayoutModeBtns()

    -- Un compagnon enregistre un mode apres coup -> on reconstruit la barre.
    ns.On("MVL_RIGHTMODES_CHANGED", function()
        BuildModeBar(); LayoutModeBtns()
    end)

    SetMode("teams")
    Update()
    ns.On("CATS_CHANGED", Update)
    ns.On("TEAMS_CHANGED", Update)
    -- Deplie la categorie de destination a chaque sauvegarde/deplacement de
    -- team (TeamStore.Save/SetInfo) : sinon une team fraichement rangee dans
    -- une categorie repliee (typiquement "Aucune categorie" la 1ere fois)
    -- semble disparaitre au lieu d'apparaitre a l'endroit choisi.
    ns.On("TEAM_SAVED", function(_, catID) if catID then expanded[catID] = true end end)
    -- Le mode de choix du slot XP change l'ordre de la File : on la rafraichit.
    ns.On("MVL_OPTIONS_CHANGED", function() if mode == "queue" then Update() end end)
end

ns.On("MVL_FRAME_READY", Build)
ns.On("MVL_FRAME_SHOW", function() if built then Update() end end)
-- Un pet monte en niveau : la File "a monter" se met a jour toute seule.
ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", function()
    if built and mode == "queue" then Update() end
end)
