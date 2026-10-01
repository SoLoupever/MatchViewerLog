local addonName, ns = ...

-- ====================================================
-- SCRIPTSHARE — branche le script "code" de l'equipe dans l'export/
-- import de MVL via ses hooks. MVL transporte un blob OPAQUE : lui seul
-- (ici) sait le lire/ecrire. Forme : "code:<code>".
-- ====================================================

ns.RegisterModule("ScriptShare", {})

local function Serialize(teamID)
    if not (teamID and ns.Scripts and ns.Scripts.Has(teamID)) then return nil end
    return "code:" .. (ns.Scripts.GetCode(teamID) or "")
end

-- Repli "seq:" volontairement absent : l'ancienne forme sequence n'est
-- plus lue, un vieux code partage avec ce prefixe est ignore (pas d'erreur).
local function Deserialize(teamID, blob)
    if type(blob) ~= "string" or not teamID then return end
    if blob:sub(1, 5) ~= "code:" then return end
    local s = ns.Scripts.Ensure(teamID)
    if not s then return end
    s.code = blob:sub(6)
    ns.Fire("MSVL_SCRIPTS_CHANGED")
end

-- Enregistrement des hooks aupres de MVL (aucun couplage inverse).
if ns.MVL.RegisterExportHook then
    ns.MVL.RegisterExportHook(function(payload, teamID)
        local blob = Serialize(teamID)
        if blob then payload.scriptBlob = blob end
    end)
end
if ns.MVL.RegisterImportHook then
    ns.MVL.RegisterImportHook(function(payload, newTeamID)
        if payload.scriptBlob then Deserialize(newTeamID, payload.scriptBlob) end
    end)
end
