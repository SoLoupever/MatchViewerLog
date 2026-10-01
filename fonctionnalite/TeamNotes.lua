local addonName, ns = ...

-- ====================================================
-- TEAMNOTES — notes libres attachees a une equipe enregistree.
-- S'attache au meme module ns.Teams (patron TeamTargets/TeamQueue).
-- ====================================================

local Teams = ns.Teams

local MAX_LETTERS = 4000
Teams.NOTES_MAX = MAX_LETTERS

function Teams.GetNotes(id)
    local t = id and ns.DB and ns.DB.teams[id]
    return t and t.notes or ""
end

-- Texte vide = champ supprime (pas de cle morte dans la DB).
function Teams.SetNotes(id, text)
    local t = id and ns.DB and ns.DB.teams[id]
    if not t then return false end
    text = text or ""
    t.notes = (text ~= "") and text:sub(1, MAX_LETTERS) or nil
    ns.Fire("TEAM_NOTES_CHANGED", id)
    return true
end
