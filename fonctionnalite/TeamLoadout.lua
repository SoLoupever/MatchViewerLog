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

-- Ecrit reellement la compo concrete dans les emplacements de combat. Si l'etat
-- du jeu l'interdit (combat), on memorise pour re-essayer a la fin du combat :
-- sans ca, une compo modifiee pendant un combat n'etait jamais appliquee et
-- l'ancien loadout ressortait au combat suivant.
function Teams.ApplyLoadout()
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then pendingSync = true; return end
    if InCombatLockdown() then pendingSync = true; return end
    if C_PetJournal.IsJournalUnlocked and not C_PetJournal.IsJournalUnlocked() then pendingSync = true; return end
    pendingSync = false
    local c = Teams.current
    for slot = 1, 3 do
        local petID = c.pets[slot]
        if not (c.random and c.random[slot])
           and type(petID) == "string" and petID:find("^BattlePet") then
            pcall(C_PetJournal.SetPetLoadOutInfo, slot, petID)
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
