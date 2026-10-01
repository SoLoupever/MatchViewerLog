local addonName, ns = ...

-- /mvl : ouvre le Codex sur l'onglet mascottes. /mvl debug : bascule le debug.

SLASH_MATCHVIEWERLOG1 = "/mvl"
SLASH_MATCHVIEWERLOG2 = "/matchviewerlog"

-- Ouvre/ferme le Codex sur l'onglet mascottes : c'est le journal
-- Blizzard qui est ouvert, et JournalTakeover met MatchViewerLog a sa
-- place. Aucune fenetre autonome : une seule fenetre, celle du Codex.
local function OpenPetJournal()
    if CollectionsJournal and CollectionsJournal:IsShown() then
        HideUIPanel(CollectionsJournal)
    elseif ToggleCollectionsJournal then
        ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS or 2)
    end
end

SlashCmdList["MATCHVIEWERLOG"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "debug" then
        ns.DB.settings.debug = not ns.DB.settings.debug
        print("|cff4da6ffMatchViewerLog|r "
            .. ns.L(ns.DB.settings.debug and "SLASH_DEBUG_ON" or "SLASH_DEBUG_OFF"))
        return
    end

    if msg == "import" then
        -- L'import Rematch vit dans MatchViewerLog_Converter (dependance).
        if MatchViewerLog_Converter then
            MatchViewerLog_Converter.Diagnose()
            MatchViewerLog_Converter.ImportRematch(true)
        end
        return
    end

    OpenPetJournal()
end
