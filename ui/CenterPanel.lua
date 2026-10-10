local addonName, ns = ...

-- ====================================================
-- CENTERPANEL — 3 cartes d'equipe egales. Chaque carte : icone
-- haut-gauche (infobulle mascotte au survol), nom (couleur rarete),
-- type haut-droite, breed, barre de vie, et 3 sorts a droite.
-- Survol d'un sort : fleche + infobulle du sort. Clic : menu des 2
-- choix du palier. Accepte le glisser-deposer.
-- ====================================================

ns.RegisterModule("CenterPanel", {})

local built
local tbox, teamFS, slots = nil, nil, {}
local TOP_USED = 8 + 56 + 6 + 26 + 6
local ABIL_SIZE = 32
local COL = ns.Style.COL
local BREED_HEX = "|cff9a9aa6"
local NOTES_ICON = "Interface\\Icons\\INV_Icon_Daily_Mission_Scroll"

-- Couleur de la barre de vie : degrade vert (plein) -> jaune (moitie) -> rouge.
local function HpColor(r)
    r = math.max(0, math.min(1, r))
    if r >= 0.5 then
        local t = (r - 0.5) * 2            -- jaune -> vert
        return 0.90 - 0.72 * t, 0.78, 0.12 + 0.10 * t
    else
        local t = r * 2                    -- rouge -> jaune
        return 0.85 + 0.05 * t, 0.16 + 0.62 * t, 0.14
    end
end

-- ---- infobulles ----
local function ShowPetTip(owner, petID)
    if not petID then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetCompanionPet then GameTooltip:SetCompanionPet(petID) end
    GameTooltip:Show()
end
local function HidePetTip() GameTooltip:Hide() end

local function ShowAbilityTip(owner, abilityID, i)
    if not abilityID or not PetJournal_ShowAbilityTooltip then return end
    local speciesID = ns.Teams and ns.Teams.GetSlotSpecies(i)
    local petID = ns.Teams and ns.Teams.current.pets[i]
    PetJournal_ShowAbilityTooltip(owner, abilityID, speciesID, petID)
end
local function HideAbilityTip()
    if PetJournalPrimaryAbilityTooltip then PetJournalPrimaryAbilityTooltip:Hide() end
end

-- ---- menu de choix de sort (partage) ----
local flyout
local function EnsureFlyout()
    if flyout then return flyout end
    flyout = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    flyout:SetFrameStrata("TOOLTIP")
    ns.Style.Paint(flyout, { 0.04, 0.04, 0.05, 0.98 }, COL.border)
    flyout.btns = {}
    for c = 1, 2 do
        local b = CreateFrame("Button", nil, flyout)
        b:SetSize(30, 30)
        b:SetPoint("TOPLEFT", 4, -4 - (c - 1) * 34)
        b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.3)
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetPoint("TOPLEFT", -2, 2); b.check:SetPoint("BOTTOMRIGHT", 2, -2)
        b.check:SetColorTexture(1, 0.82, 0, 0)
        b:SetScript("OnEnter", function(self) ShowAbilityTip(self, self.abilityID, flyout.slot) end)
        b:SetScript("OnLeave", HideAbilityTip)
        b:SetScript("OnClick", function(self)
            ns.Teams.SetAbility(flyout.slot, flyout.tier, self.abilityID)
            flyout:Hide()
        end)
        flyout.btns[c] = b
    end
    flyout:SetWidth(38)
    -- Se ferme quand la souris quitte le menu et son ancre.
    flyout:SetScript("OnUpdate", function(self, e)
        self.t = (self.t or 0) + e
        if self.t < 0.1 then return end
        self.t = 0
        if not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end
    end)
    return flyout
end

