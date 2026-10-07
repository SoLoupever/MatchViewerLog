local addonName, ns = ...

-- ====================================================
-- TEAMSTORE — equipe en cours d'edition (3 slots) + sauvegarde. Gere aussi
-- la selection de sorts par slot (chaque palier a 2 choix) et les slots
-- "aleatoires par type". Voir aussi, tous extraits de ce fichier et
-- attaches au meme ns.Teams : TeamQueue (file d'XP), TeamTargets (dompteurs),
-- TeamLoadout (sync loadout Blizzard), TeamResolve (matching import +
-- resolution "non possede"), TeamCaging (repli mise en cage) et
-- TeamMigrations (migrations one-shot). La selection de mascotte epinglee
-- (ns.SetSelectedPet) vit a part, dans fonctionnalite/Selection.lua.
-- ====================================================

local Teams = ns.RegisterModule("TeamStore", {})
ns.Teams = Teams

-- random[i] = 1..10 : le slot i est un pet aleatoire de ce type (prioritaire
-- sur pets[i] pour l'affichage/deploiement).
-- special[i] = "leveling"/"ignored" : slot Rematch sans petID exploitable
-- (mascotte en montee de niveau ou emplacement volontairement ignore).
-- Purement informatif pour l'affichage, ne remplace pas random.
Teams.current = { pets = {}, abil = {}, abilAll = {}, random = {}, special = {}, unowned = {}, name = nil, category = nil, sourceTeamID = nil }

-- Palier t : choix par defaut list[t], alternative list[t+3].
local function ComputeAbil(petID)
    if type(petID) ~= "string" or not petID:find("^BattlePet") then return nil, nil end
    local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
    if not speciesID then return nil, nil end
    local list = C_PetJournal.GetPetAbilityList(speciesID)
    if type(list) ~= "table" then return nil, nil end
    return { list[1], list[2], list[3] }, list
end

-- Copie plate des sorts choisis (pour sauvegarde/export).
local function CaptureAbil()
    local c, out = Teams.current, {}
    for i = 1, 3 do
        if c.abil[i] then out[i] = { c.abil[i][1], c.abil[i][2], c.abil[i][3] } end
    end
    return out
end

-- Copie plate des types aleatoires.
local function CaptureRandom()
    local c, out = Teams.current, {}
    for i = 1, 3 do out[i] = c.random[i] end
    return out
end

-- Copie plate des marqueurs "special" (leveling/ignored).
local function CaptureSpecial()
    local c, out = Teams.current, {}
    for i = 1, 3 do out[i] = c.special[i] end
    return out
end

-- Copie plate des emplacements "non possede" (importes ou mis en cage).
local function CaptureUnowned()
    local c, out = Teams.current, {}
    for i = 1, 3 do
        local u = c.unowned[i]
        if u then
            out[i] = { species = u.species, breed = u.breed,
                       abil = u.abil and { u.abil[1], u.abil[2], u.abil[3] } or nil }
        end
    end
    return out
end

-- Le slot Rematch "montee de niveau" (special="leveling") fait doublon avec le
-- slot aleatoire "XP" (random=RANDOM_XP) : meme intention, pioche dans la file
-- d'XP au deploiement. On unifie sur RANDOM_XP ; seul "ignored" reste special.
-- Idempotent : rien a faire s'il n'y a aucun marqueur "leveling".
local function NormalizeLeveling(random, special)
    if type(special) ~= "table" then return end
    for i = 1, 3 do
        if special[i] == "leveling" then
            if type(random) == "table" and not random[i] then random[i] = ns.RANDOM_XP end
            special[i] = nil
        end
    end
end
-- Exposee pour TeamMigrations.lua (meme normalisation, pas de doublon).
Teams.NormalizeLeveling = NormalizeLeveling

-- Infos visuelles d'une mascotte (petID GUID). nil si non affichable.
function Teams.GetPetDisplay(petID)
    if type(petID) ~= "string" or not petID:find("^BattlePet") then return nil end
    local speciesID, customName, level, _, _, _, _, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
    if not name then return nil end
    local health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID)
    return {
        name      = customName or name,
        icon      = icon,
        level     = level,
        petType   = petType,
        breed     = ns.Breed and ns.Breed.GetForPetID(petID) or nil,
        health    = health,
        maxHealth = maxHealth,
        rarity    = rarity,
    }
end

-- Meilleure mascotte possedee pour un slot "aleatoire par type" : plus haut
-- niveau d'abord, puis plus haute rarete a niveau egal (meme logique que le
-- choix aleatoire de Rematch, cf. randomPets.lua GetPetIDWeight). Source
-- unique : utilisee pour l'apercu (CenterPanel) ET le vrai deploiement
-- (MatchScriptViewerLog via l'API publique), pour que les deux soient
-- toujours coherents entre eux.
--
-- Cache par type le temps que le roster ne change pas (meme principe que
-- PetCard.lua collectedCache) : evite de rescanner tout le journal a chaque
-- rafraichissement du panneau central. Uniquement pour l'apercu (excluded
-- nil) ; un deploiement reel (excluded fourni) n'est jamais mis en cache.
local randomPickCache = {}
ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", function() wipe(randomPickCache) end)

