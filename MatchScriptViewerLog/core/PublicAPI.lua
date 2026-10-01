local addonName, ns = ...

-- ====================================================
-- PUBLICAPI — expose _G.MatchScriptViewerLog pour le convertisseur
-- (MatchViewerLog_Converter), qui importe les scripts tdBattlePetScript.
-- On ne recree rien : ces helpers delèguent a ScriptStore / Engine et
-- ecrivent dans MatchScriptViewerLogDB. Aucune dependance dure : MSVL
-- fonctionne seul si le convertisseur est absent.
-- ====================================================

local API = {
    version = 1,

    -- Ecrit un script "code" sur une equipe. true si ok.
    StoreScriptCode = function(teamID, code)
        local s = ns.Scripts and ns.Scripts.Ensure(teamID)
        if not s then return false end
        s.code = code
        return true
    end,

    -- Valide un code via le moteur : true si compilable, false sinon.
    ValidateCode = function(code)
        if ns.Engine and ns.Engine.Build then
            return (ns.Engine.Build(code)) and true or false
        end
        return true
    end,

    -- Signale un changement de scripts (rafraichit l'UI + le marqueur MVL).
    NotifyScriptsChanged = function() if ns.Fire then ns.Fire("MSVL_SCRIPTS_CHANGED") end end,

    -- Drapeau "import deja fait" (evite de reimporter a chaque connexion).
    IsImported  = function() return ns.DB and ns.DB.settings and ns.DB.settings.imported or false end,
    SetImported = function(v) if ns.DB and ns.DB.settings then ns.DB.settings.imported = v and true or false end end,

    -- Traduction MSVL (repli ; le convertisseur a ses propres locales).
    L = function(key) return ns.L(key) end,
}

ns.API = API
_G.MatchScriptViewerLog = API
