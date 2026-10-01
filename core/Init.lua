local addonName, ns = ...

-- ====================================================
-- INIT — namespace, registre de modules, traduction, et surtout
-- l'initialisation de la base SAUVEGARDEE au bon moment.
--
-- IMPORTANT : les SavedVariables ne sont PAS disponibles au moment ou
-- les fichiers .lua s'executent ; WoW les restaure juste avant
-- ADDON_LOADED. On initialise donc ns.DB dans ADDON_LOADED, sinon on
-- pointe sur une table vide jamais sauvegardee (bug d'origine).
-- ====================================================

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
        print("|cff4da6ffMVL|r", ...)
    end
end

-- Base sauvegardee : initialisee a ADDON_LOADED (frame dediee car
-- core/Events.lua n'est pas encore charge a l'execution de ce fichier).
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loaded)
    if loaded ~= addonName then return end
    MatchViewerLogDB = MatchViewerLogDB or {}
    local db = MatchViewerLogDB
    db.teams      = db.teams      or {}
    db.categories = db.categories or {}
    db.settings   = db.settings   or {}
    ns.DB = db
    self:UnregisterEvent("ADDON_LOADED")
    if ns.Fire then ns.Fire("DB_READY") end
end)
