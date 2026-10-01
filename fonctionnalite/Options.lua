local addonName, ns = ...

-- ====================================================
-- OPTIONS — preferences d'affichage persistees (ns.DB.settings.options).
-- Etat pur : l'UI (ui/OptionsPanel) lit/ecrit via Get/Set, les consommateurs
-- (LeftPanel) lisent via Get. Un changement diffuse ROSTER_REFRESH (systeme
-- existant) : pas d'event parallele. Les defauts = comportement actuel.
-- ====================================================

local Options = ns.RegisterModule("Options", {})
ns.Options = Options

-- sort : ordre de la liste de gauche.
--   level_name        favoris -> niveau desc -> nom            (defaut actuel)
--   level_rarity_name favoris -> niveau desc -> rarete desc -> nom
--   rarity_name       favoris -> rarete desc -> nom
--   name              favoris -> nom
-- nonBattleLast : mascottes non-combattantes reléguées tout en bas.
-- xpPick : choix du slot aleatoire "XP" (file d'XP).
--   closest25       la plus proche de 25 (defaut actuel)
--   closest25_rare  la plus proche de 25, qualite rare (bleu) uniquement
--   random          une au hasard, varie a chaque deploiement
--   lowest          plus bas niveau d'abord
-- baseName : afficher les mascottes renommees avec leur nom de base
--   (le nom personnalise est ignore dans les listes).
local DEFAULTS = { sort = "level_name", nonBattleLast = false, xpPick = "closest25", baseName = false }

function Options.Get(key)
    local o = ns.DB and ns.DB.settings and ns.DB.settings.options
    if o and o[key] ~= nil then return o[key] end
    return DEFAULTS[key]
end

function Options.Set(key, val)
    if DEFAULTS[key] == nil then return end
    if not (ns.DB and ns.DB.settings) then return end
    ns.DB.settings.options = ns.DB.settings.options or {}
    ns.DB.settings.options[key] = val
    -- ROSTER_REFRESH : la liste de gauche (tri). MVL_OPTIONS_CHANGED : les autres
    -- consommateurs (ex: File d'XP a droite) sans re-trier la gauche pour rien.
    ns.Fire("ROSTER_REFRESH")
    ns.Fire("MVL_OPTIONS_CHANGED")
end

-- Nom a afficher pour une mascotte : nom de base si l'option est active,
-- sinon le nom personnalise (repli sur le nom de base). Point unique pour
-- que toutes les listes restent coherentes.
function Options.DisplayName(customName, baseName)
    if Options.Get("baseName") then return baseName or customName end
    return customName or baseName
end
