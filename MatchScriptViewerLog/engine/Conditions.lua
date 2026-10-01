local addonName, ns = ...

-- ENGINE/CONDITIONS — implementations des conditions (portage fidele).

local E         = ns.Engine
local Util      = E.Util
local Condition = E.Condition
local RegisterCondition = E.RegisterCondition

local ALLY  = Enum.BattlePetOwner.Ally
local ENEMY = Enum.BattlePetOwner.Enemy

local function getOpponent(owner)
    return owner == ALLY and ENEMY or ALLY
end

local function getOpponentActivePet(owner)
    local opponent = getOpponent(owner)
    return opponent, C_PetBattles.GetActivePet(opponent)
end

local function GetAbilityAttackModifier(owner, pet, ability)
    if not pet or not ability then
        return
    end
    local abilityType, noStrongWeakHints = select(7, C_PetBattles.GetAbilityInfo(owner, pet, ability))
    if noStrongWeakHints then
        return
    end
    local opponentType = C_PetBattles.GetPetType(getOpponentActivePet(owner))
    return C_PetBattles.GetAttackModifier(abilityType, opponentType)
end

local infinite = tonumber('inf')
local function logical_max_health(owner, pet)
    return pet and C_PetBattles.GetMaxHealth(owner, pet) or infinite
end

RegisterCondition('dead', { type = 'boolean', arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) == 0
end)

RegisterCondition('hp', { type = 'compare', arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet)
end)

RegisterCondition('hp.full', { type = 'boolean', arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) == logical_max_health(owner, pet)
end)

RegisterCondition('hp.can_be_exploded', { type = 'boolean', arg = false }, function(owner, pet)
    return pet and C_PetBattles.GetHealth(owner, pet) <= floor(logical_max_health(getOpponentActivePet(owner)) * 0.4)
end)
RegisterCondition('hp.can_explode', Condition.opts['hp.can_be_exploded'], Condition.apis['hp.can_be_exploded'])

RegisterCondition('hp.low', { type = 'boolean', pet = false, arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) < C_PetBattles.GetHealth(getOpponentActivePet(owner))
end)

RegisterCondition('hp.high', { type = 'boolean', pet = false, arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) > C_PetBattles.GetHealth(getOpponentActivePet(owner))
end)

local function hpp(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) / logical_max_health(owner, pet) * 100
end

RegisterCondition('hpp', { type = 'compare', arg = false }, function(owner, pet)
    return hpp(owner, pet)
end)

RegisterCondition('hp.diff', { type = 'compare', arg = false }, function(owner, pet)
    return C_PetBattles.GetHealth(owner, pet) - C_PetBattles.GetHealth(getOpponentActivePet(owner))
end)

RegisterCondition('hpp.diff', { type = 'compare', arg = false }, function(owner, pet)
    return hpp(owner, pet) - hpp(getOpponentActivePet(owner))
end)

RegisterCondition('aura.exists', { type = 'boolean' }, function(owner, pet, aura)
    return aura and Util.FindAura(owner, pet, aura)
end)

RegisterCondition('aura.duration', { type = 'compare' }, function(owner, pet, aura)
    local owner, pet, index = Util.FindAura(owner, pet, aura)
    if aura and index then
        return (select(3, C_PetBattles.GetAuraInfo(owner, pet, index)))
    end
    return 0
end)

RegisterCondition('weather.exists', { type = 'boolean', owner = 'not-allowed', pet = false }, function(_, _, weather)
    local id, name = 0, ''
    local aura = C_PetBattles.GetAuraInfo(Enum.BattlePetOwner.Weather, PET_BATTLE_PAD_INDEX, 1)
    if aura then
        id, name = C_PetBattles.GetAbilityInfoByID(aura)
    end
    return weather and (id == weather or name == weather)
end)
RegisterCondition('weather', Condition.opts['weather.exists'], Condition.apis['weather.exists'])

RegisterCondition('weather.duration', { type = 'compare', owner = 'not-allowed', pet = false }, function(_, _, weather)
    local id, _, duration = C_PetBattles.GetAuraInfo(Enum.BattlePetOwner.Weather, PET_BATTLE_PAD_INDEX, 1)
    if weather and id and (id == weather or select(2, C_PetBattles.GetAbilityInfoByID(id)) == weather) then
        return duration
    end
    return 0
end)

RegisterCondition('active', { type = 'boolean', arg = false }, function(owner, pet)
    return C_PetBattles.GetActivePet(owner) == pet
end)

RegisterCondition('ability.usable', { type = 'boolean', argParse = Util.ParseAbility }, function(owner, pet, ability)
    local isUsable = C_PetBattles.GetAbilityState(owner, pet, ability)
    return ability and isUsable
end)

