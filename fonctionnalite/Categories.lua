local addonName, ns = ...

-- ====================================================
-- CATEGORIES — donnees des categories de teams. Chaque categorie :
-- { id, name, color(hex) }. Les noms par defaut sont localises ;
-- l'utilisateur pourra en creer/renommer, et l'import (Rematch)
-- en ajoutera. Le comptage de teams sera reel des que TeamStore
-- (phase suivante) existera ; pour l'instant 0.
-- ====================================================

local Cats = ns.RegisterModule("Categories", {})
ns.Cats = Cats

-- Categories par defaut (semees une seule fois si la base est vide).
local function DefaultCategories()
    return {
        { id = "group:favorites", name = ns.L("CAT_FAVORITES"), color = "ffd200" },
        { id = "group:none", name = ns.L("CAT_NONE"), color = "9d9d9d" },
        { id = "leveling",name = ns.L("CAT_LEVELING"),    color = "40e0d0" },
        { id = "wq",       name = ns.L("CAT_WORLDQUESTS"), color = "40e040" },
        { id = "tournament",name = ns.L("CAT_TOURNAMENT"), color = "ff8040" },
        { id = "dungeons", name = ns.L("CAT_DUNGEONS"),    color = "ff6060" },
    }
end

local function EnsureSeed()
    local db = ns.DB.categories
    if not db.list then
        db.list = DefaultCategories()
    end
    return db.list
end

function Cats.List()
    return EnsureSeed()
end

-- Migration unique : l'ancienne categorie par defaut "fav" (id mort, jamais
-- lu par le reste du code) est remplacee par la vraie categorie virtuelle
-- "group:favorites" (celle que TeamsIn/CountTeams reconnaissent via le flag
-- t.favorite). Les teams qui pointaient encore sur "fav" basculent sur le
-- vrai systeme : flag pose + retour en "aucune categorie".
function Cats.MigrateFavId()
    local db = ns.DB
    if not db then return end
    db.settings = db.settings or {}
    if db.settings._favIdMigrated then return end
    local list = EnsureSeed()
    local hasFav = false
    for i = #list, 1, -1 do
        if list[i].id == "group:favorites" then hasFav = true end
        if list[i].id == "fav" then table.remove(list, i) end
    end
    if not hasFav then
        table.insert(list, 1, { id = "group:favorites", name = ns.L("CAT_FAVORITES"), color = "ffd200" })
    end
    for _, t in pairs(db.teams or {}) do
        if t.category == "fav" then
            t.favorite = true
            t.category = "group:none"
        end
    end
    db.settings._favIdMigrated = true
end
ns.On("DB_READY", Cats.MigrateFavId)

-- Migration unique : "group:none" n'etait jamais semee par defaut, seulement
-- ajoutee a la volee par EnsureIntegrity une fois qu'une team l'utilisait
-- deja -- donc absente/invisible tant qu'aucune team n'y avait ete rangee au
-- moins une fois. Desormais un vrai defaut, comme Favoris. Flag separe de
-- _favIdMigrated : doit s'appliquer aussi aux comptes deja migres pour fav.
function Cats.MigrateNoneSeed()
    local db = ns.DB
    if not db then return end
    db.settings = db.settings or {}
    if db.settings._noneCatSeeded then return end
    local list = EnsureSeed()
    local has = false
    for _, c in ipairs(list) do if c.id == "group:none" then has = true break end end
    if not has then
        table.insert(list, 2, { id = "group:none", name = ns.L("CAT_NONE"), color = "9d9d9d" })
    end
    db.settings._noneCatSeeded = true
end
ns.On("DB_READY", Cats.MigrateNoneSeed)

-- Garantit que toute categorie referencee par une team existe dans la liste.
-- Sinon une team pointant vers une categorie absente (typiquement "group:none"
-- apres un import ou la liste a ete reconstruite sans elle) n'est jamais dessinee
-- par le panneau Teams (il ne parcourt que les categories de la liste) et devient
-- invisible. Idempotent, ne touche ni aux favoris ni aux categories utilisateur.
function Cats.EnsureIntegrity()
    local db = ns.DB and ns.DB.categories
    local teams = ns.DB and ns.DB.teams
    if not db or not teams then return end
    db.list = db.list or {}
    local have = {}
    for _, c in ipairs(db.list) do have[c.id] = true end
    local added = false
    for _, t in pairs(teams) do
        local cid = t.category
        if cid and cid ~= "group:favorites" and not have[cid] then
            local name = (cid == "group:none") and ns.L("CAT_NONE") or cid
            table.insert(db.list, { id = cid, name = name, color = "9d9d9d" })
            have[cid] = true
            added = true
        end
    end
    if added then ns.Fire("CATS_CHANGED") end
end

-- Repare la liste des l'ouverture de la base (meme sans source d'import active)
-- ET a chaque changement de teams : une sauvegarde manuelle (TeamDialog) peut
-- referencer une categorie ("group:none" typiquement) absente de la liste tant
-- qu'aucune autre team n'y pointait deja ; sans ce watcher elle restait
-- invisible jusqu'au prochain /reload.
ns.On("DB_READY", Cats.EnsureIntegrity)
ns.On("TEAMS_CHANGED", Cats.EnsureIntegrity)

-- Expose les defauts pour le repli de l'import (quand aucune source).
function Cats.Defaults()
    return DefaultCategories()
