local addonName, ns = ...

-- Fallback table (base). ns.L uses it when the client locale lacks a key.
ns._locales = ns._locales or {}
ns._locales.enUS = {

    MODE_SCRIPT         = "Script",

    -- Battle button.
    BTN_NO_SCRIPT       = "No script",
    BTN_TOOLTIP_TITLE   = "Match Script",
    BTN_TOOLTIP_LEFT    = "Press to run the next action of the loaded team's script.",

    -- Script state label.
    STEP_CODE_READY     = "Script ready",

    -- Code editor.
    CODE_TITLE          = "Code: %s",
    CODE_SAVE           = "Save",
    CODE_SAVED          = "Script saved.",
    CODE_ERROR          = "Script error",

    -- Button row + import.
    SCRIPT_SAVE_BTN     = "Save",
    SCRIPT_KIND_CODE    = "Code",
    SCRIPT_IMPORT_TD    = "Import Rematch",
    DEPLOY_BTN          = "Deploy",
    DEPLOY_DONE         = "Team deployed: %s (pets + abilities equipped).",
    DEPLOY_NO_TEAM      = "No loaded team to deploy.",
    DEPLOY_IN_COMBAT    = "Can't deploy during battle. Deploy before starting the fight.",
    DEPLOY_FAILED       = "Deploy failed.",

    -- Editor.
    EDIT_NO_TEAM        = "Load a team in MatchViewerLog to edit its script.",

    -- Right panel script mode.
    SCRIPT_TEAMS_MENU   = "Scripted teams (%d)",
    SCRIPT_NO_TEAMS     = "No scripted team yet",
    SCRIPT_HINT_LOAD    = "Load a team to create or edit its script.",
    SCRIPT_HINT_EMPTY   = "Write the script code below to create this team's script.",

    -- Battle key option (Options panel).
    OPTKEY_LABEL        = "Battle script key",
    OPTKEY_PRESS        = "Press a key... (Escape to cancel)",
    OPTKEY_TIP          = "Click, then press the key that will run the next script step during a pet battle.",

    -- Slash.
    SLASH_KEY_SET       = "key set to %s",
    SLASH_KEY_CURRENT   = "current key: %s",
    SLASH_HELP          = "/msvl import (Rematch scripts), /msvl key <KEY>, /msvl debug.",
    SLASH_DEBUG_ON      = "debug: on",
    SLASH_DEBUG_OFF     = "debug: off",
}
