local addonName, ns = ...

-- ====================================================
-- TEAMMIGRATIONS — migrations one-shot des donnees sauvegardees (jetable une
-- fois que tout le monde est passe par la nouvelle forme). Extrait de
-- TeamStore ; s'attache au meme module ns.Teams.
-- ====================================================

local Teams = ns.Teams

-- Migration unique : convertit les anciens slots "leveling" deja enregistres
-- en slot aleatoire "XP". Doit tourner avant RestoreState (donnee propre).
function Teams.MigrateSpecialLeveling()
    if not ns.DB then return end
    ns.DB.settings = ns.DB.settings or {}
    if ns.DB.settings._levelingMigrated then return end
    for _, t in pairs(ns.DB.teams or {}) do
        if type(t.special) == "table" then
            t.random = t.random or {}
            Teams.NormalizeLeveling(t.random, t.special)
        end
    end
    local last = ns.DB.settings.lastTeam
    if last and type(last.special) == "table" then
        last.random = last.random or {}
        Teams.NormalizeLeveling(last.random, last.special)
    end
    ns.DB.settings._levelingMigrated = true
end

-- Ordre impose : la migration doit tourner AVANT RestoreState (qui lirait
-- sinon une donnee pas encore nettoyee). Le bus DB_READY est FIFO (voir
-- core/Events.lua) : les deux inscriptions restent donc groupees ici plutot
-- que chacune a cote de sa fonction, meme si Teams.RestoreState est definie
-- dans TeamStore.lua.
ns.On("DB_READY", Teams.MigrateSpecialLeveling)
ns.On("DB_READY", Teams.RestoreState)
