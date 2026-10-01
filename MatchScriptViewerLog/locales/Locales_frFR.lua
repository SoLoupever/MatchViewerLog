local addonName, ns = ...

ns._locales = ns._locales or {}
ns._locales.frFR = {

    MODE_SCRIPT         = "Script",

    -- Bouton de combat.
    BTN_NO_SCRIPT       = "Aucun script",
    BTN_TOOLTIP_TITLE   = "Script de combat",
    BTN_TOOLTIP_LEFT    = "Appuie pour executer l'action suivante du script de l'equipe chargee.",

    -- Libelles d'etat du script.
    STEP_CODE_READY     = "Script pret",

    -- Editeur de code.
    CODE_TITLE          = "Code : %s",
    CODE_SAVE           = "Enregistrer",
    CODE_SAVED          = "Script enregistre.",
    CODE_ERROR          = "Erreur de script",

    -- Rangee de boutons + import.
    SCRIPT_SAVE_BTN     = "Enregistrer",
    SCRIPT_KIND_CODE    = "Code",
    SCRIPT_IMPORT_TD    = "Importer Rematch",
    DEPLOY_BTN          = "Deployer",
    DEPLOY_DONE         = "Equipe deployee : %s (mascottes + sorts equipes).",
    DEPLOY_NO_TEAM      = "Aucune equipe chargee a deployer.",
    DEPLOY_IN_COMBAT    = "Impossible de deployer en combat. Deploie avant de lancer le combat.",
    DEPLOY_FAILED       = "Echec du deploiement.",

    -- Editeur.
    EDIT_NO_TEAM        = "Charge une equipe dans MatchViewerLog pour editer son script.",

    -- Mode script du panneau droit.
    SCRIPT_TEAMS_MENU   = "Equipes scriptees (%d)",
    SCRIPT_NO_TEAMS     = "Aucune equipe scriptee",
    SCRIPT_HINT_LOAD    = "Charge une equipe pour creer ou modifier son script.",
    SCRIPT_HINT_EMPTY   = "Ecris le code du script ci-dessous pour creer le script de cette equipe.",

    -- Option de touche (panneau Options).
    OPTKEY_LABEL        = "Touche du script en combat",
    OPTKEY_PRESS        = "Appuie sur une touche... (Echap : annuler)",
    OPTKEY_TIP          = "Clique puis appuie sur la touche qui executera l'etape suivante du script pendant un combat de mascottes.",

    -- Slash.
    SLASH_KEY_SET       = "touche definie sur %s",
    SLASH_KEY_CURRENT   = "touche actuelle : %s",
    SLASH_HELP          = "/msvl import (scripts Rematch), /msvl key <TOUCHE>, /msvl debug.",
    SLASH_DEBUG_ON      = "debug : actif",
    SLASH_DEBUG_OFF     = "debug : inactif",
}
