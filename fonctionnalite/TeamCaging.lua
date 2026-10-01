local addonName, ns = ...

-- ====================================================
-- TEAMCAGING — repli "non possede" quand une mascotte d'equipe est mise en
-- cage ou relachee (son GUID cesse de resoudre) : on memorise espece/breed
-- pendant qu'elle est possedee, puis on bascule le slot pour qu'il se
-- resolve tout seul au re-apprentissage (voir TeamResolve). Extrait de
-- TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- ---- Mascottes d'equipe mises en cage / relachees ------------------------
-- Un slot stocke sa mascotte par petID (GUID). Mise en cage ou relachee, ce
-- GUID ne resout plus : sans repli le slot passait "vide" et, un pet re-appris
-- recevant un nouveau GUID, il ne repoussait jamais. On memorise species/breed
-- tant que la mascotte est possedee ; quand son GUID cesse de resoudre, on
-- bascule le slot dans le systeme "non possede" existant (icone grisee +
-- resolution auto au re-apprentissage via ResolveAllUnowned).
local function MetaStore()
    ns.DB.settings.petMeta = ns.DB.settings.petMeta or {}
    return ns.DB.settings.petMeta
end

-- Memorise species/breed d'un petID encore possede (repli si mise en cage).
local function RememberPet(petID)
    if type(petID) ~= "string" or not petID:find("^BattlePet") then return end
    local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
    if not speciesID then return end
    MetaStore()[petID] = { species = speciesID,
                           breed = ns.Breed and ns.Breed.GetForPetID(petID) or nil }
end

-- Bascule en "non possede" les slots dont le petID ne resout plus, via la meta.
-- abilBySlot : sorts choisis, rebranches au re-apprentissage. true si changement.
local function ConvertCagedSlots(pets, unowned, abilBySlot)
    if type(pets) ~= "table" then return false end
    local meta, changed = MetaStore(), false
    for i = 1, 3 do
        local pid = pets[i]
        if type(pid) == "string" and pid:find("^BattlePet")
           and not C_PetJournal.GetPetInfoByPetID(pid) then
            local m = meta[pid]
            if m and m.species then
                local a = abilBySlot and abilBySlot[i]
                unowned[i] = { species = m.species, breed = m.breed,
                               abil = a and { a[1], a[2], a[3] } or nil }
                pets[i] = nil
                changed = true
            end
        end
    end
    return changed
end

-- Purge les meta plus referencees par aucune equipe (pet resolu ou converti).
local function PruneMeta()
    local meta, keep = MetaStore(), {}
    local c = Teams.current
    for i = 1, 3 do if type(c.pets[i]) == "string" then keep[c.pets[i]] = true end end
    for _, t in pairs(ns.DB.teams) do
        if type(t.pets) == "table" then
            for i = 1, 3 do if type(t.pets[i]) == "string" then keep[t.pets[i]] = true end end
        end
    end
    for pid in pairs(meta) do if not keep[pid] then meta[pid] = nil end end
end

-- Passe sur l'equipe en cours + toutes les equipes enregistrees a chaque
-- changement de journal : memorise les mascottes possedees, puis convertit
-- celles qui viennent d'etre mises en cage.
local reconciling = false
function Teams.ReconcileCaged()
    if reconciling then return end
    if not (ns.DB and ns.DB.teams) then return end
    reconciling = true
    local c = Teams.current
    for i = 1, 3 do RememberPet(c.pets[i]) end
    for _, t in pairs(ns.DB.teams) do
        if type(t.pets) == "table" then
            for i = 1, 3 do RememberPet(t.pets[i]) end
        end
    end
    local any = false
    for _, t in pairs(ns.DB.teams) do
        t.unowned = t.unowned or {}
        if ConvertCagedSlots(t.pets, t.unowned, t.abil) then any = true end
    end
    c.unowned = c.unowned or {}
    local curChanged = ConvertCagedSlots(c.pets, c.unowned, c.abil)
    PruneMeta()
    reconciling = false
    if any then ns.Fire("TEAMS_CHANGED") end
    if curChanged then ns.Fire("TEAM_LOADED") end
end
ns.RegisterWowEvent("PET_JOURNAL_LIST_UPDATE", Teams.ReconcileCaged)
