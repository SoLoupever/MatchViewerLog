local addonName, ns = ...

-- ====================================================
-- BRIDGE — commandes slash du compagnon. La liaison a MVL est
-- faite dans Init (ns.MVL). Ici : /msvl pour la touche et le debug.
-- ====================================================

SLASH_MATCHSCRIPTVIEWERLOG1 = "/msvl"
SLASH_MATCHSCRIPTVIEWERLOG2 = "/matchscript"

SlashCmdList["MATCHSCRIPTVIEWERLOG"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")

    if cmd == "debug" then
        ns.DB.settings.debug = not ns.DB.settings.debug
        print("|cffa060ffMatchScriptViewerLog|r "
            .. ns.L(ns.DB.settings.debug and "SLASH_DEBUG_ON" or "SLASH_DEBUG_OFF"))
        return
    end

    if cmd == "import" then
        -- L'import tdBattlePetScript vit dans MatchViewerLog_Converter.
        if MatchViewerLog_Converter then MatchViewerLog_Converter.ImportTd(true) end
        return
    end

    if cmd == "why" then
        if ns.Runner and ns.Runner.Diagnose then ns.Runner.Diagnose() end
        return
    end

    if cmd == "deploy" then
        if ns.Deploy then ns.Deploy.Current(true) end
        return
    end

    if cmd == "autodeploy" then
        ns.DB.settings.autoDeploy = (rest ~= "off")
        print("|cffa060ffMatchScriptViewerLog|r auto-deploy: " .. (ns.DB.settings.autoDeploy and "on" or "off"))
        return
    end

    if cmd == "key" and rest and rest ~= "" then
        local key = rest:upper()
        ns.DB.settings.key = key
        ns.Fire("MSVL_KEY_CHANGED")
        print("|cffa060ffMatchScriptViewerLog|r " .. ns.L("SLASH_KEY_SET"):format(key))
        return
    end

    -- Sans argument : etat courant.
    print("|cffa060ffMatchScriptViewerLog|r "
        .. ns.L("SLASH_KEY_CURRENT"):format(ns.DB and ns.DB.settings.key or "A"))
    print("|cffa060ffMSVL|r " .. ns.L("SLASH_HELP"))
end
