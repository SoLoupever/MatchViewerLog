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
    CODE_DELETE         = "Supprimer",
    CODE_DELETE_CONFIRM = "Supprimer le script de l'equipe \"%s\" ?",
    CODE_DELETED        = "Script supprime.",

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

    -- Enregistrement de combat.
    REC_TIP_TITLE       = "Enregistrer un combat",
    REC_TIP_OFF         = "Clique pour enregistrer les prochains combats de mascottes (journal + conversion en script).",
    REC_TIP_ON          = "Enregistrement actif. Clique pour l'arreter.",
    REC_WIN_TITLE       = "Journal de combat",
    REC_ASK             = "Convertir ce combat en script pour \"%s\" ?",
    REC_ASK_REPLACE     = "Remplacer le script actuel de \"%s\" par ce combat ?",
    REC_CONVERT         = "Convertir",
    REC_REPLACE         = "Remplacer",
    REC_DISMISS         = "Ignorer",
    REC_CONVERTED       = "Script cree pour \"%s\" (%d actions).",
    REC_CONVERT_ERR     = "Conversion impossible : %s",
    REC_NO_TEAM         = "Aucune equipe chargee : conversion impossible.",
    REC_NO_ACTION       = "Aucune action enregistree.",

    -- Lignes du journal de combat.
    LOG_SIDE_ALLY       = "Vous",
    LOG_SIDE_ENEMY      = "Ennemi",
    LOG_SIDE_WEATHER    = "Meteo",
    LOG_PET_ENTRY       = "%s (niv. %d, %d PV)",
    LOG_ROUND           = "|cffffd100Tour %d|r",
    LOG_ACT_ABILITY     = "%s lance %s",
    LOG_ACT_TRAP        = "Piege lance",
    LOG_ACT_SKIP        = "Tour passe",
    LOG_SWITCH_IN       = "%s entre au combat",
    LOG_DAMAGE          = "%s perd %d PV",
    LOG_HEAL            = "%s recupere %d PV",
    LOG_AURA_ON         = "Effet %s sur %s",
    LOG_AURA_OFF        = "Fin de l'effet %s sur %s",
    LOG_AURA_UNKNOWN    = "?",
    LOG_LEVEL           = "%s passe niveau %d",
    LOG_XP              = "%s gagne %d XP",
    LOG_CAPTURED        = "%s capture",
    LOG_STATUS_PET      = "%s %d/%d PV",
    LOG_STATUS          = "|cff909090Fin du tour - vous : %s | ennemi : %s|r",
    LOG_WIN             = "|cff40ff40Victoire|r",
    LOG_LOSS            = "|cffff6060Defaite|r",
    LOG_END             = "Combat termine",
}
