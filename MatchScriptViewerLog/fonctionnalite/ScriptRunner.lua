local addonName, ns = ...

-- ====================================================
-- SCRIPTRUNNER — arme le script "code" de l'equipe chargee dans MVL :
-- ns.Engine evalue l'etat du combat et joue UNE action par appel.
-- IMPORTANT : les fonctions C_PetBattles sont PROTEGEES. ExecuteNext
-- ne doit etre appele QUE depuis le OnClick du bouton (clic/override).
-- ====================================================

local Runner = ns.RegisterModule("ScriptRunner", {})
ns.Runner = Runner

local ALLY = Enum.BattlePetOwner.Ally
local armedTeamID
local compiledCache = {}       -- [teamID] = compiled (runtime, non sauvegarde)

local function InBattle()
    return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
end

local function Compiled()
    if not armedTeamID then return nil end
    if compiledCache[armedTeamID] == nil then
        local code = ns.Scripts.GetCode(armedTeamID)
        compiledCache[armedTeamID] = (code ~= "" and ns.Engine and ns.Engine.Build(code)) or false
    end
    return compiledCache[armedTeamID] or nil
end

function Runner.IsArmed()
    return armedTeamID ~= nil and ns.Scripts.Has(armedTeamID)
end

function Runner.ArmForCurrentTeam()
    local cur = ns.MVL.GetCurrentTeam()
    local id  = cur and cur.sourceTeamID
    armedTeamID = (id and ns.Scripts.Has(id)) and id or nil
    ns.Fire("MSVL_RUNNER_CHANGED")
end

-- Info d'affichage de la prochaine action.
function Runner.NextStepInfo()
    if not armedTeamID then return nil end
    local compiled = Compiled()
    if not compiled then return nil end
    local action = InBattle() and ns.Engine.PeekNext(compiled) or nil
    return { code = true, label = action or ns.L("STEP_CODE_READY") }
end

-- Execute l'action courante. A APPELER UNIQUEMENT SUR CLIC (materiel).
function Runner.ExecuteNext()
    if not InBattle() or not armedTeamID then return false end
    local compiled = Compiled()
    if not compiled then return false end
    local acted = ns.Engine.RunOnce(compiled)   -- joue une action selon l'etat
    if acted then ns.Fire("MSVL_RUNNER_CHANGED") end
    return acted
end

-- ---- Diagnostic (/msvl why) : montre pourquoi chaque ligne passe ou non ----
local function condStr(c)
    if type(c) == "table" then return table.concat(c, " & ") elseif c then return c else return "" end
end

function Runner.Diagnose()
    if not InBattle() then print("|cffa060ffMSVL|r pas en combat."); return end
    print(string.format("|cffa060ffMSVL|r round=%s  petActif=%s  armed=%s",
        tostring(ns.Engine.GetRound()), tostring(C_PetBattles.GetActivePet(ALLY)), tostring(armedTeamID)))
    if not armedTeamID then print("  aucune equipe armee (charge une equipe avec script)"); return end
    local compiled = Compiled()
    if not compiled then print("  code non compile"); return end

    local Cond, Act = ns.Engine.Condition, ns.Engine.Action
    local function walk(item, depth)
        local pad = ("  "):rep(depth + 1)
        for _, v in ipairs(item) do
            local action, cond = v[1], v[2]
            local okC, resC = pcall(function() return Cond:Run(cond) end)
            local condOk = okC and resC and true or false
            if type(action) == "table" then
                print(string.format("%sif [%s] -> %s", pad, condStr(cond), tostring(condOk)))
                if condOk then walk(action, depth + 1) end
            else
                local testOk = false
                if condOk then
                    local okT, resT = pcall(function() return Act:Test(action) end)
                    testOk = okT and resT and true or false
                end
                print(string.format("%s%s  [%s]  cond=%s test=%s", pad, action, condStr(cond),
                    tostring(condOk), tostring(testOk)))
            end
        end
    end
    walk(compiled, 0)
end

-- ---- Cycle de vie du combat ----
ns.RegisterWowEvent("PET_BATTLE_OPENING_START", Runner.ArmForCurrentTeam)
ns.RegisterWowEvent("PET_BATTLE_OPENING_DONE", Runner.ArmForCurrentTeam)
ns.RegisterWowEvent("PET_BATTLE_CLOSE", function()
    armedTeamID = nil
    ns.Fire("MSVL_RUNNER_CHANGED")
end)
ns.RegisterWowEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", function() ns.Fire("MSVL_RUNNER_CHANGED") end)
ns.RegisterWowEvent("PET_BATTLE_PET_CHANGED", function() ns.Fire("MSVL_RUNNER_CHANGED") end)

ns.On("TEAM_LOADED", function()
    if InBattle() then Runner.ArmForCurrentTeam() end
end)

-- Un script modifie -> invalide le cache compile.
ns.On("MSVL_SCRIPTS_CHANGED", function() wipe(compiledCache) end)
