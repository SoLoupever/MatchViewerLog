local addonName, ns = ...

-- ENGINE/ACTIONS — implementations des actions (portage fidele).
-- Les appels C_PetBattles sont proteges : ne sont executes que quand
-- Action:Run est atteint depuis le OnClick materiel du bouton (run=true).

local E    = ns.Engine
local Util = E.Util
local RegisterAction = E.RegisterAction

local ALLY = Enum.BattlePetOwner.Ally

RegisterAction('test', function(arg, run)
    if run then
        print(arg)
    end
    return true
end)

RegisterAction('change', function(index, run)
    local active = C_PetBattles.GetActivePet(ALLY)
    if index == 'next' then
        local function nextAfter(index)
            return index % C_PetBattles.GetNumPets(ALLY) + 1
        end
        local function canUse(index)
            return C_PetBattles.GetHealth(ALLY, index) ~= 0 and C_PetBattles.CanPetSwapIn(index)
        end
        index = nextAfter(active)
        while not canUse(index) and index ~= active do
            index = nextAfter(index)
        end
    else
        index = Util.ParsePetIndex(ALLY, index)
    end

    if not index or active == index or not (C_PetBattles.CanActivePetSwapOut() or C_PetBattles.ShouldShowPetSelect()) or not C_PetBattles.CanPetSwapIn(index) then
        return false
    end
    if run then
        C_PetBattles.ChangePet(index)
    end
    return true
end)

RegisterAction('ability', 'use', function(ability, run)
    local index = C_PetBattles.GetActivePet(ALLY)
    ability = Util.ParseAbility(ALLY, index, ability)
    if not ability then
        return false
    end
    if not C_PetBattles.GetAbilityState(ALLY, index, ability) then
        return false
    end
    if run then
        C_PetBattles.UseAbility(ability)
    end
    return true
end)

RegisterAction('quit', function(run)
    if run then
        C_PetBattles.ForfeitGame()
    end
    return true
end)

RegisterAction('standby', function(run)
    if not C_PetBattles.IsSkipAvailable() then
        return false
    end
    if run then
        C_PetBattles.SkipTurn()
    end
    return true
end)

RegisterAction('catch', function(run)
    if not C_PetBattles.IsTrapAvailable() then
        return false
    end
    if run then
        C_PetBattles.UseTrap()
    end
    return true
end)

RegisterAction('--', function(run)
    return false
end)
