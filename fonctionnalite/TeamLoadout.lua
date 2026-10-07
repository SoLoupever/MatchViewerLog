local addonName, ns = ...

-- ====================================================
-- TEAMLOADOUT — synchro du loadout de combat Blizzard avec la compo editee au
-- centre. Extrait de TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- ---- Synchro du loadout de combat Blizzard avec la compo affichee ----
-- Les mascottes CONCRETES de l'equipe en cours sont placees dans les
-- emplacements de combat (hors combat / hors bataille), pour qu'un
-- changement de mascotte parte tout de suite au combat sans devoir
-- sauvegarder. Les slots aleatoires sont laisses au deploiement (companion).
-- En attente : une edition a eu lieu alors que l'API loadout etait bloquee
-- (combat de mascottes ou combat monde). On re-applique a la sortie.
local pendingSync = false

local function IsPetID(v) return type(v) == "string" and v:find("^BattlePet") ~= nil end

-- Pet effectif par slot : fixes d'abord (marques "used"), puis slots aleatoires
-- (XP / type) resolus sans doublon. Resultat memoise pour l'equipe courante
-- (signature pets/random/special) : l'edition d'un sort ne retire pas un
-- aleatoire, et MSVL/MVL deploient le meme resultat. Reset au chargement
-- d'equipe, au changement de teams/file et en fin de combat (niveaux changes).
local resolved
function Teams.ResetResolved() resolved = nil end

function Teams.ResolveSlots(src)
    local c = Teams.current
    src = src or c
    local random, special, pets = src.random or {}, src.special or {}, src.pets or {}
    local sig
    if src == c then
        local p = {}
        for i = 1, 3 do p[i] = tostring(pets[i]) .. "|" .. tostring(random[i]) .. "|" .. tostring(special[i]) end
        sig = table.concat(p, ";")
        if resolved and resolved.sig == sig then return resolved.out end
    end
    local out, used = {}, {}
    for i = 1, 3 do
        if not random[i] and special[i] ~= "leveling" and IsPetID(pets[i]) then
            out[i] = pets[i]; used[pets[i]] = true
        end
    end
    for i = 1, 3 do
        if not out[i] then
            local pid
            if random[i] == ns.RANDOM_XP or special[i] == "leveling" then
                pid = Teams.PickLevelingPet(used)
            elseif random[i] then
                pid = Teams.PickRandomOfType(random[i], used)
            end
            if pid then out[i] = pid; used[pid] = true end
        end
    end
    if sig then resolved = { sig = sig, out = out } end
    return out
end

ns.On("TEAMS_CHANGED", Teams.ResetResolved)
ns.RegisterWowEvent("PET_BATTLE_CLOSE", Teams.ResetResolved)

-- Ecrit reellement la compo dans les emplacements de combat (slots aleatoires
-- inclus). Si l'etat du jeu l'interdit (combat), on memorise pour re-essayer a
-- la fin du combat : sans ca, une compo modifiee pendant un combat n'etait
-- jamais appliquee et l'ancien loadout ressortait au combat suivant.
function Teams.ApplyLoadout()
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then pendingSync = true; return end
    if InCombatLockdown() then pendingSync = true; return end
    if C_PetJournal.IsJournalUnlocked and not C_PetJournal.IsJournalUnlocked() then pendingSync = true; return end
    pendingSync = false
    local c = Teams.current
    local slots = Teams.ResolveSlots()
    for slot = 1, 3 do
        local petID = slots[slot]
        if petID then
            local cur = C_PetJournal.GetPetLoadOutInfo(slot)
            if cur ~= petID then pcall(C_PetJournal.SetPetLoadOutInfo, slot, petID) end
            local a = c.abil[slot]
            if type(a) == "table" then
                for tier = 1, 3 do
                    if a[tier] then pcall(C_PetJournal.SetAbility, slot, tier, a[tier]) end
                end
            end
        end
    end
end

-- Sync depuis l'edition (TEAM_LOADED) : uniquement quand la fenetre est ouverte
-- (edition active). Coalesce les editions rapprochees (changement de sort,
-- cycle de slot) en une seule ecriture de loadout au lieu d'une par event.
local syncPending = false
local function DoSync()
    syncPending = false
    if _G.MatchViewerLogFrame and MatchViewerLogFrame:IsShown() then Teams.ApplyLoadout() end
end
function Teams.SyncLoadout()
    if not (_G.MatchViewerLogFrame and MatchViewerLogFrame:IsShown()) then return end
    if syncPending then return end
    syncPending = true
    C_Timer.After(0.2, DoSync)
end

ns.On("TEAM_LOADED", Teams.SyncLoadout)
-- Fin d'un combat de mascottes / sortie de combat monde : si une edition a ete
-- faite pendant, on l'applique enfin (leger delai apres PET_BATTLE_CLOSE, l'etat
-- "en combat" pouvant persister un instant).
ns.RegisterWowEvent("PET_BATTLE_CLOSE", function()
    if pendingSync then C_Timer.After(0.1, Teams.ApplyLoadout) end
end)
ns.RegisterWowEvent("PLAYER_REGEN_ENABLED", function()
    if pendingSync then Teams.ApplyLoadout() end
end)
