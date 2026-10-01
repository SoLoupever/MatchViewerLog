local addonName, ns = ...

-- ====================================================
-- TDSCRIPT — importe les scripts de tdBattlePetScript (Pet Battle
-- Scripts) et les rattache aux equipes MVL. Les scripts sont dans
-- TD_DB_BATTLEPETSCRIPT_GLOBAL.scripts.Rematch[teamID] = { name, code },
-- indexes par teamID Rematch. On retrouve l'equipe MVL correspondante
-- par la MEME cle que l'import Rematch (nom + mascottes triees), via
-- Rematch5SavedTeams. Repli par nom si besoin. Ecrit les scripts dans
-- MatchScriptViewerLogDB via l'API publique de MSVL.
-- ====================================================

local MVL  = ns.MVL
local MSVL = ns.MSVL
if not MSVL then return end   -- MatchScriptViewerLog absent : rien a importer.

local Import = ns.RegisterModule("ImportTd", {})

-- Reproduit exactement la cle d'import de MVL (source/Import.lua).
local function TeamKey(name, pets)
    local ids = {}
    for _, p in ipairs(pets or {}) do ids[#ids + 1] = tostring(p) end
    table.sort(ids)
    return (name or ""):lower() .. "|" .. table.concat(ids, ",")
end

-- Ecrit le code sur l'equipe MVL (sans passer par la validation stricte,
-- pour ne perdre aucun script ; la validation sert au rapport).
local function StoreCode(teamID, code)
    MSVL.StoreScriptCode(teamID, code)
end

function Import.Run(verbose)
    -- AceDB range les donnees sous .global (cle du fichier SavedVariables).
    local td = _G.TD_DB_BATTLEPETSCRIPT_GLOBAL
    local scripts = td and td.global and td.global.scripts
    if type(scripts) ~= "table" then
        if verbose then print("|cffa060ffMatchScriptViewerLog|r " .. ns.L("IMPORT_TD_NO_SOURCE")) end
        return 0, 0, 0
    end

    local teams = MVL.GetTeams()
    if type(teams) ~= "table" then
        if verbose then print("|cffa060ffMatchScriptViewerLog|r " .. ns.L("IMPORT_TD_NO_TEAMS")) end
        return 0, 0, 0
    end

    -- Index des equipes MVL : par srcKey et par nom.
    local byKey, byName = {}, {}
    for id, t in pairs(teams) do
        if t.srcKey then byKey[t.srcKey] = id end
        if t.name then byName[t.name:lower()] = byName[t.name:lower()] or id end
    end

    local rematch = _G.Rematch5SavedTeams

    local function FindTeam(scriptKey, data)
        -- 1) via la team Rematch d'origine (cle exacte nom+mascottes).
        local rt = rematch and rematch[scriptKey]
        if rt then
            local id = byKey[TeamKey(rt.name, rt.pets)]
            if id then return id end
        end
        -- 2) repli par nom du script.
        if data.name then return byName[data.name:lower()] end
    end

    local matched, total, errors = 0, 0, 0

    local function Process(bucket)
        if type(bucket) ~= "table" then return end
        for scriptKey, data in pairs(bucket) do
            if type(data) == "table" and type(data.code) == "string" and data.code ~= "" then
                total = total + 1
                local id = FindTeam(scriptKey, data)
                if id then
                    StoreCode(id, data.code)
                    matched = matched + 1
                    if not MSVL.ValidateCode(data.code) then errors = errors + 1 end
                end
            end
        end
    end

    Process(scripts.Rematch)
    Process(scripts.Rematch4)

    MSVL.SetImported(true)
    MSVL.NotifyScriptsChanged()

    if verbose then
        print("|cffa060ffMatchScriptViewerLog|r " ..
            ns.L("IMPORT_TD_DONE"):format(matched, total, total - matched))
        if errors > 0 then
            print("|cffa060ffMSVL|r " .. ns.L("IMPORT_TD_ERRORS"):format(errors))
        end
    end
    return matched, total, errors
end

-- Declencheur expose (slash /msvl import, bouton "Importer Rematch").
ns.API.ImportTd = Import.Run

-- Import automatique une seule fois (apres que MVL a charge ses equipes).
local function AutoRun()
    if not MSVL.IsImported() then
        if _G.TD_DB_BATTLEPETSCRIPT_GLOBAL then Import.Run(false) end
    end
end

ns.RegisterWowEvent("PLAYER_LOGIN", function() C_Timer.After(3, AutoRun) end)
