local addonName, ns = ...

-- ====================================================
-- PUBLICAPI — point d'extension unique et controle pour les
-- addons compagnons (ex: MatchScriptViewerLog). On ne recree
-- rien : on expose le bus, le registre de modules et un registre
-- de modes du panneau droit. Aucune dependance dure : MVL
-- fonctionne seul si aucun compagnon n'est present.
-- ====================================================

-- Registre des modes injectes dans la barre du panneau droit.
ns.rightPanelExtraModes = ns.rightPanelExtraModes or {}

-- Points d'extension export/import : un compagnon (ex: scripts) peut
-- ajouter/relire ses donnees dans le code d'echange d'une team, sans que
-- MVL connaisse le compagnon.
ns.exportHooks = ns.exportHooks or {}
ns.importHooks = ns.importHooks or {}

-- Convertisseurs de chaine (ex: code Rematch/Xufu) : un compagnon enregistre
-- fn(text) -> payload. La fenetre d'import (ui/TeamShare) les essaie quand la
-- case de conversion est cochee. MVL n'embarque aucun format etranger.
ns.stringImporters = ns.stringImporters or {}
-- Meme principe pour l'import d'une CATEGORIE entiere (plusieurs teams
-- collees a la suite) : fn(text) -> liste de payloads, ou nil.
ns.categoryStringImporters = ns.categoryStringImporters or {}

-- Controles d'options injectes par un compagnon dans le panneau Options.
-- def = { build = f(parent) -> frame (hauteur definie), sync = f() (optionnel) }.
-- MVL ne connait pas le contenu : il pose le frame sous les options natives et
-- appelle sync a chaque ouverture. Meme principe que rightPanelExtraModes.
ns.optionControls = ns.optionControls or {}

-- Fournisseurs "cette equipe a-t-elle un script ?" (ex: MatchScriptViewerLog).
-- MVL ne connait pas le stockage du compagnon : il interroge les providers.
ns.teamScriptProviders = ns.teamScriptProviders or {}
function ns.TeamHasScript(teamID)
    if not teamID then return false end
    for _, fn in ipairs(ns.teamScriptProviders) do
        local ok, has = pcall(fn, teamID)
        if ok and has then return true end
    end
    return false
end

