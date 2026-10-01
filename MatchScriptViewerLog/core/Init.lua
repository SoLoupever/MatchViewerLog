local addonName, ns = ...

-- ====================================================
-- INIT (MatchScriptViewerLog) — compagnon de MatchViewerLog.
-- On ne recree pas de bus ni de facade d'events : on REUTILISE
-- ceux de MVL via son API publique (_G.MatchViewerLog), pose en
-- dependance dure dans le .toc. La base sauvegardee du compagnon
-- lui est propre (isolation des donnees), initialisee a ADDON_LOADED.
-- ====================================================

ns.name = addonName

local M = _G.MatchViewerLog
if not M then
    -- Ne devrait pas arriver (## Dependencies: MatchViewerLog).
    print("|cffff4040MatchScriptViewerLog|r: MatchViewerLog introuvable.")
    return
end
ns.MVL = M

-- Bus + facade events : ceux de MVL (aucun systeme parallele).
ns.On               = M.On
ns.Fire             = M.Fire
ns.RegisterWowEvent = M.RegisterWowEvent

-- Registre de modules propre au compagnon.
ns.modules = {}
function ns.RegisterModule(name, tbl)
    tbl = tbl or {}
    ns.modules[name] = tbl
    return tbl
end

-- Traduction (locales chargees avant ce fichier).
local locale   = GetLocale()
local strings  = (ns._locales and (ns._locales[locale] or ns._locales.enUS)) or {}
local fallback = (ns._locales and ns._locales.enUS) or {}
function ns.L(key)
    return strings[key] or fallback[key] or key
end

function ns.Debug(...)
    if ns.DB and ns.DB.settings and ns.DB.settings.debug then
        print("|cffa060ffMSVL|r", ...)
    end
end

-- Base sauvegardee : disponible seulement a ADDON_LOADED.
ns.RegisterWowEvent("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then return end
    MatchScriptViewerLogDB = MatchScriptViewerLogDB or {}
    local db = MatchScriptViewerLogDB
    db.scripts  = db.scripts  or {}   -- [teamID] = { steps = {...} }
    db.settings = db.settings or {}
    if db.settings.key == nil then db.settings.key = "A" end
    ns.DB = db
    ns.Fire("MSVL_DB_READY")
end)
