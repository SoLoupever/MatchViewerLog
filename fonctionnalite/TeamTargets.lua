local addonName, ns = ...

-- ====================================================
-- TEAMTARGETS — association equipe <-> dompteur (npcID) et cache des noms de
-- PNJ rencontres. Extrait de TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- npcID de la cible actuelle (creature/vehicule uniquement), ou nil si pas de
-- cible ou cible un joueur. Cache le nom au passage (meme table que
-- CacheNpcName, reutilisee par AllTargets) : mutualise, seul point d'entree
-- pour lire la cible courante (CenterPanel, TeamStore.Save).
function Teams.CurrentTargetNpcID()
    if not (UnitExists("target") and not UnitIsPlayer("target")) then return nil end
    local guid = UnitGUID("target")
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    npcID = tonumber(npcID)
    if npcID then Teams.CacheNpcName(npcID, UnitName("target")) end
    return npcID
end

-- Toutes les equipes enregistrees pour un dompteur (npcID), triees par nom
-- puis id (ordre stable pour naviguer entre elles). Liste vide si aucune.
function Teams.FindAllByTarget(npcID)
    local out = {}
    if not npcID or not ns.DB then return out end
    for _, t in pairs(ns.DB.teams) do
        local hit = t.target == npcID
        if not hit and t.targets then
            for _, n in ipairs(t.targets) do
                if n == npcID then hit = true; break end
            end
        end
        if hit then out[#out + 1] = t end
    end
    table.sort(out, function(a, b)
        local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
        if na ~= nb then return na < nb end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

-- Cache npcID -> nom (rempli quand on cible/survole un PNJ).
function Teams.CacheNpcName(npcID, name)
    if not npcID or not name or not ns.DB then return end
    ns.DB.settings.npcNames = ns.DB.settings.npcNames or {}
    ns.DB.settings.npcNames[npcID] = name
end

-- Toutes les cibles ayant au moins une equipe : liste triee de
-- { npcID, name, teams = {..} }.
function Teams.AllTargets()
    local names = ns.DB.settings.npcNames or {}
    local map = {}
    for _, t in pairs(ns.DB.teams) do
        local tgts = t.targets or (t.target and { t.target }) or nil
        if tgts then
            for _, npc in ipairs(tgts) do
                map[npc] = map[npc] or { npcID = npc, teams = {} }
                table.insert(map[npc].teams, t)
            end
        end
    end
    local out = {}
    for npc, v in pairs(map) do
        v.name = names[npc] or ("PNJ #" .. npc)
        out[#out + 1] = v
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end