local API = {
    version = 1,

    -- Valeur d'un slot aleatoire "pioche dans la file d'XP" (= ns.RANDOM_XP).
    -- Expose pour que le convertisseur mappe les slots leveling Rematch dessus
    -- sans redefinir la constante de son cote.
    RANDOM_XP = ns.RANDOM_XP,

    -- Bus interne (memes fonctions que le noyau, pas un doublon).
    On               = function(evt, fn) return ns.On(evt, fn) end,
    Fire             = function(evt, ...) return ns.Fire(evt, ...) end,
    RegisterWowEvent = function(evt, fn) return ns.RegisterWowEvent(evt, fn) end,
    RegisterModule   = function(name, tbl) return ns.RegisterModule(name, tbl) end,

    -- Acces lecture aux donnees d'equipes (le compagnon ne stocke pas ici).
    GetDB          = function() return ns.DB end,
    GetTeams       = function() return ns.DB and ns.DB.teams end,
    GetTeam        = function(id) return ns.DB and ns.DB.teams and ns.DB.teams[id] end,
    GetCurrentTeam = function() return ns.Teams and ns.Teams.current end,
    -- File d'XP (mascottes a monter) : pour les slots aleatoires "XP".
    GetLevelingQueuePets = function() return ns.Teams and ns.Teams.QueuePets() end,
    -- Choix du slot "XP" selon l'option xpPick (used = {petID=true} deja places).
    -- Source unique : le compagnon deploie exactement ce que cette fonction rend.
    PickLevelingPet = function(used)
        return ns.Teams and ns.Teams.PickLevelingPet(used)
    end,
    -- Meilleure mascotte possedee pour un slot "aleatoire par type" (niveau
    -- puis rarete). Source unique partagee avec l'apercu du panneau central.
    PickRandomPetOfType = function(typeIndex, excluded)
        return ns.Teams and ns.Teams.PickRandomOfType(typeIndex, excluded)
    end,
    SelectTeam     = function(id)
        local t = ns.DB and ns.DB.teams and ns.DB.teams[id]
        if t and ns.Teams then ns.Teams.Load(t) end
    end,

    -- Ancre du panneau droit (le compagnon y greffe son UI de mode).
    GetRightPanel = function() return ns.Frame and ns.Frame.right end,

    -- Ajoute un mode a droite des modes de base (Teams/Cibles/File).
    -- def = { key, label, color = {r,g,b}, onShow = f(panel), onHide = f(panel) }
    RegisterRightPanelMode = function(def)
        if type(def) ~= "table" or not def.key then return end
        for _, m in ipairs(ns.rightPanelExtraModes) do
            if m.key == def.key then return end -- deja enregistre
        end
        ns.rightPanelExtraModes[#ns.rightPanelExtraModes + 1] = def
        if ns.Fire then ns.Fire("MVL_RIGHTMODES_CHANGED") end
    end,

    -- Ajoute un controle dans le panneau Options (sous les options natives).
    -- def = { build = f(parent) -> frame, sync = f() }. Le compagnon fournit
    -- ses propres strings : MVL n'embarque aucun libelle du compagnon.
    RegisterOptionControl = function(def)
        if type(def) ~= "table" or type(def.build) ~= "function" then return end
        ns.optionControls[#ns.optionControls + 1] = def
        if ns.Fire then ns.Fire("MVL_OPTIONCTRLS_CHANGED") end
    end,

    -- Export : fn(payload, teamID) enrichit la table exportee (ex: script).
    RegisterExportHook = function(fn)
        if type(fn) == "function" then ns.exportHooks[#ns.exportHooks + 1] = fn end
    end,
    -- Import : fn(payload, newTeamID) relit ses donnees apres creation.
    RegisterImportHook = function(fn)
        if type(fn) == "function" then ns.importHooks[#ns.importHooks + 1] = fn end
    end,

    -- Un compagnon declare pouvoir dire si une team a un script : fn(teamID)->bool.
    RegisterTeamScriptProvider = function(fn)
        if type(fn) == "function" then ns.teamScriptProviders[#ns.teamScriptProviders + 1] = fn end
    end,
    TeamHasScript = function(id) return ns.TeamHasScript(id) end,
    -- Le compagnon demande a MVL de rafraichir l'affichage des teams
    -- (ex: apres modification d'un script) sans coupler leurs internes.
    NotifyTeamsVisualChanged = function() if ns.Fire then ns.Fire("TEAMS_CHANGED") end end,

    -- Restyle une barre de defilement (Faux/UIPanel) facon MVL : le compagnon
    -- reutilise le meme skin fin bleu clair que les panneaux natifs.
    SkinScrollBar = function(scroll) if ns.ScrollSkin then ns.ScrollSkin.Apply(scroll) end end,

    -- Traduction MVL (repli ; le compagnon a ses propres locales).
    L = function(key) return ns.L(key) end,

    -- ---- Points d'entree pour le convertisseur (MatchViewerLog_Converter) ----
    -- L'import ecrit dans MatchViewerLogDB via GetDB() ; ces helpers evitent
    -- au convertisseur de toucher les internes (ns.Teams / ns.Cats / Const).
    QueueImport               = function(ids) return (ns.Teams and ns.Teams.QueueImport(ids)) or 0 end,
    GetDefaultCategories      = function() return (ns.Cats and ns.Cats.Defaults()) or {} end,
    EnsureCategoriesIntegrity = function() if ns.Cats and ns.Cats.EnsureIntegrity then ns.Cats.EnsureIntegrity() end end,
    GetBreedName              = function(breedID) return ns.BREED_NAMES and ns.BREED_NAMES[breedID] end,
    -- Enregistre un convertisseur de chaine fn(text) -> payload (utilise par
    -- la case xufu de la fenetre d'import).
    RegisterStringImporter    = function(fn)
        if type(fn) == "function" then ns.stringImporters[#ns.stringImporters + 1] = fn end
    end,
    -- Enregistre un convertisseur de chaine "categorie" fn(text) -> {payload,...}
    -- (utilise par la case xufu du mode "Importer une categorie").
    RegisterCategoryStringImporter = function(fn)
        if type(fn) == "function" then ns.categoryStringImporters[#ns.categoryStringImporters + 1] = fn end
    end,
}

ns.API = API
_G.MatchViewerLog = API
