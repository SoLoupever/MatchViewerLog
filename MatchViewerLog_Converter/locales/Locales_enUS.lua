local addonName, ns = ...

-- Fallback table (base). ns.L uses it when the client locale lacks a key.
ns._locales = ns._locales or {}
ns._locales.enUS = {
    -- Rematch import (teams / categories).
    IMPORT_DONE         = "%d teams imported (%d categories)",
    IMPORT_QUEUE_DONE   = "%d pets added to the leveling queue",
    IMPORT_NO_SOURCE    = "No source loaded. Enable Rematch, /reload, then /mvl import.",

    -- tdBattlePetScript import (scripts).
    IMPORT_TD_NO_SOURCE = "tdBattlePetScript not found (enable it, /reload).",
    IMPORT_TD_NO_TEAMS  = "No MVL teams. Open MatchViewerLog first.",
    IMPORT_TD_DONE      = "Scripts imported: %d matched of %d (%d without team).",
    IMPORT_TD_ERRORS    = "%d script(s) with syntax errors (please check).",
}