local function ShowFlyout(anchor, i, tier)
    local choices = ns.Teams and ns.Teams.GetTierChoices(i, tier)
    if not choices or #choices < 2 then return end
    EnsureFlyout()
    flyout.slot, flyout.tier, flyout.anchor = i, tier, anchor
    local sel = ns.Teams.current.abil[i] and ns.Teams.current.abil[i][tier]
    for c = 1, 2 do
        local b, ch = flyout.btns[c], choices[c]
        b.abilityID = ch.id
        b.tex:SetTexture(ch.icon)
        b.check:SetColorTexture(1, 0.82, 0, (sel == ch.id) and 0.6 or 0)
    end
    flyout:SetHeight(4 + 2 * 34)
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, -2)
    flyout:Show()
end

-- ---- cible / equipe ----
local NAME_X, ARROW = 60, 22
local EMPTY = {}
-- Equipes du PNJ cible + index affiche (navigation par fleches).
local tgt = { npcID = nil, list = EMPTY, idx = 1 }

-- Affiche l'equipe courante de la liste + fleches si plusieurs equipes.
local function ShowTargetTeam()
    local team, n = tgt.list[tgt.idx], #tgt.list
    tbox.name:SetJustifyH(tgt.has and "LEFT" or "CENTER")
    if team then
        tbox.teamFS:SetText("|cff40e0d0" .. (team.name or "") .. "|r")
        tbox.loadBtn.team = team; tbox.loadBtn:Show()
    else
        tbox.teamFS:SetText(""); tbox.loadBtn:Hide()
    end
    local multi = n > 1
    tbox.prev:SetShown(multi); tbox.next:SetShown(multi); tbox.counter:SetShown(multi)
    if multi then tbox.counter:SetText(tgt.idx .. "/" .. n) end
    tbox.name:ClearAllPoints()
    if not tgt.has then
        -- Aucune cible : titre centre dans la boite.
        tbox.name:SetPoint("LEFT", tbox, "LEFT", 8, 0)
        tbox.name:SetPoint("RIGHT", tbox, "RIGHT", -8, 0)
        return
    end
    tbox.name:SetPoint("TOPLEFT", tbox, "TOPLEFT", NAME_X, -6)
    if multi then tbox.name:SetPoint("RIGHT", tbox.prev, "LEFT", -4, 0)
    else tbox.name:SetPoint("RIGHT", tbox, "RIGHT", -8, 0) end
end

local function StepTargetTeam(d)
    local n = #tgt.list
    if n < 2 then return end
    tgt.idx = (tgt.idx - 1 + d) % n + 1
    ShowTargetTeam()
end

local function UpdateTarget()
    if not tbox then return end
    local npcID
    if UnitExists("target") and not UnitIsPlayer("target") then
        tgt.has = true
        SetPortraitTexture(tbox.portrait, "target"); tbox.portrait:Show()
        tbox.name:SetFontObject("GameFontNormalLarge")
        tbox.name:SetText(UnitName("target")); tbox.name:SetTextColor(1, 0.82, 0)
        npcID = ns.Teams and ns.Teams.CurrentTargetNpcID()
    else
        tgt.has = false
        tbox.portrait:Hide()
        tbox.name:SetFontObject(ns.Style.TITLE_FONT)
        tbox.name:SetText(string.upper(ns.L("CENTER_NO_TARGET"))); tbox.name:SetTextColor(0.55, 0.45, 0.22)
    end
    local list = npcID and ns.Teams.FindAllByTarget(npcID) or EMPTY
    -- Meme PNJ : on garde l'equipe affichee ; sinon on se cale sur l'equipe chargee.
    local shown = tgt.list[tgt.idx]
    local want = (npcID == tgt.npcID and shown and shown.id) or (ns.Teams and ns.Teams.current.sourceTeamID)
    local idx = 1
    for i, t in ipairs(list) do
        if t.id == want then idx = i; break end
    end
    tgt.npcID, tgt.list, tgt.idx = npcID, list, idx
    ShowTargetTeam()
end

-- Nom localise d'un type de mascotte (donnee du jeu, pas une invention).
local function TypeName(t)
    return _G["BATTLE_PET_NAME_" .. t] or ("#" .. t)
end

