local addonName, ns = ...

ns._locales = ns._locales or {}
ns._locales.frFR = {
    -- Import Rematch (teams / categories).
    IMPORT_DONE         = "%d equipes importees (%d categories)",
    IMPORT_QUEUE_DONE   = "%d mascottes ajoutees a la file d'XP",
    IMPORT_NO_SOURCE    = "Aucune source chargee. Active Rematch, fais /reload, puis /mvl import.",

    -- Import tdBattlePetScript (scripts).
    IMPORT_TD_NO_SOURCE = "tdBattlePetScript introuvable (active-le, /reload).",
    IMPORT_TD_NO_TEAMS  = "Aucune equipe MVL. Ouvre MatchViewerLog d'abord.",
    IMPORT_TD_DONE      = "Scripts importes : %d rattaches sur %d (%d sans equipe).",
    IMPORT_TD_ERRORS    = "%d script(s) avec erreur de syntaxe (a verifier).",
}
