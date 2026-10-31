local addonName, ns = ...

-- ====================================================
-- THEME — theme actif de l'interface (mvl | blizzard).
-- Resolu une seule fois (1re lecture apres DB_READY) : un changement
-- est sauvegarde via ns.Options mais n'est applique qu'au rechargement.
-- Les modules UI ne testent pas le theme : ils passent par ns.Style.
-- ====================================================

local Theme = ns.RegisterModule("Theme", {})
ns.Theme = Theme

Theme.ORDER = { "mvl", "blizzard" }
Theme.LABEL = { mvl = "THEME_MVL", blizzard = "THEME_BLIZZARD" }

local VALID = { mvl = true, blizzard = true }
local active

-- Theme sauvegarde (peut differer de l'actif tant qu'on n'a pas recharge).
function Theme.Saved()
    local id = ns.Options.Get("theme")
    return VALID[id] and id or "mvl"
end

function Theme.Get()
    if not active then
        if not ns.DB then return "mvl" end   -- pas encore de SavedVariables
        active = Theme.Saved()
    end
    return active
end

function Theme.IsBlizzard() return Theme.Get() == "blizzard" end

function Theme.Set(id)
    if VALID[id] then ns.Options.Set("theme", id) end
end

function Theme.PendingReload()
    return active ~= nil and Theme.Saved() ~= active
end