-- Slot marque "aleatoire" : par type (Teams.PickRandomOfType) ou "XP" (Teams.
-- PickLevelingPet, pioche dans la file d'XP). Pas de pet precis avant
-- deploiement, mais l'apercu (lecture seule) utilise la MEME fonction de
-- selection que le vrai deploiement cote MatchScriptViewerLog, pour les deux
-- variantes : le nom reste "Aleatoire"/"XP" (le pet reel n'est fixe qu'au
-- deploiement) mais sa couleur, son niveau et son icone montrent ce qui
-- serait pris maintenant.
local function ShowRandom(slot, i, t)
    slot.hpBar:Hide(); slot.hpText:SetText("")
    for a = 1, 3 do slot.abilities[a].abilityID = nil; slot.abilities[a]:Hide() end

    if t == ns.RANDOM_XP then
        slot.typeIcon:Hide()
        -- Meme principe que le random par type juste en dessous : montre la
        -- mascotte qui serait reellement piochee dans la file d'XP au
        -- deploiement (Teams.PickLevelingPet, meme fonction que le vrai
        -- deploiement cote MatchScriptViewerLog), au lieu d'un libelle nu.
        local previewID = ns.Teams and ns.Teams.PickLevelingPet({})
        local info = previewID and ns.Teams.GetPetDisplay(previewID)
        if info then
            slot.icon:SetTexture(info.icon); slot.icon:Show()
            slot.level:SetText(info.level and ("|cffffd200" .. info.level .. "|r") or "")
            slot.breed:SetText(info.breed and (BREED_HEX .. info.breed .. "|r") or "")
            local q = info.rarity and ITEM_QUALITY_COLORS[info.rarity - 1]
            slot.name:SetText(ns.L("SLOT_RANDOM_XP"))
            if q then slot.name:SetTextColor(q.r, q.g, q.b) else slot.name:SetTextColor(0.55, 0.85, 0.55) end
            slot.empty:Hide()
        else
            slot.icon:Hide(); slot.level:SetText(""); slot.breed:SetText("")
            slot.name:SetText(ns.L("SLOT_RANDOM_XP")); slot.name:SetTextColor(0.55, 0.85, 0.55)
            slot.empty:SetText("|cff8fd3ff" .. ns.L("SLOT_RANDOM_XP") .. "|r"); slot.empty:Show()
        end
        return
    end

    -- type 0 = aleatoire tout type (import Rematch "random:0").
    local typeIndex = (t ~= 0) and t or nil
    if typeIndex and GetPetTypeTexture then
        slot.typeIcon:SetTexture(GetPetTypeTexture(typeIndex))
        slot.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
        slot.typeIcon:Show()
    else
        slot.typeIcon:Hide()
    end

    -- Candidat actuel : la mascotte qui serait reellement sortie maintenant.
    local previewID = ns.Teams and ns.Teams.PickRandomOfType(typeIndex)
    local info = previewID and ns.Teams.GetPetDisplay(previewID)

    if info then
        slot.icon:SetTexture(info.icon); slot.icon:Show()
        slot.level:SetText(info.level and ("|cffffd200" .. info.level .. "|r") or "")
        slot.breed:SetText(info.breed and (BREED_HEX .. info.breed .. "|r") or "")
        local q = info.rarity and ITEM_QUALITY_COLORS[info.rarity - 1]
        slot.name:SetText(ns.L("SLOT_RANDOM"))
        if q then slot.name:SetTextColor(q.r, q.g, q.b) else slot.name:SetTextColor(0.7, 0.85, 1) end
        slot.empty:Hide()
    else
        -- Aucune mascotte possedee de ce type : rien a previsualiser.
        slot.icon:Hide(); slot.level:SetText(""); slot.breed:SetText("")
        slot.name:SetText(ns.L("SLOT_RANDOM")); slot.name:SetTextColor(0.7, 0.85, 1)
        local label = typeIndex and TypeName(typeIndex) or ns.L("SLOT_RANDOM")
        slot.empty:SetText("|cff8fd3ff" .. label .. "|r"); slot.empty:Show()
    end
end

-- Slot "special" Rematch "ignore" : pas de mascotte exploitable, mais ce n'est
-- pas un slot vide non plus. Meme squelette que ShowRandom pour rester coherent
-- visuellement. (Le slot leveling est unifie sur le slot aleatoire "XP".)
local function ShowSpecial(slot)
    slot.icon:Hide(); slot.typeIcon:Hide()
    slot.level:SetText(""); slot.breed:SetText("")
    slot.hpBar:Hide(); slot.hpText:SetText("")
    for a = 1, 3 do slot.abilities[a].abilityID = nil; slot.abilities[a]:Hide() end
    local label = ns.L("SLOT_IGNORED")
    slot.name:SetText(label); slot.name:SetTextColor(0.7, 0.85, 1)
    slot.empty:SetText("|cff8fd3ff" .. label .. "|r"); slot.empty:Show()
end

-- Mascotte importee que le joueur NE POSSEDE PAS : on montre quand meme son
-- icone (grisee) + un cadenas + son nom, pour indiquer ce qui manque.
local function ShowUnowned(slot, u)
    local name, tex, petType = C_PetJournal.GetPetInfoBySpeciesID(u.species)
    slot.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    slot.icon:SetDesaturated(true); slot.icon:Show()
    slot.lock:Show()
    slot.level:SetText("")
    slot.name:SetText(name or "?"); slot.name:SetTextColor(0.7, 0.7, 0.7)
    slot.breed:SetText((u.breed and u.breed ~= "0") and (BREED_HEX .. u.breed .. "|r") or "")
    if petType and GetPetTypeTexture then
        slot.typeIcon:SetTexture(GetPetTypeTexture(petType))
        slot.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
        slot.typeIcon:Show()
    else
        slot.typeIcon:Hide()
    end
    slot.hpBar:Hide(); slot.hpText:SetText("")
    if slot.hpBar.spark then slot.hpBar.spark:Hide() end
    -- Attaques que la mascotte AURA une fois debloquee (grisees). Les icones de
    -- sort sont des donnees de jeu : disponibles meme sans posseder la mascotte.
    local list = C_PetJournal.GetPetAbilityList(u.species)
    for a = 1, 3 do
        local btn = slot.abilities[a]
        local id = u.abil and u.abil[a]
        if id and id ~= 0 then
            local _, aicon = C_PetJournal.GetPetAbilityInfo(id)
            btn.tex:SetTexture(aicon)
            btn.tex:SetDesaturated(true)
            btn.abilityID = id
            btn.choice:SetText(ns.Teams.AbilityChoice(list, a, id) or "")
            if btn.lock then btn.lock:Hide() end
            if btn.req then btn.req:Hide() end
            btn:Show()
        else
            btn.abilityID = nil
            btn:Hide()
        end
    end
    slot.empty:Hide()
end

local function RefreshSlot(i)
    local slot = slots[i]
    if not slot then return end
    slot.lock:Hide(); slot.icon:SetDesaturated(false)

    local rand = ns.Teams and ns.Teams.GetRandomType(i)
    if rand then slot.empty:SetText(ns.L("SLOT_EMPTY")); ShowRandom(slot, i, rand); return end

    local special = ns.Teams and ns.Teams.GetSpecialSlotType(i)
    if special then ShowSpecial(slot); return end

    local unowned = ns.Teams and ns.Teams.GetUnowned(i)
    if unowned then slot.empty:SetText(ns.L("SLOT_EMPTY")); ShowUnowned(slot, unowned); return end

    local petID = ns.Teams and ns.Teams.current.pets[i]
    local info = petID and ns.Teams.GetPetDisplay(petID)
    slot.empty:SetText(ns.L("SLOT_EMPTY"))
    if info then
        slot.icon:SetTexture(info.icon); slot.icon:Show()
        slot.level:SetText(info.level and ("|cffffd200" .. info.level .. "|r") or "")
        slot.name:SetText(info.name or "")
        local q = info.rarity and ITEM_QUALITY_COLORS[info.rarity - 1]
        if q then slot.name:SetTextColor(q.r, q.g, q.b) else slot.name:SetTextColor(1, 1, 1) end
        slot.breed:SetText(info.breed and (BREED_HEX .. info.breed .. "|r") or "")
        if info.petType and GetPetTypeTexture then
            slot.typeIcon:SetTexture(GetPetTypeTexture(info.petType))
            slot.typeIcon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
            slot.typeIcon:Show()
        else
            slot.typeIcon:Hide()
        end
        -- Barre de vie : PV actuels / max (visible apres un combat).
        local hp, hpMax = info.health or 0, info.maxHealth or 0
        slot.hpBar:SetMinMaxValues(0, hpMax > 0 and hpMax or 1)
        slot.hpBar:SetValue(hpMax > 0 and hp or 1)
        local ratio = hpMax > 0 and (hp / hpMax) or 1
        slot.hpBar:SetStatusBarColor(HpColor(ratio))
        -- Spark au bord du remplissage (masquee a 0% et 100%).
        if slot.hpBar.spark then
            if ratio > 0.02 and ratio < 0.98 then
                slot.hpBar.spark:ClearAllPoints()
                slot.hpBar.spark:SetPoint("CENTER", slot.hpBar, "LEFT", slot.hpBar:GetWidth() * ratio, 0)
                slot.hpBar.spark:Show()
            else
                slot.hpBar.spark:Hide()
            end
        end
        slot.hpBar:Show()
        slot.hpText:SetText(hpMax > 0 and (hp .. " / " .. hpMax) or "")
        local abil = ns.Teams.GetSlotAbilities(i)
        -- Niveau requis par sort (levelList de l'API), pour verrouiller les
        -- sorts que le niveau de la mascotte ne permet pas encore.
        local reqByID
        local speciesID = ns.Teams.GetSlotSpecies(i)
        if speciesID then
            local ids, lvls = C_PetJournal.GetPetAbilityList(speciesID)
            if ids and lvls then
                reqByID = {}
                for k = 1, #ids do reqByID[ids[k]] = lvls[k] end
            end
        end
        for a = 1, 3 do
            local ab = abil and abil[a]
            local btn = slot.abilities[a]
            if ab and ab.icon then
                btn.tex:SetTexture(ab.icon)
                btn.abilityID = ab.id
                btn.choice:SetText(ab.choice or "")
                local req = reqByID and reqByID[ab.id]
                local locked = req and info.level and info.level < req
                btn.tex:SetDesaturated(locked and true or false)
                btn.lock:SetShown(locked and true or false)
                if locked then btn.req:SetText(req); btn.req:Show() else btn.req:Hide() end
                btn:Show()
            else
                btn.abilityID = nil
                btn:Hide()
            end
        end
        slot.empty:Hide()
    else
        slot.icon:Hide(); slot.typeIcon:Hide(); slot.hpBar:Hide()
        slot.level:SetText(""); slot.name:SetText(""); slot.breed:SetText(""); slot.hpText:SetText("")
        for a = 1, 3 do slot.abilities[a]:Hide() end
        slot.empty:Show()
    end
end

local function RefreshAll()
    if teamFS then
        local n = ns.Teams and ns.Teams.current.name
        teamFS:SetText(n or ns.L("CENTER_NO_TEAM"))
    end
    for i = 1, 3 do RefreshSlot(i) end
end

local function Relayout()
    local center = ns.Frame and ns.Frame.center
    if not center or not slots[1] then return end
    local avail = center:GetHeight() - TOP_USED - 8
    local gap = 8
    local slotH = math.floor((avail - 2 * gap) / 3)
    if slotH < 60 then slotH = 60 end
    for i = 1, 3 do
        local s = slots[i]
        local y = TOP_USED + (i - 1) * (slotH + gap)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", center, "TOPLEFT", 8, -y)
        s:SetPoint("TOPRIGHT", center, "TOPRIGHT", -8, -y)
        s:SetHeight(slotH)
        -- Barre de vie : tout l'espace entre l'icone et les 3 sorts.
        s.hpBar:SetWidth(math.max(40, center:GetWidth() - 16 - 16 - 8 - (3 * ABIL_SIZE + 8)))
    end
end

local function OnSlotReceive(i)
    local kind, id = GetCursorInfo()
    if kind == "battlepet" and id then ns.Teams.SetSlot(i, id); ClearCursor() end
end

local function MakeBox(parent, h)
    local b = ns.Style.Box(parent, { 0.04, 0.04, 0.05, 1 }, COL.edge)
    if h then b:SetHeight(h) end
    return b
end

-- Clic gauche/depot = poser un pet ; clic droit = faire defiler le type aleatoire.
local function OnSlotClick(i, button)
    if button ~= "RightButton" and SpellIsTargeting() and C_PetJournal.SpellTargetBattlePet then
        local petID = ns.Teams.current.pets[i]
        if type(petID) == "string" and petID:find("^BattlePet") then
            C_PetJournal.SpellTargetBattlePet(petID)
            return
        end
    end
    if button == "RightButton" then
        ns.Teams.CycleRandom(i)
    else
        OnSlotReceive(i)
    end
end

local function BuildSlot(center, i)
    local slot = MakeBox(center)
    slot:EnableMouse(true)
    slot:SetScript("OnMouseUp", function(_, button) OnSlotClick(i, button) end)
    slot:SetScript("OnReceiveDrag", function() OnSlotReceive(i) end)

    -- Icone = bouton (infobulle mascotte + depot).
    local iconBtn = CreateFrame("Button", nil, slot)
    iconBtn:SetSize(36, 36); iconBtn:SetPoint("TOPLEFT", 8, -8)
    iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    iconBtn:SetScript("OnEnter", function(self) ShowPetTip(self, ns.Teams.current.pets[i]) end)
    iconBtn:SetScript("OnLeave", HidePetTip)
    iconBtn:SetScript("OnReceiveDrag", function() OnSlotReceive(i) end)
    iconBtn:SetScript("OnMouseUp", function(_, button) OnSlotClick(i, button) end)
    slot.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints(); slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Cadenas : mascotte importee mais non possedee (affiche par ShowUnowned).
    slot.lock = iconBtn:CreateTexture(nil, "OVERLAY")
    slot.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    slot.lock:SetSize(22, 22); slot.lock:SetPoint("CENTER"); slot.lock:Hide()

    slot.name = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.name:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 8, -3)
    slot.name:SetJustifyH("LEFT"); slot.name:SetWordWrap(false)

    -- Niveau a droite du type (element le plus a droite de l'en-tete du slot).
    slot.level = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.level:SetWidth(22); slot.level:SetJustifyH("CENTER")
    slot.level:SetPoint("TOPRIGHT", -6, -10)

    slot.typeIcon = slot:CreateTexture(nil, "OVERLAY")
    slot.typeIcon:SetSize(18, 18)
    slot.typeIcon:SetPoint("RIGHT", slot.level, "LEFT", -3, 0)
    slot.name:SetPoint("RIGHT", slot.typeIcon, "LEFT", -4, 0)

    slot.breed = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slot.breed:SetPoint("TOPLEFT", slot.name, "BOTTOMLEFT", 0, -4)

    slot.hpBar = CreateFrame("StatusBar", nil, slot, "BackdropTemplate")
    slot.hpBar:SetSize(96, 14); slot.hpBar:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -8)
    slot.hpBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    slot.hpBar:SetStatusBarColor(0.20, 0.75, 0.25); slot.hpBar:SetMinMaxValues(0, 1); slot.hpBar:SetValue(1)
    -- Cadre fin + fond assombri (aspect plus net que la barre nue).
    slot.hpBar:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    slot.hpBar:SetBackdropBorderColor(0, 0, 0, 0.9)
    local hpBg = slot.hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetPoint("TOPLEFT", 1, -1); hpBg:SetPoint("BOTTOMRIGHT", -1, 1)
    hpBg:SetColorTexture(0.07, 0.08, 0.10, 0.95)
    -- Reflet en haut de la barre (leger degrade vers le clair).
    local hpGloss = slot.hpBar:CreateTexture(nil, "OVERLAY")
    hpGloss:SetPoint("TOPLEFT", 1, -1); hpGloss:SetPoint("TOPRIGHT", -1, -1); hpGloss:SetHeight(6)
    hpGloss:SetColorTexture(1, 1, 1, 0.10)
    -- Spark au bord du remplissage.
    slot.hpBar.spark = slot.hpBar:CreateTexture(nil, "OVERLAY")
    slot.hpBar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    slot.hpBar.spark:SetBlendMode("ADD"); slot.hpBar.spark:SetSize(10, 20); slot.hpBar.spark:Hide()
    slot.hpText = slot.hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); slot.hpText:SetPoint("CENTER")
    slot.hpText:SetShadowColor(0, 0, 0, 1); slot.hpText:SetShadowOffset(1, -1)

    slot.abilities = {}
    for a = 1, 3 do
        local ab = CreateFrame("Button", nil, slot)
        ab:SetSize(ABIL_SIZE, ABIL_SIZE)
        if a == 1 then ab:SetPoint("LEFT", slot.hpBar, "RIGHT", 8, 0)
        else ab:SetPoint("LEFT", slot.abilities[a - 1], "RIGHT", 4, 0) end
        ab.tex = ab:CreateTexture(nil, "ARTWORK"); ab.tex:SetAllPoints(); ab.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = ab:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.3)
        -- Sort verrouille (niveau de la mascotte insuffisant) : cadenas + niveau requis.
        ab.lock = ab:CreateTexture(nil, "OVERLAY")
        ab.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
        ab.lock:SetSize(16, 16); ab.lock:SetPoint("CENTER"); ab.lock:Hide()
        ab.req = ab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ab.req:SetPoint("TOPRIGHT", 1, 0); ab.req:SetTextColor(1, 0.2, 0.2); ab.req:Hide()
        -- Rang du sort dans son palier (1 ou 2), bas droite.
        ab.choice = ab:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        ab.choice:SetPoint("BOTTOMRIGHT", -1, 1)
        -- Fleche vers le bas (au survol).
        ab.arrow = ab:CreateTexture(nil, "OVERLAY")
        ab.arrow:SetSize(12, 12); ab.arrow:SetPoint("BOTTOM", 0, -2)
        ab.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up"); ab.arrow:Hide()
        ab:SetScript("OnEnter", function(self)
            self.arrow:Show()
            ShowAbilityTip(self, self.abilityID, i)
        end)
        ab:SetScript("OnLeave", function(self) self.arrow:Hide(); HideAbilityTip() end)
        ab:SetScript("OnClick", function(self) ShowFlyout(self, i, a) end)
        slot.abilities[a] = ab
    end

    slot.empty = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slot.empty:SetPoint("CENTER"); slot.empty:SetText(ns.L("SLOT_EMPTY"))
    return slot
