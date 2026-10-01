local addonName, ns = ...

-- ====================================================
-- TEAMRESOLVE — retrouve un petID possede correspondant a une espece/breed
-- importee (matching), et resout automatiquement les emplacements "non
-- possede" des qu'un joueur obtient l'espece qui manquait. Extrait de
-- TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- Balaye la liste courante du journal a la recherche du meilleur petID de
-- l'espece. Respecte les filtres UI actifs : ne trouve pas une espece masquee
-- par un filtre de type/recherche.
-- Si un breed precis est demande ET detectable (BattlePetBreedID installe),
-- le match est STRICT : un exemplaire du mauvais breed n'est pas candidat,
-- meme si c'est le seul possede. Sans BattlePetBreedID (breed indetectable)
-- ou si le code importe ne demande pas de breed ("0"), on garde l'ancien
-- classement par rarete puis niveau, faute de mieux.
local function ScanForOwned(speciesID, breedStr)
    local wantBreed = breedStr and breedStr ~= "0" and ns.Breed and ns.Breed.IsAvailable()
    local best, bestScore
    local num = C_PetJournal.GetNumPets() or 0
    for i = 1, num do
        local pid, sp, isOwned, _, level = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and sp == speciesID and pid and (not wantBreed or ns.Breed.GetForPetID(pid) == breedStr) then
            local _, _, _, _, rarity = C_PetJournal.GetPetStats(pid)
            local score = (rarity or 0) * 100 + (level or 0)
            if not bestScore or score > bestScore then best, bestScore = pid, score end
        end
    end
    return best
end

-- Evite les balayages "sans filtre" imbriques : le fait de toucher aux filtres
-- declenche PET_JOURNAL_LIST_UPDATE, qui pourrait relancer une resolution.
local inFullScan = false

-- Cherche un petID possede de l'espece donnee (et du breed exact si demande
-- et detectable, voir ScanForOwned). D'abord dans la liste filtree courante ;
-- si introuvable alors que l'espece est bien collectee, on neutralise
-- temporairement les filtres (type + recherche) pour la retrouver, puis on les
-- restaure. nil si l'espece n'est pas collectee, OU si elle l'est mais pas
-- dans le breed exact demande -> l'appelant traite ca comme "non possede"
-- (meme circuit que TeamShare.ApplyPayload/ResolveTeamUnowned).
function Teams.FindOwnedPet(speciesID, breedStr)
    if not speciesID then return nil end
    local pid = ScanForOwned(speciesID, breedStr)
    if pid then return pid end
    -- Rien dans la vue filtree : l'espece est-elle possedee mais masquee ?
    if inFullScan then return nil end
    local collected = C_PetJournal.GetNumCollectedInfo(speciesID)
    if not collected or collected <= 0 then return nil end
    inFullScan = true
    -- Sauvegarde l'etat des filtres de type puis tout ouvrir.
    local numTypes = C_PetJournal.GetNumPetTypes() or 0
    local saved = {}
    for t = 1, numTypes do saved[t] = C_PetJournal.IsPetTypeChecked(t) end
    C_PetJournal.SetAllPetTypesChecked(true)
    C_PetJournal.SetSearchFilter("")
    pid = ScanForOwned(speciesID, breedStr)
    -- Restaure la recherche et chaque filtre de type.
    C_PetJournal.SetSearchFilter(ns.petSearchText or "")
    for t = 1, numTypes do C_PetJournal.SetPetTypeFilter(t, saved[t]) end
    inFullScan = false
    return pid
end

-- Resout un emplacement "non possede" en vraie mascotte quand le joueur l'a
-- obtenue : on la place dans le slot, on rebranche ses attaques importees, et
-- si elle n'est pas au niveau max on l'ajoute a la file d'XP.
local function ResolveTeamUnowned(t)
    if type(t.unowned) ~= "table" then return false end
    local changed = false
    for i = 1, 3 do
        local u = t.unowned[i]
        if u and u.species then
            local pid = Teams.FindOwnedPet(u.species, u.breed)
            if pid then
                t.pets = t.pets or {}
                t.pets[i] = pid
                if u.abil and (u.abil[1] or u.abil[2] or u.abil[3]) then
                    t.abil = t.abil or {}
                    t.abil[i] = { u.abil[1] ~= 0 and u.abil[1] or nil,
                                  u.abil[2] ~= 0 and u.abil[2] or nil,
                                  u.abil[3] ~= 0 and u.abil[3] or nil }
                end
                t.unowned[i] = nil
                local lvl = select(3, C_PetJournal.GetPetInfoByPetID(pid))
                if lvl and lvl < ns.MAX_PET_LEVEL then Teams.QueueAdd(pid) end
                changed = true
            end
        end
    end
    return changed
end

-- Balaye toutes les equipes quand le roster change (mascotte obtenue) : les
-- emplacements verrouilles se remplissent d'eux-memes des qu'on a la mascotte.
local resolving = false
function Teams.ResolveAllUnowned()
    if resolving then return end
    if not (ns.DB and ns.DB.teams) then return end
    resolving = true
    local curId, curChanged, any = Teams.current.sourceTeamID, false, false
    for id, t in pairs(ns.DB.teams) do
        if ResolveTeamUnowned(t) then
            any = true
            if id == curId then curChanged = true end
        end
    end
    resolving = false
    if any then ns.Fire("TEAMS_CHANGED") end
    if curChanged and ns.DB.teams[curId] then Teams.Load(ns.DB.teams[curId]) end
end

ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", Teams.ResolveAllUnowned)
