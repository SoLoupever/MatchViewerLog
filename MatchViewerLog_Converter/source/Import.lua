local addonName, ns = ...

-- ====================================================
-- REMATCH — recupere groupes/teams de Rematch en LISANT ses SavedVariables
-- (globales chargees par l'addon quand il est actif). Anti-doublon par cle
-- (nom + mascottes). Import AUTOMATIQUE a la connexion : aucune commande requise.
-- Ecrit dans MatchViewerLogDB via l'API publique de MVL (aucun acces aux
-- internes de MatchViewerLog).
-- ====================================================

local MVL = ns.MVL
local Import = ns.RegisterModule("Import", {})

local SOURCES = { "Rematch" }

local function TeamKey(name, pets)
    local ids = {}
    for _, p in ipairs(pets or {}) do ids[#ids + 1] = tostring(p) end
    table.sort(ids)
    return (name or ""):lower() .. "|" .. table.concat(ids, ",")
end

local function Count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- Decode un tag Rematch (voir Rematch/process/petTags.lua) en 3 abilityID.
-- Format : 3 chiffres base32 (choix 0/1/2 par palier) + breed + speciesID,
-- ex "22201A5" -> paliers 2/2/2, breed 0, speciesID base32 "1A5".
-- Choix 1 = list[tier], choix 2 = list[tier+3] (meme convention que Deploy.lua).
-- Renvoie nil si le tag est absent, special (ZL/ZI/ZR...) ou pas assez long.
local function DecodeTagAbilities(tag)
    if type(tag) ~= "string" or #tag < 5 or tag:sub(1, 1) == "Z" then return nil end
    local speciesID = tonumber(tag:sub(5, -1), 32)
    if not speciesID then return nil end
    local list = C_PetJournal.GetPetAbilityList(speciesID)
    if type(list) ~= "table" then return nil end
    local out
    for tier = 1, 3 do
        local choice = tonumber(tag:sub(tier, tier), 32)
        local id = (choice == 1 and list[tier]) or (choice == 2 and list[tier + 3]) or nil
        if id then out = out or {}; out[tier] = id end
    end
    return out
end

-- Construit abil[slot] pour les 3 slots a partir de t.tags Rematch.
-- Renvoie nil si aucun palier n'a pu etre decode (pas de perte silencieuse :
-- Teams.Load() retombe alors sur son propre defaut).
local function DecodeAbilFromTags(tags)
    if type(tags) ~= "table" then return nil end
    local abil
    for slot = 1, 3 do
        local a = DecodeTagAbilities(tags[slot])
        if a then abil = abil or {}; abil[slot] = a end
    end
    return abil
end