RegisterCondition('ability.duration', { type = 'compare', argParse = Util.ParseAbility }, function(owner, pet, ability)
    local isUsable, currentCooldown, currentLockdown = C_PetBattles.GetAbilityState(owner, pet, ability)
    return ability and max(currentCooldown, currentLockdown) or infinite
end)

RegisterCondition('ability.strong', { type = 'boolean', argParse = Util.ParseAbility }, function(owner, pet, ability)
    local modifier = GetAbilityAttackModifier(owner, pet, ability)
    return modifier and modifier > 1
end)

RegisterCondition('ability.weak', { type = 'boolean', argParse = Util.ParseAbility }, function(owner, pet, ability)
    local modifier = GetAbilityAttackModifier(owner, pet, ability)
    return modifier and modifier < 1
end)

RegisterCondition('ability.type', { type = 'equality', argParse = Util.ParseAbility, valueParse = Util.ParsePetType }, function(owner, pet, ability)
    return (select(7, C_PetBattles.GetAbilityInfo(owner, pet, ability)))
end)

RegisterCondition('round', { type = 'compare', owner = 'optional', pet = false, arg = false }, function(owner)
    if owner then
        return E.GetRound(owner)
    else
        return E.GetRound()
    end
end)

RegisterCondition('played', { type = 'boolean', arg = false }, function(owner, pet)
    return pet and E.IsPetPlayed(owner, pet)
end)

RegisterCondition('speed', { type = 'compare', arg = false }, C_PetBattles.GetSpeed)
RegisterCondition('power', { type = 'compare', arg = false }, C_PetBattles.GetPower)
RegisterCondition('level', { type = 'compare', arg = false }, C_PetBattles.GetLevel)

RegisterCondition('level.max', { type = 'boolean', arg = false }, function(owner, pet)
    return pet and C_PetBattles.GetLevel(owner, pet) == 25
end)

RegisterCondition('speed.fast', { type = 'boolean', pet = false, arg = false }, function(owner)
    return C_PetBattles.GetSpeed(owner, C_PetBattles.GetActivePet(owner)) > C_PetBattles.GetSpeed(getOpponentActivePet(owner))
end)

RegisterCondition('speed.slow', { type = 'boolean', pet = false, arg = false }, function(owner)
    return C_PetBattles.GetSpeed(owner, C_PetBattles.GetActivePet(owner)) < C_PetBattles.GetSpeed(getOpponentActivePet(owner))
end)

RegisterCondition('type', { type = 'equality', arg = false, valueParse = Util.ParsePetType }, function(owner, pet)
    return pet and C_PetBattles.GetPetType(owner, pet)
end)

RegisterCondition('quality', { type = 'compare', arg = false, valueParse = Util.ParseQuality }, function(owner, pet)
    return pet and (C_PetBattles.GetBreedQuality(owner, pet) + 1)
end)

RegisterCondition('exists', { type = 'boolean', pet = 1, arg = false }, function(owner, pet)
    return not not pet
end)

RegisterCondition('is', { type = 'boolean', pet = 1 }, function(owner, pet, other)
    return pet and Util.ComparePet(owner, pet, Util.ParseID(other) or other)
end)

RegisterCondition('id', { type = 'equality', pet = 1, arg = false }, function(owner, pet)
    return pet and C_PetBattles.GetPetSpeciesID(owner, pet) or 0
end)

RegisterCondition('collected', { type = 'boolean', arg = false }, function(owner, pet)
    local name = select(2, C_PetBattles.GetName(owner, pet))
    return select(2, C_PetJournal.FindPetIDByName(name)) ~= nil
end)

RegisterCondition('collected.count', { type = 'compare', arg = false }, function(owner, pet)
    local species = C_PetJournal.FindPetIDByName(select(2, C_PetBattles.GetName(owner, pet)))
    local obtainable = species and select(11, C_PetJournal.GetPetInfoBySpeciesID(species))
    if not obtainable then
        return 0
    end
    return species and select(1, C_PetJournal.GetNumCollectedInfo(species)) or 0
end)

RegisterCondition('collected.max', { type = 'compare', arg = false }, function(owner, pet)
    local species = C_PetJournal.FindPetIDByName(select(2, C_PetBattles.GetName(owner, pet)))
    local obtainable = species and select(11, C_PetJournal.GetPetInfoBySpeciesID(species))
    if not obtainable then
        return 0
    end
    return species and select(2, C_PetJournal.GetNumCollectedInfo(species)) or 0
end)

RegisterCondition('trap', { type = 'boolean', owner = 'not-allowed', pet = false, arg = false }, function()
    local usable, err = C_PetBattles.IsTrapAvailable()
    return usable or (not usable and err == 4)
end)