end

local function Build()
    if built then return end
    local center = ns.Frame and ns.Frame.center
    if not center then return end
    built = true

    local box = MakeBox(center, 56)
    box:SetBackdropColor(unpack(COL.bg)); box:SetBackdropBorderColor(unpack(COL.border))
    box:SetPoint("TOPLEFT", 8, -8); box:SetPoint("TOPRIGHT", -8, -8)
    tbox = box
    box.portrait = box:CreateTexture(nil, "ARTWORK")
    box.portrait:SetSize(40, 40); box.portrait:SetPoint("LEFT", 8, 0); box.portrait:Hide()
    box.name = box:CreateFontString(nil, "OVERLAY", ns.Style.TITLE_FONT)
    box.name:SetJustifyH("CENTER")
    box.name:SetText(string.upper(ns.L("CENTER_NO_TARGET"))); box.name:SetTextColor(0.55, 0.45, 0.22)
    box.teamFS = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.teamFS:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -4)

    -- Fleches (haut droite) : changer d'equipe quand le PNJ en a plusieurs.
    local function MakeArrow(kind, tip, d)
        local b = CreateFrame("Button", nil, box)
        b:SetSize(ARROW, ARROW)
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function() StepTargetTeam(d) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(ns.L(tip)); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        return b
    end
    box.next = MakeArrow("Next", "CENTER_NEXT_TEAM", 1)
    box.next:SetPoint("TOPRIGHT", -4, -4)
    box.counter = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.counter:SetWidth(30); box.counter:SetJustifyH("CENTER")
    box.counter:SetPoint("RIGHT", box.next, "LEFT", 0, 0); box.counter:Hide()
    box.prev = MakeArrow("Prev", "CENTER_PREV_TEAM", -1)
    box.prev:SetPoint("RIGHT", box.counter, "LEFT", 0, 0)
    box.loadBtn = ns.Style.Button(box, ns.L("CENTER_DEPLOY"), 64, 18, {
        bg = COL.card, border = COL.border, text = COL.gold,
    })
    box.loadBtn:SetPoint("BOTTOMRIGHT", -6, 5)
    box.loadBtn:Hide()
    box.loadBtn:SetScript("OnClick", function(self)
        if self.team and ns.Teams then ns.Teams.Load(self.team) end
    end)

    local teamBar = MakeBox(center, 26)
    teamBar:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6); teamBar:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -6)
    teamBar:SetBackdropColor(0.12, 0.09, 0.09, 1); teamBar:SetBackdropBorderColor(0.45, 0.20, 0.20, 1)
    -- Notes de la team : bouton a droite du nom (fenetre NotesDialog).
    local notesBtn = CreateFrame("Button", nil, teamBar)
    notesBtn:SetSize(20, 20); notesBtn:SetPoint("RIGHT", -4, 0)
    local notesIcon = notesBtn:CreateTexture(nil, "ARTWORK")
    notesIcon:SetAllPoints(); notesIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    notesIcon:SetTexture(NOTES_ICON)
    local notesHl = notesBtn:CreateTexture(nil, "HIGHLIGHT"); notesHl:SetAllPoints(); notesHl:SetColorTexture(1, 1, 1, 0.25)
    notesBtn:SetScript("OnClick", function() if ns.NotesDialog then ns.NotesDialog.Toggle() end end)
    notesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText(ns.L("NOTES_BTN_TIP")); GameTooltip:Show()
    end)
    notesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    teamFS = teamBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    teamFS:SetPoint("LEFT", 8, 0); teamFS:SetPoint("RIGHT", notesBtn, "LEFT", -4, 0)
    teamFS:SetJustifyH("CENTER"); teamFS:SetWordWrap(false)
    teamFS:SetText(ns.L("CENTER_NO_TEAM"))

    for i = 1, 3 do slots[i] = BuildSlot(center, i) end
    Relayout()
    center:HookScript("OnSizeChanged", Relayout)
    RefreshAll(); UpdateTarget()
end

ns.On("MVL_FRAME_READY", Build)
ns.On("MVL_FRAME_SHOW", function() if built then Relayout(); RefreshAll() end end)
ns.On("TEAM_LOADED", RefreshAll)
ns.RegisterWowEvent("PLAYER_TARGET_CHANGED", UpdateTarget)
ns.On("TEAMS_CHANGED", UpdateTarget)
-- Les PV changent apres un combat : on rafraichit les barres de vie.
ns.RegisterWowEvent("PET_BATTLE_CLOSE", function() if built then RefreshAll() end end)
ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", function() if built then RefreshAll() end end)