local function ImportSource(prefix, log)
    local teams  = _G[prefix .. "5SavedTeams"]
    local groups = _G[prefix .. "5SavedGroups"]
    local sett   = _G[prefix .. "5Settings"]
    if type(teams) ~= "table" then return 0, 0 end

    local db = MVL.GetDB()
    db.categories = db.categories or {}
    db.categories.list = db.categories.list or {}
    db.teams = db.teams or {}

    -- Categories depuis les groupes (ordre GroupOrder si dispo).
    -- "group:none" INCLUS : cote Rematch ce n'est pas un simple sentinel,
    -- c'est un vrai groupe (savedGroups.lua le cree toujours avec un nom et
    -- une liste de teams), que l'utilisateur peut renommer/re-icone comme
    -- n'importe quel autre. Rematch l'affiche toujours dans son propre
    -- arbre de groupes -> on fait pareil, sinon les teams qu'il contient
    -- deviennent invisibles cote MVL (categorie jamais creee).
    local haveCat = {}
    for _, c in ipairs(db.categories.list) do haveCat[c.id] = true end
    local addedCats = 0
    local function AddCat(gid)
        if not gid or haveCat[gid] then return end
        local g = groups and groups[gid]
        table.insert(db.categories.list, {
            id = gid, name = (g and g.name) or gid, color = g and g.color or nil,
        })
        haveCat[gid] = true
        addedCats = addedCats + 1
    end
    if type(sett) == "table" and type(sett.GroupOrder) == "table" then
        for _, gid in ipairs(sett.GroupOrder) do AddCat(gid) end
    end
    if type(groups) == "table" then for gid in pairs(groups) do AddCat(gid) end end

    -- Teams (dedup par cle). keyToID sert aussi au rattrapage des abil
    -- manquants sur des teams deja importees (voir plus bas).
    local keyToID = {}
    for id, t in pairs(db.teams) do if t.srcKey then keyToID[t.srcKey] = id end end
    local seen, named, added, backfilled = 0, 0, 0, 0
    for _, t in pairs(teams) do
        seen = seen + 1
        if type(t) == "table" and t.name then
            named = named + 1
            local key = TeamKey(t.name, t.pets)
            local existingID = keyToID[key]

            if not existingID then
                db._teamCounter = (db._teamCounter or 0) + 1
                local id = "mvl:" .. db._teamCounter
                local pref = t.preferences

                -- pets[slot] n'est pas toujours un petID reel (voir
                -- Rematch/savedvars/savedTeams.lua) : "random:N" (aleatoire),
                -- 0 (montee de niveau) ou "ignored" (slot ignore). On sort ces
                -- cas de pets vers des tables dediees pour que l'affichage les
                -- distingue d'un slot vraiment vide au lieu de tenter un
                -- C_PetJournal.GetPetInfoByPetID() voue a echouer. Le slot
                -- leveling Rematch (0) est unifie sur le slot aleatoire "XP".
                local pets = t.pets and CopyTable(t.pets) or {}
                local random, special
                for slot = 1, 3 do
                    local v = pets[slot]
                    if type(v) == "string" then
                        local rt = v:match("^random:(%d+)")
                        if rt then
                            random = random or {}
                            random[slot] = tonumber(rt)
                            pets[slot] = false
                        elseif v == "ignored" then
                            special = special or {}
                            special[slot] = "ignored"
                            pets[slot] = false
                        end
                    elseif v == 0 then
                        random = random or {}
                        random[slot] = MVL.RANDOM_XP
                        pets[slot] = false
                    end
                end

                db.teams[id] = {
                    id       = id,
                    name     = t.name,
                    pets     = pets,
                    random   = random,
                    special  = special,
                    abil     = DecodeAbilFromTags(t.tags),
                    category = t.groupID or "group:none",
                    target   = t.targets and t.targets[1] or nil,
                    targets  = t.targets and CopyTable(t.targets) or nil,
                    xp       = (pref and pref.minXP and pref.minXP > 0) and true or false,
                    favorite = t.favorite and true or false,
                    source   = prefix,
                    srcKey   = key,
                }
                keyToID[key] = id
                added = added + 1
            elseif not db.teams[existingID].abil then
                -- Team deja importee avant ce correctif : on rattrape les
                -- sorts a partir des tags Rematch, sans toucher au reste
                -- (ne jamais ecraser un choix deja fait par l'utilisateur).
                local abil = DecodeAbilFromTags(t.tags)
                if abil then
                    db.teams[existingID].abil = abil
                    backfilled = backfilled + 1
                end
            end
        end
    end

    if log then
        print(string.format("  %s : vus=%d nommes=%d ajoutes=%d rattrapes=%d cats=%d",
            prefix, seen, named, added, backfilled, addedCats))
    end
    return addedCats, added
end

-- Migration : les teams importees AVANT le support des slots aleatoires ont
-- encore "random:N" coince dans pets (et pas de champ random). On les corrige
-- une fois pour toutes. Idempotent (rien a faire s'il n'y a plus de "random:").
local function MigrateRandomSlots(db)
    for _, t in pairs(db.teams or {}) do
        if type(t.pets) == "table" then
            for slot = 1, 3 do
                local v = t.pets[slot]
                if type(v) == "string" then
                    local rt = v:match("^random:(%d+)")
                    if rt then
                        t.random = t.random or {}
                        t.random[slot] = tonumber(rt)
                        t.pets[slot] = false
                    end
                end
            end
        end
    end
end

-- Migration : meme principe que ci-dessus pour les teams importees AVANT le
-- support des slots leveling/ignored (0 ou "ignored" coince dans pets). Le
-- leveling Rematch (0) est unifie sur le slot aleatoire "XP" ; seul "ignored"
-- reste special. Ne necessite pas la source Rematch. Idempotent.
local function MigrateSpecialSlots(db)
    for _, t in pairs(db.teams or {}) do
        if type(t.pets) == "table" then
            for slot = 1, 3 do
                local v = t.pets[slot]
                if v == 0 then
                    t.random = t.random or {}
                    t.random[slot] = MVL.RANDOM_XP
                    t.pets[slot] = false
                elseif v == "ignored" then
                    t.special = t.special or {}
                    t.special[slot] = "ignored"
                    t.pets[slot] = false
                end
            end
        end
    end
end

function Import.Run(verbose)
    local db = MVL.GetDB()
    db.categories = db.categories or {}
    db.teams = db.teams or {}
    MigrateRandomSlots(db)
    MigrateSpecialSlots(db)

    -- Si une source est chargee, on reconstruit la liste des categories a
    -- neuf (fini les defauts parasites melanges aux vraies). Sans source, on
    -- garde ce qui est deja importe (ne rien effacer).
    local anySource = false
    for _, p in ipairs(SOURCES) do
        if type(_G[p .. "5SavedTeams"]) == "table" then anySource = true end
    end
    if anySource then
        -- On garde les categories creees par l'utilisateur (id "mvl:cat:...").
        local kept = {}
        for _, c in ipairs(db.categories.list or {}) do
            if type(c.id) == "string" and c.id:find("^mvl:cat:") then kept[#kept + 1] = c end
        end
        db.categories.list = kept
    end

    local totalC, totalT = 0, 0
    for _, prefix in ipairs(SOURCES) do
        local c, t = ImportSource(prefix, verbose)
        totalC, totalT = totalC + c, totalT + t
    end

    -- File de montee XP : <prefix>5Settings.LevelingQueue = liste de
    -- { petID, petTag, added, preferred }. On ne garde que les petID.
    local qids = {}
    for _, prefix in ipairs(SOURCES) do
        local sett = _G[prefix .. "5Settings"]
        local lq = type(sett) == "table" and sett.LevelingQueue
        if type(lq) == "table" then
            for _, e in ipairs(lq) do
                local pid = (type(e) == "table" and e.petID) or (type(e) == "string" and e) or nil
                if pid then qids[#qids + 1] = pid end
            end
        end
    end
    local totalQ = MVL.QueueImport(qids)

    -- Toujours vide (jamais de source, jamais importe) : categories par defaut.
    if not db.categories.list or #db.categories.list == 0 then
        db.categories.list = MVL.GetDefaultCategories()
    end

    -- "group:favorites" est garantie par MVL des le DB_READY (Categories.lua,
    -- seed par defaut + migration) : plus besoin de la reinserer ici a la main.

    -- Filet de securite : garantit que les categories referencees par les teams
    -- importees (dont "group:none") existent bien dans la liste, sinon elles
    -- resteraient invisibles cote panneau Teams.
    MVL.EnsureCategoriesIntegrity()

    ns.Fire("CATS_CHANGED")
    ns.Fire("TEAMS_CHANGED")

    if verbose then
        local any = false
        for _, p in ipairs(SOURCES) do if type(_G[p .. "5SavedTeams"]) == "table" then any = true end end
        print("|cff4da6ffMatchViewerLog|r " ..
            (any and string.format(ns.L("IMPORT_DONE"), totalT, totalC) or ns.L("IMPORT_NO_SOURCE")))
        if any then print("|cff4da6ffMatchViewerLog|r " .. string.format(ns.L("IMPORT_QUEUE_DONE"), totalQ)) end
    end
    return totalC, totalT
end

function Import.Diagnose()
    local db = MVL.GetDB()
    print("|cff4da6ffMatchViewerLog|r diagnostic import :")
    for _, prefix in ipairs(SOURCES) do
        local t = _G[prefix .. "5SavedTeams"]
        local g = _G[prefix .. "5SavedGroups"]
        local s = _G[prefix .. "5Settings"]
        local order = (type(s) == "table") and s.GroupOrder or nil
        print(string.format("  %s : teams=%s(%d)  groups=%s(%d)  GroupOrder=%s(%d)",
            prefix, type(t), Count(t), type(g), Count(g), type(order), Count(order)))
    end
    print(string.format("  MatchViewerLogDB : teams=%d  categories=%d",
        Count(db.teams), Count(db.categories and db.categories.list)))
end

-- Declencheurs exposes (slash /mvl import, etc.).
ns.API.ImportRematch = Import.Run
ns.API.Diagnose      = Import.Diagnose

-- ---- Import AUTOMATIQUE ----
local ran = false
local function AutoRun()
    if ran then return end
    local any = false
    for _, p in ipairs(SOURCES) do if type(_G[p .. "5SavedTeams"]) == "table" then any = true end end
    if not any then return end   -- aucune source active : on retentera plus tard
    ran = true
    Import.Run(false)
end

ns.RegisterWowEvent("PLAYER_LOGIN", function() C_Timer.After(1, AutoRun) end)
ns.On("MVL_FRAME_READY", AutoRun)

-- Corrige les teams deja importees meme si aucune source n'est chargee cette
-- session (slots "random:N", 0 ou "ignored" restes coinces dans pets).
ns.On("DB_READY", function()
    local db = MVL.GetDB()
    if db and db.teams then
        MigrateRandomSlots(db)
        MigrateSpecialSlots(db)
        ns.Fire("TEAMS_CHANGED")
    end
end)
