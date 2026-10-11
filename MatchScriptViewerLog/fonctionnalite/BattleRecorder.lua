local addonName, ns = ...

-- ====================================================
-- BATTLERECORDER — enregistre un combat de mascottes (journal lisible +
-- actions du joueur) et le convertit en script "code" sur l'equipe chargee.
-- Actif seulement quand l'interrupteur (bouton Enregistrer) est arme.
-- L'API de combat n'expose pas l'attaque choisie par l'ennemi : on
-- journalise ses effets (degats, soins, effets, changements de mascotte).
-- ====================================================

local Rec = ns.RegisterModule("BattleRecorder", {})
ns.Recorder = Rec

local PB      = C_PetBattles
local ALLY    = Enum.BattlePetOwner.Ally
local ENEMY   = Enum.BattlePetOwner.Enemy
local WEATHER = Enum.BattlePetOwner.Weather
local ACTION  = Enum.BattlePetAction
local OWNERS  = { ALLY, ENEMY }
local MAX_LINES = 1000

local COLOR = { [ALLY] = "|cff66ccff", [ENEMY] = "|cffff7070", [WEATHER] = "|cffd0d0d0" }
local SIDE_KEY = { [ALLY] = "LOG_SIDE_ALLY", [ENEMY] = "LOG_SIDE_ENEMY", [WEATHER] = "LOG_SIDE_WEATHER" }

local session   -- combat en cours d'enregistrement, nil sinon

-- ---- Interrupteur ----

function Rec.IsArmed()
    return ns.DB and ns.DB.settings.recording or false
end

function Rec.SetArmed(on)
    if not ns.DB then return end
    on = on and true or false
    if (ns.DB.settings.recording or false) == on then return end
    ns.DB.settings.recording = on
    if not on then session = nil end
    ns.Fire("MSVL_RECORD_STATE", on)
    if on and not session and PB.IsInBattle() then Rec.Start() end
end

function Rec.Toggle() Rec.SetArmed(not Rec.IsArmed()) end

-- ---- Helpers de journal ----

local function Side(owner) return ns.L(SIDE_KEY[owner]) end

local function PetName(owner, pet)
    local name, species = PB.GetName(owner, pet)
    return name or species or "?"
end

local function Who(owner, pet)
    if owner == WEATHER or not pet then
        return COLOR[owner] .. Side(owner) .. "|r"
    end
    return COLOR[owner] .. PetName(owner, pet) .. " (" .. Side(owner) .. ")|r"
end

