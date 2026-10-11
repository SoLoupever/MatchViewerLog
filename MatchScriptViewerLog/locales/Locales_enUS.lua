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
    CODE_DELETE         = "Delete",
    CODE_DELETE_CONFIRM = "Delete the script of team \"%s\"?",
    CODE_DELETED        = "Script deleted.",

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

    -- Battle recording.
    REC_TIP_TITLE       = "Record a battle",
    REC_TIP_OFF         = "Click to record the next pet battles (log + conversion to script).",
    REC_TIP_ON          = "Recording is on. Click to stop.",
    REC_WIN_TITLE       = "Battle log",
    REC_ASK             = "Convert this battle into a script for \"%s\"?",
    REC_ASK_REPLACE     = "Replace the current script of \"%s\" with this battle?",
    REC_CONVERT         = "Convert",
    REC_REPLACE         = "Replace",
    REC_DISMISS         = "Dismiss",
    REC_CONVERTED       = "Script created for \"%s\" (%d actions).",
    REC_CONVERT_ERR     = "Conversion failed: %s",
    REC_NO_TEAM         = "No team loaded: can't convert.",
    REC_NO_ACTION       = "No action recorded.",

    -- Battle log lines.
    LOG_SIDE_ALLY       = "You",
    LOG_SIDE_ENEMY      = "Enemy",
    LOG_SIDE_WEATHER    = "Weather",
    LOG_PET_ENTRY       = "%s (lvl %d, %d HP)",
    LOG_ROUND           = "|cffffd100Round %d|r",
    LOG_ACT_ABILITY     = "%s uses %s",
    LOG_ACT_TRAP        = "Trap thrown",
    LOG_ACT_SKIP        = "Turn skipped",
    LOG_SWITCH_IN       = "%s enters the battle",
    LOG_DAMAGE          = "%s loses %d HP",
    LOG_HEAL            = "%s heals %d HP",
    LOG_AURA_ON         = "Effect %s on %s",
    LOG_AURA_OFF        = "Effect %s ended on %s",
    LOG_AURA_UNKNOWN    = "?",
    LOG_LEVEL           = "%s reaches level %d",
    LOG_XP              = "%s gains %d XP",
    LOG_CAPTURED        = "%s captured",
    LOG_STATUS_PET      = "%s %d/%d HP",
    LOG_STATUS          = "|cff909090End of round - you: %s | enemy: %s|r",
    LOG_WIN             = "|cff40ff40Victory|r",
    LOG_LOSS            = "|cffff6060Defeat|r",
    LOG_END             = "Battle ended",
}