-- typeIndex nil/0 = tout type. excluded = table optionnelle {petID=true}.
function Teams.PickRandomOfType(typeIndex, excluded)
    if typeIndex == 0 then typeIndex = nil end
    if not excluded then
        local cacheKey = typeIndex or 0
        local cached = randomPickCache[cacheKey]
        if cached ~= nil then return cached or nil end
    end
    local pool, bestLevel, bestRarity = {}, 0, 0
    local num = C_PetJournal.GetNumPets() or 0
    for i = 1, num do
        local pid, _, isOwned, _, level, _, _, _, _, petType = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and pid and (not excluded or not excluded[pid]) and (not typeIndex or petType == typeIndex) then
            level = level or 0
            local _, _, _, _, rarity = C_PetJournal.GetPetStats(pid)
            rarity = rarity or 0
            if level > bestLevel or (level == bestLevel and rarity > bestRarity) then
                wipe(pool)
                pool[1] = pid
                bestLevel, bestRarity = level, rarity
            elseif level == bestLevel and rarity == bestRarity then
                pool[#pool + 1] = pid
            end
        end
    end
    local result = (#pool > 0) and pool[math.random(#pool)] or nil
    if not excluded then randomPickCache[typeIndex or 0] = result or false end
    return result
end

-- Rang du sort dans son palier : 1 = list[t], 2 = list[t+3] (nil si inconnu).
function Teams.AbilityChoice(list, tier, id)
    if not list or not id then return nil end
    if id == list[tier] then return 1 end
    if id == list[tier + 3] then return 2 end
end

-- Icones/noms des 3 sorts selectionnes d'un slot (+ l'alternative).
function Teams.GetSlotAbilities(i)
    local sel, all = Teams.current.abil[i], Teams.current.abilAll[i]
    if not sel then return nil end
    local out = {}
    for t = 1, 3 do
        local id = sel[t]
        if id then
            local aname, aicon = C_PetJournal.GetPetAbilityInfo(id)
            local altID = all and ((sel[t] == all[t]) and all[t + 3] or all[t]) or nil
            out[t] = { id = id, icon = aicon, name = aname, altID = altID, choice = Teams.AbilityChoice(all, t, id) }
        end
    end
    return out
end

-- Les 2 choix d'un palier (pour le menu de selection).
function Teams.GetTierChoices(i, tier)
    local all = Teams.current.abilAll[i]
    if not all then return nil end
    local out = {}
    for _, id in ipairs({ all[tier], all[tier + 3] }) do
        if id then
            local aname, aicon = C_PetJournal.GetPetAbilityInfo(id)
            out[#out + 1] = { id = id, icon = aicon, name = aname }
        end
    end
    return out
end

-- Fixe le sort d'un palier.
function Teams.SetAbility(i, tier, abilityID)
    local sel = Teams.current.abil[i]
    if not sel then return end
    sel[tier] = abilityID
    ns.Fire("TEAM_LOADED")
end

-- speciesID de la mascotte d'un slot (pour l'infobulle de sort).
function Teams.GetSlotSpecies(i)
    local petID = Teams.current.pets[i]
    if type(petID) ~= "string" then return nil end
    return C_PetJournal.GetPetInfoByPetID(petID)
end

-- Type aleatoire d'un slot, ou nil.
function Teams.GetRandomType(i)
    return Teams.current.random[i]
end

-- Mascotte NON POSSEDEE d'un slot (importee mais absente de la collection),
-- ou nil. { species = speciesID, breed = "S/S" }.
function Teams.GetUnowned(i)
    return Teams.current.unowned[i]
end

-- "leveling"/"ignored" si le slot vient d'un emplacement special Rematch
-- sans petID exploitable, sinon nil (slot vraiment vide ou pet normal).
function Teams.GetSpecialSlotType(i)
    return Teams.current.special[i]
end

-- Clic droit sur un slot : fait defiler nil -> types 1..10 -> "XP aleatoire"
-- (pioche dans la file d'XP au deploiement) -> nil.
function Teams.CycleRandom(i)
    if i < 1 or i > 3 then return end
    local cur = Teams.current.random[i]
    local nextVal
    if cur == nil then
        nextVal = 1
    elseif cur == ns.RANDOM_XP then
        nextVal = nil
    elseif type(cur) == "number" and cur < ns.NUM_PET_TYPES then
        nextVal = cur + 1
    else
        nextVal = ns.RANDOM_XP   -- apres le dernier type
    end
    Teams.current.random[i] = nextVal
    ns.Fire("TEAM_LOADED")
end

function Teams.Load(team)
    local c = Teams.current
    wipe(c.pets); wipe(c.abil); wipe(c.abilAll); wipe(c.random); wipe(c.special); wipe(c.unowned)
    for i = 1, 3 do
        c.pets[i] = team.pets and team.pets[i] or nil
        local def, all = ComputeAbil(c.pets[i])
        c.abilAll[i] = all
        c.abil[i] = (team.abil and team.abil[i]) or def
        c.random[i] = team.random and team.random[i] or nil
        c.special[i] = team.special and team.special[i] or nil
        c.unowned[i] = team.unowned and team.unowned[i] or nil
    end
    NormalizeLeveling(c.random, c.special)
    c.name, c.category, c.sourceTeamID = team.name, team.category, team.id
    Teams.ResetResolved()
    ns.Fire("TEAM_LOADED")
end

function Teams.SetSlot(i, petID)
    if i < 1 or i > 3 then return end
    Teams.current.pets[i] = petID
    Teams.current.random[i] = nil   -- un pet precis remplace l'aleatoire
    Teams.current.special[i] = nil  -- ... et remplace aussi un marqueur special
    Teams.current.unowned[i] = nil  -- ... et remplace un emplacement "non possede"
    Teams.current.abil[i], Teams.current.abilAll[i] = ComputeAbil(petID)
    ns.Fire("TEAM_LOADED")
end

function Teams.HasPets()
    for i = 1, 3 do
        if Teams.current.pets[i] or Teams.current.random[i] then return true end
    end
    return false
end

function Teams.Save(name, category)
    local c = Teams.current
    local pets = {}
    for i = 1, 3 do pets[i] = c.pets[i] end
    ns.DB._teamCounter = (ns.DB._teamCounter or 0) + 1
    local id = "mvl:" .. ns.DB._teamCounter
    local cat = category or c.category or "group:none"
    -- Dompteur regarde au moment de l'enregistrement : la team lui est
    -- associee (nil si pas de cible), exactement comme un import xufu avec
    -- cible. Teams.FindAllByTarget la ressort ensuite quand on recible ce PNJ.
    local target = Teams.CurrentTargetNpcID()
    ns.DB.teams[id] = {
        id = id, name = name, pets = pets,
        abil = CaptureAbil(), random = CaptureRandom(), special = CaptureSpecial(),
        unowned = CaptureUnowned(),
        category = cat, target = target,
        source = "mvl", srcKey = (name or ""):lower() .. "|user:" .. id,
    }
    c.sourceTeamID, c.name, c.category = id, name, cat
    -- TEAM_SAVED avant TEAMS_CHANGED : le panneau droit deplie la categorie
    -- cible sur ce signal, pour que la team soit visible immediatement (au
    -- lieu de sembler "disparue" dans une categorie repliee, ex. "Aucune
    -- categorie" la toute premiere fois qu'elle est utilisee).
    ns.Fire("TEAM_SAVED", id, cat)
    ns.Fire("TEAMS_CHANGED"); ns.Fire("TEAM_LOADED")
    return id
end

function Teams.Replace()
    local c = Teams.current
    local id = c.sourceTeamID
    if not id or not ns.DB.teams[id] then return false end
    local pets = {}
    for i = 1, 3 do pets[i] = c.pets[i] end
    local t = ns.DB.teams[id]
    t.pets = pets
    t.abil = CaptureAbil()
    t.random = CaptureRandom()
    t.special = CaptureSpecial()
    t.unowned = CaptureUnowned()
    ns.Fire("TEAMS_CHANGED")
    return true
end

-- Renomme et/ou deplace (change de categorie) une equipe enregistree.
function Teams.SetInfo(id, name, category)
    local t = id and ns.DB and ns.DB.teams[id]
    if not t then return false end
    if name and name ~= "" then t.name = name end
    if category then t.category = category end
    -- Repercute sur l'equipe chargee si c'est la meme.
    if Teams.current.sourceTeamID == id then
        if name and name ~= "" then Teams.current.name = name end
        if category then Teams.current.category = category end
    end
    -- Meme signal que Save : la categorie de destination se deplie (cf. Save).
    if category then ns.Fire("TEAM_SAVED", id, category) end
    ns.Fire("TEAMS_CHANGED")
    return true
end

-- Bascule le flag favori d'une equipe enregistree (menu clic droit). Categorie
-- virtuelle "group:favorites" cote affichage (Categories.TeamsIn/CountTeams) :
-- pas un champ category, ce flag est la seule ecriture correspondante.
function Teams.ToggleFavorite(id)
    local t = id and ns.DB and ns.DB.teams[id]
    if not t then return false end
    t.favorite = (not t.favorite) or nil
    ns.Fire("TEAMS_CHANGED")
    return t.favorite and true or false
end

-- Supprime une equipe enregistree.
function Teams.Delete(id)
    if not id or not ns.DB or not ns.DB.teams[id] then return false end
    ns.DB.teams[id] = nil
    if Teams.current.sourceTeamID == id then Teams.current.sourceTeamID = nil end
    ns.Fire("TEAMS_CHANGED")
    return true
end

-- Cree une equipe enregistree a partir de donnees explicites (import).
-- silent : n'emet pas TEAMS_CHANGED (import par lot, ex. categorie entiere,
-- qui emet un seul signal a la fin au lieu d'un par equipe).
function Teams.CreateStored(data, silent)
    if not ns.DB then return nil end
    ns.DB._teamCounter = (ns.DB._teamCounter or 0) + 1
    local id = "mvl:" .. ns.DB._teamCounter
    data.random = data.random or {}
    data.special = data.special or {}
    NormalizeLeveling(data.random, data.special)
    ns.DB.teams[id] = {
        id = id, name = data.name or "?",
        pets = data.pets or {}, abil = data.abil or {}, random = data.random, special = data.special,
        unowned = data.unowned or {},
        category = data.category or "group:none",
        target = (data.targets and data.targets[1]) or data.target or nil,
        targets = data.targets or nil,
        source = "import", srcKey = (data.name or ""):lower() .. "|import:" .. id,
    }
    if not silent then ns.Fire("TEAMS_CHANGED") end
    return id
end

-- ---- Persistance de l'equipe en cours (garde la derniere utilisee) ----
function Teams.SaveState()
    if not ns.DB then return end
    local c = Teams.current
    local pets = {}
    for i = 1, 3 do pets[i] = c.pets[i] end
    ns.DB.settings.lastTeam = {
        pets = pets, abil = CaptureAbil(), random = CaptureRandom(), special = CaptureSpecial(),
        unowned = CaptureUnowned(),
        name = c.name, category = c.category, sourceTeamID = c.sourceTeamID,
    }
end

function Teams.RestoreState()
    if not ns.DB then return end
    local s = ns.DB.settings.lastTeam
    if not s then return end
    local c = Teams.current
    wipe(c.pets); wipe(c.abil); wipe(c.abilAll); wipe(c.random); wipe(c.special); wipe(c.unowned)
    for i = 1, 3 do
        c.pets[i] = s.pets and s.pets[i] or nil
        local _, all = ComputeAbil(c.pets[i])
        c.abilAll[i] = all
        c.abil[i] = (s.abil and s.abil[i]) or (all and { all[1], all[2], all[3] }) or nil
        c.random[i] = s.random and s.random[i] or nil
        c.special[i] = s.special and s.special[i] or nil
        c.unowned[i] = s.unowned and s.unowned[i] or nil
    end
    NormalizeLeveling(c.random, c.special)
    c.name, c.category, c.sourceTeamID = s.name, s.category, s.sourceTeamID
    ns.Fire("TEAM_LOADED")
end

ns.On("TEAM_LOADED", Teams.SaveState)
