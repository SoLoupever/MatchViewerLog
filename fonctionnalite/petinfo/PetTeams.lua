local addonName, ns = ...

-- ====================================================
-- PETTEAMS — donnee. Index petID -> teams enregistrees qui
-- l'utilisent. Reconstruit a la demande apres TEAMS_CHANGED.
-- ====================================================

local PetTeams = ns.RegisterModule("PetTeams", {})
ns.PetTeams = PetTeams

local index, dirty = {}, true
local EMPTY = {}

local function ByName(a, b) return (a.name or "") < (b.name or "") end

local function Rebuild()
    wipe(index)
    for _, t in pairs(ns.DB and ns.DB.teams or EMPTY) do
        for i = 1, 3 do
            local pid = t.pets and t.pets[i]
            if type(pid) == "string" then
                local list = index[pid]
                if not list then list = {}; index[pid] = list end
                if list[#list] ~= t then list[#list + 1] = t end
            end
        end
    end
    for _, list in pairs(index) do table.sort(list, ByName) end
    dirty = false
end

-- Liste (triee par nom) des teams contenant ce petID ; table vide sinon.
function PetTeams.Get(petID)
    if dirty then Rebuild() end
    return index[petID] or EMPTY
end

ns.On("TEAMS_CHANGED", function() dirty = true end)
ns.On("DB_READY", function() dirty = true end)
