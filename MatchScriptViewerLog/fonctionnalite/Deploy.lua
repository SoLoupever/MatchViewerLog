local addonName, ns = ...

-- ====================================================
-- DEPLOY — equipe reellement le combat : place les 3 mascottes de
-- l'equipe dans les emplacements de combat et regle leurs sorts sur
-- ceux nommes par le script. Sans ça, `use(NomSort:ID)` ne trouve pas
-- le sort (il n'est pas dans les 3 emplacements actifs) et le script
-- tombe sur change(). Ne peut se faire QUE hors combat.
-- ====================================================

local Deploy = ns.RegisterModule("Deploy", {})
ns.Deploy = Deploy

-- IDs de sorts references par use()/ability() dans un code.
local function AbilityIDsInCode(code)
    local ids = {}
    for cmd, arg in code:gmatch("(%a+)%s*%(([^)]*)%)") do
        if cmd == "use" or cmd == "ability" then
            local id = arg:match(":(%d+)") or arg:match("^%s*(%d+)%s*$")
            if id then ids[tonumber(id)] = true end
        end
    end
    return ids
end

local function InBattle()
    return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
end

-- Valeur d'un slot aleatoire "pioche dans la file d'XP" (cote MVL : ns.RANDOM_XP).
local RANDOM_XP = "xp"

-- Slot aleatoire par type : delegue a MVL (ns.MVL.PickRandomPetOfType), qui
-- est la source unique de selection (niveau puis rarete). On ne duplique pas
-- cette logique ici : ca garantit que ce qui est deploye correspond a ce que
-- l'apercu du panneau central (cote MVL) a montre.
-- typeIndex 0 ou nil = tout type (import Rematch "random:0").
local function RandomOwnedOfType(typeIndex, used)
    return ns.MVL.PickRandomPetOfType(typeIndex, used)
end

-- Slot aleatoire "XP" : delegue a MVL (ns.MVL.PickLevelingPet), qui applique
-- l'option de choix (proche de 25 / rare / aleatoire / plus bas niveau). Repli
-- sur l'ancien comportement (1re non utilisee) si MVL n'expose pas encore la
-- fonction (compatibilite avec une version MVL anterieure).
local function RandomXPPet(used)
    if ns.MVL.PickLevelingPet then return ns.MVL.PickLevelingPet(used) end
    local pets = ns.MVL.GetLevelingQueuePets and ns.MVL.GetLevelingQueuePets() or nil
    if type(pets) ~= "table" then return nil end
    for _, pid in ipairs(pets) do
        if type(pid) == "string" and pid:find("^BattlePet") and not used[pid] then
            return pid
        end
    end
    return nil
end

-- Deploie l'equipe teamID. Renvoie true, ou false + raison.
function Deploy.Team(teamID)
    if InBattle() then return false, "battle" end
    if InCombatLockdown() then return false, "combat" end
    local team = ns.MVL.GetTeam(teamID)
    if not team or type(team.pets) ~= "table" then return false, "noteam" end

    -- Si l'equipe deployee est celle EDITEE au centre, on prend sa compo en
    -- cours (pets/random/sorts) et non la version enregistree : ainsi un
    -- changement de mascotte est pris en compte sans avoir a sauvegarder.
    local cur = ns.MVL.GetCurrentTeam()
    local useCurrent = cur and cur.sourceTeamID == teamID
    local pets    = (useCurrent and cur.pets)    or team.pets
    local random  = (useCurrent and cur.random)  or team.random
    local special = (useCurrent and cur.special) or team.special
    local abil    = (useCurrent and cur.abil)    or team.abil

    -- 1) Placer les mascottes (slot aleatoire -> pet du type / de la file XP).
    -- Un slot Rematch "en montee de niveau" (special="leveling") n'a pas de
    -- petID exploitable et pas de random associe : sans ca on laisserait
    -- l'ancienne mascotte du loadout Blizzard (potentiellement niveau 25)
    -- au lieu de piocher une mascotte a monter, contrairement a l'intention
    -- du slot. On le traite comme un random "xp".
    local placed, used = {}, {}
    if ns.MVL.ResolveSlots and useCurrent then
        -- Meme resolution (memoisee) que le loadout MVL : fixes d'abord, pas de doublon.
        placed = ns.MVL.ResolveSlots()
        for slot = 1, 3 do
            local petID = placed[slot]
            if petID then pcall(C_PetJournal.SetPetLoadOutInfo, slot, petID) end
        end
    else
    for slot = 1, 3 do
        local petID = pets[slot]
        if random and random[slot] then
            if random[slot] == RANDOM_XP then
                petID = RandomXPPet(used)
            else
                petID = RandomOwnedOfType(random[slot], used)
            end
        elseif special and special[slot] == "leveling" then
            petID = RandomXPPet(used)
        end
        if type(petID) == "string" and petID:find("^BattlePet") then
            used[petID] = true
            placed[slot] = petID
            pcall(C_PetJournal.SetPetLoadOutInfo, slot, petID)
        end
    end
    end

    -- 2a) Sorts explicites de l'equipe/editeur (ce qui est affiche au centre).
    for slot = 1, 3 do
        local petID = placed[slot]
        local a = abil and abil[slot]
        if type(petID) == "string" and petID:find("^BattlePet") and type(a) == "table" then
            for tier = 1, 3 do
                if a[tier] then pcall(C_PetJournal.SetAbility, slot, tier, a[tier]) end
            end
        end
    end

    -- 2b) Sorts nommes par le script : priment quand la mascotte les
    -- possede (garde le script fonctionnel).
    if ns.Scripts.Has(teamID) then
        local want = AbilityIDsInCode(ns.Scripts.GetCode(teamID))
        for slot = 1, 3 do
            local petID = placed[slot]
            if type(petID) == "string" and petID:find("^BattlePet") then
                local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
                local list = speciesID and C_PetJournal.GetPetAbilityList(speciesID)
                if type(list) == "table" then
                    for idx, aid in ipairs(list) do
                        if want[aid] then
                            local tier = ((idx - 1) % 3) + 1   -- 1..6 -> paliers 1..3
                            pcall(C_PetJournal.SetAbility, slot, tier, aid)
                        end
                    end
                end
            end
        end
    end
    return true
