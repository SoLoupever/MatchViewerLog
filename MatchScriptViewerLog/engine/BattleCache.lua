local addonName, ns = ...

-- ====================================================
-- ENGINE/BATTLECACHE — suivi round + "pet joue", comme les modules
-- Round/Played de tdBattlePetScript. Maintenu par les events de combat
-- (via la facade d'events de MVL, reutilisee). Pas de persistance
-- inter-/reload (edge case mineur : /reload en plein combat = round remis a 0).
-- ====================================================

ns.Engine = ns.Engine or {}
local E = ns.Engine

local ALLY  = Enum.BattlePetOwner.Ally
local ENEMY = Enum.BattlePetOwner.Enemy

local rounds = { [0] = 0, [ALLY] = 0, [ENEMY] = 0 }
local played = {}

local function slot(owner, pet)
    return (owner - 1) * NUM_BATTLE_PETS_IN_BATTLE + pet
end

function E.GetRound(owner)
    if owner then return rounds[owner] end
    return rounds[0]
end

function E.IsPetPlayed(owner, pet)
    return played[slot(owner, pet)]
end

ns.RegisterWowEvent("PET_BATTLE_OPENING_START", function()
    rounds[0], rounds[ALLY], rounds[ENEMY] = 0, 0, 0
    wipe(played)
end)

ns.RegisterWowEvent("PET_BATTLE_PET_ROUND_RESULTS", function(round)
    -- l'event se declenche parfois deux fois (cf. issue upstream #1).
    if round == rounds[0] - 1 then return end
    rounds[0]     = round + 1
    rounds[ALLY]  = rounds[ALLY] + 1
    rounds[ENEMY] = rounds[ENEMY] + 1
end)

ns.RegisterWowEvent("PET_BATTLE_PET_CHANGED", function(owner)
    if rounds[owner] then rounds[owner] = 1 end
    if owner then
        played[slot(owner, C_PetBattles.GetActivePet(owner))] = true
    end
end)