local function Add(text)
    local lines = session and session.lines
    if not lines or #lines >= MAX_LINES then return end
    lines[#lines + 1] = text
    ns.Fire("MSVL_LOG_LINE", text)
end

local function LogRoster()
    session.rosterDone = true
    session.active = PB.GetActivePet(ALLY)
    for _, owner in ipairs(OWNERS) do
        local parts = {}
        for i = 1, PB.GetNumPets(owner) do
            parts[i] = ns.L("LOG_PET_ENTRY"):format(PetName(owner, i), PB.GetLevel(owner, i), PB.GetMaxHealth(owner, i))
        end
        Add(COLOR[owner] .. Side(owner) .. "|r : " .. table.concat(parts, ", "))
    end
end

local function Status(owner)
    local pet = PB.GetActivePet(owner)
    if not pet then return "-" end
    return ns.L("LOG_STATUS_PET"):format(PetName(owner, pet), PB.GetHealth(owner, pet), PB.GetMaxHealth(owner, pet))
end

local function AuraName(owner, pet, instanceID)
    local cache = session.auras
    local key = owner .. ":" .. pet .. ":" .. instanceID
    for i = 1, PB.GetNumAuras(owner, pet) do
        local auraID, inst = PB.GetAuraInfo(owner, pet, i)
        if inst == instanceID then
            local _, name = PB.GetAbilityInfoByID(auraID)
            if name then cache[key] = name end
            break
        end
    end
    return cache[key] or ns.L("LOG_AURA_UNKNOWN")
end

-- Ajoute une action rejouable ; round = valeur du compteur du moteur.
local function AddAction(action, round, extraCond)
    local cond = "round=" .. round .. (extraCond and (" & " .. extraCond) or "")
    session.actions[#session.actions + 1] = action .. " [" .. cond .. "]"
end

-- ---- Cycle de vie ----

function Rec.Start()
    local cur = ns.MVL.GetCurrentTeam()
    session = {
        teamID  = cur and cur.sourceTeamID or nil,
        lines   = {},
        actions = {},
        auras   = {},
    }
    ns.Fire("MSVL_RECORD_START", session)
    if PB.IsInBattle() and PB.GetNumPets(ALLY) > 0 then LogRoster() end
end

local function EnsureSession()
    if not session and Rec.IsArmed() then Rec.Start() end
end

ns.RegisterWowEvent("PET_BATTLE_OPENING_START", EnsureSession)

ns.RegisterWowEvent("PET_BATTLE_OPENING_DONE", function()
    EnsureSession()
    if session and not session.rosterDone then LogRoster() end
end)

ns.RegisterWowEvent("PET_BATTLE_ACTION_SELECTED", function()
    if not session then return end
    local kind, index = PB.GetSelectedAction()
    if not kind or kind == ACTION.None then return end

    local round = ns.Engine.GetRound()
    session.selRound = round
    if round ~= session.lastRound then
        session.lastRound = round
        Add(ns.L("LOG_ROUND"):format(round))
    end
    if kind == ACTION.SwitchPet then return end   -- ligne ecrite au PET_CHANGED

    local active = PB.GetActivePet(ALLY)
    if kind == ACTION.Ability then
        local id, name = PB.GetAbilityInfo(ALLY, active, index)
        if not id then return end
        AddAction(("ability(%s:%d)"):format((name or ""):gsub("[%[%]]", ""), id), round)
        Add(ns.L("LOG_ACT_ABILITY"):format(Who(ALLY, active), name or "?"))
    elseif kind == ACTION.Trap then
        AddAction("catch", round)
        Add(ns.L("LOG_ACT_TRAP"))
    elseif kind == ACTION.Skip then
        AddAction("standby", round)
        Add(ns.L("LOG_ACT_SKIP"))
    end
end)

ns.RegisterWowEvent("PET_BATTLE_PET_CHANGED", function(owner)
    if not (session and session.rosterDone) then return end
    local pet = PB.GetActivePet(owner)
    if not pet then return end

    if owner == ALLY and pet ~= session.active then
        local forced = PB.GetHealth(ALLY, session.active) == 0
        local round  = forced and ns.Engine.GetRound() or session.selRound or ns.Engine.GetRound()
        AddAction("change(#" .. pet .. ")", round, forced and "self.dead" or nil)
        session.active = pet
    end
    Add(ns.L("LOG_SWITCH_IN"):format(Who(owner, pet)))
end)

ns.RegisterWowEvent("PET_BATTLE_HEALTH_CHANGED", function(owner, pet, change)
    if not session or not change or change == 0 then return end
    Add(ns.L(change < 0 and "LOG_DAMAGE" or "LOG_HEAL"):format(Who(owner, pet), math.abs(change)))
end)

ns.RegisterWowEvent("PET_BATTLE_AURA_APPLIED", function(owner, pet, instanceID)
    if not session then return end
    Add(ns.L("LOG_AURA_ON"):format(AuraName(owner, pet, instanceID), Who(owner, pet)))
end)

ns.RegisterWowEvent("PET_BATTLE_AURA_CANCELED", function(owner, pet, instanceID)
    if not session then return end
    Add(ns.L("LOG_AURA_OFF"):format(AuraName(owner, pet, instanceID), Who(owner, pet)))
end)

ns.RegisterWowEvent("PET_BATTLE_LEVEL_CHANGED", function(owner, pet, level)
    if not session then return end
    Add(ns.L("LOG_LEVEL"):format(Who(owner, pet), level))
end)

ns.RegisterWowEvent("PET_BATTLE_XP_CHANGED", function(owner, pet, xp)
    if not session or not xp or xp == 0 then return end
    Add(ns.L("LOG_XP"):format(Who(owner, pet), xp))
end)

ns.RegisterWowEvent("PET_BATTLE_CAPTURED", function(owner, pet)
    if not session then return end
    Add(ns.L("LOG_CAPTURED"):format(Who(owner, pet)))
end)

ns.RegisterWowEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", function()
    if not session then return end
    Add(ns.L("LOG_STATUS"):format(Status(ALLY), Status(ENEMY)))
end)

ns.RegisterWowEvent("PET_BATTLE_FINAL_ROUND", function(owner)
    if session then session.winner = owner end
end)

ns.RegisterWowEvent("PET_BATTLE_CLOSE", function()
    if not session then return end
    local s = session
    Add(ns.L(s.winner == ALLY and "LOG_WIN" or s.winner == ENEMY and "LOG_LOSS" or "LOG_END"))
    session = nil
    Rec.last = s
    ns.Fire("MSVL_RECORD_END", s)
end)

-- ---- Conversion en script ----

function Rec.BuildCode(s)
    return table.concat(s.actions, "\n")
end

-- true | false, message. Ecrase le script de l'equipe chargee au debut du combat.
function Rec.Convert(s)
    if not (s and s.teamID and ns.MVL.GetTeam(s.teamID)) then return false, ns.L("REC_NO_TEAM") end
    if #s.actions == 0 then return false, ns.L("REC_NO_ACTION") end
    return ns.Scripts.SetCode(s.teamID, Rec.BuildCode(s))
end