end

-- Deploie l'equipe actuellement chargee dans MVL.
function Deploy.Current(verbose)
    local cur = ns.MVL.GetCurrentTeam()
    local id  = cur and cur.sourceTeamID
    if not id then
        if verbose then print("|cffa060ffMatchScriptViewerLog|r " .. ns.L("DEPLOY_NO_TEAM")) end
        return false
    end
    local ok, why = Deploy.Team(id)
    if verbose then
        if ok then print("|cffa060ffMatchScriptViewerLog|r " .. ns.L("DEPLOY_DONE"):format(cur.name or id))
        elseif why == "battle" or why == "combat" then print("|cffa060ffMSVL|r " .. ns.L("DEPLOY_IN_COMBAT"))
        else print("|cffa060ffMSVL|r " .. ns.L("DEPLOY_FAILED")) end
    end
    return ok
end

-- Auto-deploiement : quand on charge une equipe scriptee alors que la
-- fenetre MVL est ouverte (donc action volontaire) et hors combat.
ns.On("TEAM_LOADED", function()
    if ns.DB and ns.DB.settings and ns.DB.settings.autoDeploy == false then return end
    if InBattle() then return end
    if not (_G.MatchViewerLogFrame and MatchViewerLogFrame:IsShown()) then return end
    local cur = ns.MVL.GetCurrentTeam()
    local id  = cur and cur.sourceTeamID
    if id and ns.Scripts.Has(id) then Deploy.Team(id) end
end)
