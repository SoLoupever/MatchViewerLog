local addonName, ns = ...

-- ====================================================
-- SCRIPTSTORE — script "code" par equipe (langage tdBattlePetScript,
-- importe ou ecrit), execute par ns.Engine. Donnees dans
-- MatchScriptViewerLogDB.scripts[teamID], indexees par teamID de MVL
-- (lien par cle stable, pas de couplage des SavedVariables).
-- ====================================================

local Scripts = ns.RegisterModule("ScriptStore", {})
ns.Scripts = Scripts

local function db() return ns.DB and ns.DB.scripts end

function Scripts.Get(teamID)
    local d = db()
    return d and teamID and d[teamID] or nil
end

local function Ensure(teamID)
    local d = db()
    if not d or not teamID then return nil end
    d[teamID] = d[teamID] or {}
    return d[teamID]
end
Scripts.Ensure = Ensure

-- L'equipe a-t-elle un script code exploitable ?
function Scripts.Has(teamID)
    local s = Scripts.Get(teamID)
    return s ~= nil and s.code ~= nil and s.code ~= ""
end

function Scripts.GetCode(teamID)
    local s = Scripts.Get(teamID)
    return s and s.code or ""
end

-- Valide via le moteur ; renvoie true, ou false + message d'erreur.
function Scripts.SetCode(teamID, code)
    local s = Ensure(teamID)
    if not s then return false end
    code = code or ""
    if code ~= "" and ns.Engine and ns.Engine.Build then
        local ok, err = ns.Engine.Build(code)
        if not ok then return false, err end
    end
    s.code = code
    ns.Fire("MSVL_SCRIPTS_CHANGED")
    return true
end

-- teamIDs ayant un script exploitable, tries par nom d'equipe MVL.
function Scripts.AllScriptedIDs()
    local d, out = db(), {}
    if not d then return out end
    for id in pairs(d) do
        if Scripts.Has(id) then out[#out + 1] = id end
    end
    table.sort(out, function(a, b)
        local ta = ns.MVL.GetTeam(a); local tb = ns.MVL.GetTeam(b)
        return (ta and ta.name or a) < (tb and tb.name or b)
    end)
    return out
end

-- Purge des scripts dont l'equipe MVL n'existe plus.
local function Purge()
    local d = db()
    local teams = ns.MVL.GetTeams()
    if not d or not teams then return end
    local changed = false
    for id in pairs(d) do
        if not teams[id] then d[id] = nil; changed = true end
    end
    if changed then ns.Fire("MSVL_SCRIPTS_CHANGED") end
end

ns.On("MSVL_DB_READY", function() ns.On("TEAMS_CHANGED", Purge) end)

-- Marqueur "team scriptee" cote MVL : on declare un provider (MVL affiche
-- l'icone draconien) et on demande un rafraichissement quand un script change.
if ns.MVL and ns.MVL.RegisterTeamScriptProvider then
    ns.MVL.RegisterTeamScriptProvider(function(teamID) return Scripts.Has(teamID) end)
end
ns.On("MSVL_SCRIPTS_CHANGED", function()
    if ns.MVL and ns.MVL.NotifyTeamsVisualChanged then ns.MVL.NotifyTeamsVisualChanged() end
end)
