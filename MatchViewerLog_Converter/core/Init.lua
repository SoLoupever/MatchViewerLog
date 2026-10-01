local addonName, ns = ...

-- ====================================================
-- INIT (MatchViewerLog_Converter) — convertisseur d'import, dependance
-- de MatchViewerLog. On ne stocke rien en propre : les imports ecrivent
-- dans MatchViewerLogDB (teams/categories) et MatchScriptViewerLogDB
-- (scripts) via les API publiques _G.MatchViewerLog / _G.MatchScriptViewerLog.
-- On REUTILISE le bus d'events de MVL (aucun systeme parallele).
-- ====================================================

ns.name = addonName

local MVL = _G.MatchViewerLog
if not MVL then
    -- Ne devrait pas arriver (## Dependencies: MatchViewerLog).
    print("|cffff4040MatchViewerLog_Converter|r: MatchViewerLog introuvable.")
    return
end
ns.MVL = MVL
-- MSVL est optionnel : present seulement si MatchScriptViewerLog est actif.
ns.MSVL = _G.MatchScriptViewerLog

-- Bus + facade events : ceux de MVL.
ns.On               = MVL.On
ns.Fire             = MVL.Fire
ns.RegisterWowEvent = MVL.RegisterWowEvent

-- Registre de modules propre au convertisseur.
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

-- API globale : declencheurs appeles par les slash/boutons de MVL et MSVL.
-- Remplie par les fichiers source (ImportRematch, Diagnose, ImportTd).
ns.API = {}
_G.MatchViewerLog_Converter = ns.API
