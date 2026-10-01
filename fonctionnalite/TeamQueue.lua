local addonName, ns = ...

-- ====================================================
-- TEAMQUEUE — file d'XP (mascottes a monter) : file manuelle persistante +
-- mascottes des equipes sous le niveau max, et choix du slot aleatoire "XP"
-- au deploiement. Extrait de TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- Mascottes (petID, uniques) sous le niveau max ET presentes dans au moins
-- une equipe enregistree. Calcule en direct (retroactif + a jour). Triees
-- par niveau croissant puis par nom.
function Teams.LevelingPets()
    -- Decore (pid, niveau, nom) en un seul passage puis trie : l'API n'est plus
    -- appelee dans le comparateur (O(n) appels au lieu de O(n log n)).
    local seen, deco = {}, {}
    for _, t in pairs(ns.DB.teams or {}) do
        if type(t.pets) == "table" then
            for i = 1, 3 do
                local pid = t.pets[i]
                if type(pid) == "string" and pid:find("^BattlePet") and not seen[pid] then
                    seen[pid] = true
                    local _, cname, level, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(pid)
                    if level and level < ns.MAX_PET_LEVEL then
                        deco[#deco + 1] = { pid = pid, level = level, name = cname or name or "" }
                    end
                end
            end
        end
    end
    table.sort(deco, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, #deco do out[i] = deco[i].pid end
    return out
end

-- ---- File d'XP persistante (mascottes ajoutees a la main / importees) ----
-- Stockee dans ns.DB.settings.xpQueue : liste ordonnee de petID.
local function QueueTable()
    ns.DB.settings.xpQueue = ns.DB.settings.xpQueue or {}
    return ns.DB.settings.xpQueue
end

function Teams.QueueHas(petID)
    if type(petID) ~= "string" then return false end
    for _, p in ipairs(QueueTable()) do if p == petID then return true end end
    return false
end

function Teams.QueueAdd(petID)
    if type(petID) ~= "string" or not petID:find("^BattlePet") then return end
    local q = QueueTable()
    for _, p in ipairs(q) do if p == petID then return end end
    q[#q + 1] = petID
    ns.Fire("TEAMS_CHANGED")
end

function Teams.QueueRemove(petID)
    local q = QueueTable()
    for i, p in ipairs(q) do
        if p == petID then table.remove(q, i); ns.Fire("TEAMS_CHANGED"); return end
    end
end

-- Ajout en lot (ex: file de niveau Rematch). Ignore les doublons, ne
-- diffuse qu'un seul TEAMS_CHANGED. Retourne le nombre reellement ajoute.
function Teams.QueueImport(petIDs)
    if type(petIDs) ~= "table" then return 0 end
    local q = QueueTable()
    local have = {}
    for _, p in ipairs(q) do have[p] = true end
    local added = 0
    for _, pid in ipairs(petIDs) do
        if type(pid) == "string" and pid:find("^BattlePet") and not have[pid] then
            q[#q + 1] = pid; have[pid] = true; added = added + 1
        end
    end
    if added > 0 then ns.Fire("TEAMS_CHANGED") end
    return added
end

-- File d'XP : mascottes de la file manuelle + mascottes des equipes, toutes
-- sous le niveau max, dedupliquees et triees par niveau DECROISSANT (les plus
-- proches de 25 d'abord, comme le filtre "a monter" de gauche) puis nom. Cet
-- ordre sert aussi au deploiement (le slot "XP" pioche la 1re non utilisee).
function Teams.QueuePets()
    -- Meme decoration que LevelingPets : niveau/nom captures une fois, tri sans
    -- appel API dans le comparateur. Ordre niveau DECROISSANT (proche de 25)
    -- par defaut, ou CROISSANT si l'option xpPick = "lowest".
    local seen, deco = {}, {}
    local function add(pid)
        if type(pid) == "string" and pid:find("^BattlePet") and not seen[pid] then
            local _, cname, level, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(pid)
            if level and level < ns.MAX_PET_LEVEL then
                seen[pid] = true
                deco[#deco + 1] = { pid = pid, level = level, name = cname or name or "" }
            end
        end
    end
    for _, pid in ipairs(QueueTable()) do add(pid) end
    for _, pid in ipairs(Teams.LevelingPets()) do add(pid) end
    local asc = (ns.Options and ns.Options.Get("xpPick")) == "lowest"
    table.sort(deco, function(a, b)
        if a.level ~= b.level then
            if asc then return a.level < b.level else return a.level > b.level end
        end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, #deco do out[i] = deco[i].pid end
    return out
end

-- Choisit la mascotte du slot aleatoire "XP" selon l'option xpPick. Source
-- unique de selection (le compagnon la consomme via l'API publique, comme
-- PickRandomOfType) : l'apercu et le deploiement restent coherents.
--   closest25 (defaut)  1re non utilisee de la file (deja triee proche de 25)
--   lowest              1re non utilisee (file triee plus bas niveau d'abord)
--   closest25_rare      1re non utilisee de qualite rare (bleu) ; sinon vide
--   random              une non utilisee au hasard (varie a chaque deploiement)
function Teams.PickLevelingPet(used)
    used = used or {}
    local mode = (ns.Options and ns.Options.Get("xpPick")) or "closest25"
    local cands = {}
    for _, pid in ipairs(Teams.QueuePets()) do
        if not used[pid] then cands[#cands + 1] = pid end
    end
    if #cands == 0 then return nil end
    if mode == "random" then
        return cands[math.random(#cands)]
    end
    if mode == "closest25_rare" then
        for _, pid in ipairs(cands) do
            if select(5, C_PetJournal.GetPetStats(pid)) == 4 then return pid end
        end
        return nil
    end
    return cands[1]
end