end

-- Cree une categorie utilisateur (id "mvl:cat:N", preserve par l'import).
-- Retourne l'id cree (utilise par l'import de categorie, TeamShare).
function Cats.Create(name, color)
    local db = ns.DB.categories
    db.list = db.list or {}
    db._catCounter = (db._catCounter or 0) + 1
    local id = "mvl:cat:" .. db._catCounter
    table.insert(db.list, { id = id, name = name, color = color or "ffd200" })
    ns.Fire("CATS_CHANGED")
    return id
end

function Cats.GetByID(id)
    for _, c in ipairs(ns.DB.categories.list or {}) do
        if c.id == id then return c end
    end
end

-- Modifie nom/couleur d'une categorie. Nom protege pour les deux categories
-- virtuelles reservees : Favoris et Aucune categorie ne peuvent pas etre
-- renommees (seule leur couleur reste modifiable), pour rester repérables
-- (cf. le cas vecu : "Aucune categorie" renommee "Pex" -> plus reconnaissable).
local PROTECTED_NAME = { ["group:favorites"] = true, ["group:none"] = true }
local DEFAULT_NAME_KEY = { ["group:favorites"] = "CAT_FAVORITES", ["group:none"] = "CAT_NONE" }

function Cats.IsNameLocked(id)
    return PROTECTED_NAME[id] == true
end

-- Pour les comptes ayant deja renomme Favoris/Aucune categorie avant le
-- verrou ci-dessus : remet le nom par defaut de la locale courante.
function Cats.ResetName(id)
    local key = DEFAULT_NAME_KEY[id]
    local c = Cats.GetByID(id)
    if not c or not key then return end
    c.name = ns.L(key)
    ns.Fire("CATS_CHANGED")
end

function Cats.Update(id, name, color)
    local c = Cats.GetByID(id)
    if not c then return end
    if name and name ~= "" and not PROTECTED_NAME[id] then c.name = name end
    if color then c.color = color end
    ns.Fire("CATS_CHANGED")
end

-- Supprime une categorie. Ses equipes ne sont PAS supprimees : elles
-- repassent en "aucune categorie" (group:none).
function Cats.Delete(id)
    local list = ns.DB.categories.list
    if not list then return end
    local idx
    for i, c in ipairs(list) do if c.id == id then idx = i break end end
    if not idx then return end
    table.remove(list, idx)
    for _, t in pairs(ns.DB.teams or {}) do
        if t.category == id then t.category = "group:none" end
    end
    ns.Fire("CATS_CHANGED"); ns.Fire("TEAMS_CHANGED")
end

-- Deplace la categorie dragId juste avant targetId (reordonnancement).
-- targetId nil = deplacer en fin de liste.
function Cats.MoveBefore(dragId, targetId)
    local list = ns.DB.categories.list
    if not list or dragId == targetId then return end
    local di
    for i, c in ipairs(list) do
        if c.id == dragId then di = i break end
    end
    if not di then return end
    local moved = table.remove(list, di)
    -- recalculer l'index cible apres retrait
    local ti
    for i, c in ipairs(list) do if c.id == targetId then ti = i break end end
    table.insert(list, ti or (#list + 1), moved)
    ns.Fire("CATS_CHANGED")
end

-- Equipes d'une categorie (favoris = teams marquees favorite). Triees par
-- ordre manuel (t.order, pose par le drag-and-drop) puis par nom en repli.
function Cats.TeamsIn(catID)
    local out = {}
    local teams = ns.DB.teams or {}
    for _, t in pairs(teams) do
        if catID == "group:favorites" then
            if t.favorite then out[#out + 1] = t end
        elseif t.category == catID then
            out[#out + 1] = t
        end
    end
    table.sort(out, function(a, b)
        local ao, bo = a.order, b.order
        if ao and bo and ao ~= bo then return ao < bo end
        if ao and not bo then return true end
        if bo and not ao then return false end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

-- Deplace l'equipe dragID juste avant targetID, dans sa categorie. targetID
-- nil = en fin de categorie. Reassigne t.order a toute la categorie pour un
-- ordre stable. Ignore si la cible est dans une autre categorie.
function Cats.MoveTeamBefore(dragID, targetID)
    local teams = ns.DB.teams or {}
    local drag = teams[dragID]
    if not drag or dragID == targetID then return end
    local target = targetID and teams[targetID]
    if targetID and (not target or target.category ~= drag.category) then return end
    local list = Cats.TeamsIn(drag.category)
    for i, t in ipairs(list) do if t.id == dragID then table.remove(list, i) break end end
    local ti
    if targetID then
        for i, t in ipairs(list) do if t.id == targetID then ti = i break end end
    end
    table.insert(list, ti or (#list + 1), drag)
    for i, t in ipairs(list) do t.order = i end
    ns.Fire("TEAMS_CHANGED")
end

-- Nombre de teams dans une categorie. "group:favorites" est virtuelle :
-- on compte les teams marquees favorite.
function Cats.CountTeams(catID)
    local teams = ns.DB.teams
    if not teams then return 0 end
    local n = 0
    for _, t in pairs(teams) do
        if catID == "group:favorites" then
            if t.favorite then n = n + 1 end
        elseif t.category == catID then
            n = n + 1
        end
    end
    return n
end
