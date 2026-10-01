local addonName, ns = ...

-- ====================================================
-- BREED — donnee. On delegue a BattlePetBreedID (comme
-- Rematch lit dans BPBID) : GetBreedID_Journal(petID) renvoie
-- directement "S/S", "B/B", ... Le breed n'existe pas dans
-- l'API WoW ; sans BattlePetBreedID, on ne montre rien.
-- ====================================================

local Breed = ns.RegisterModule("Breed", {})
ns.Breed = Breed

function Breed.IsAvailable()
    return type(_G.GetBreedID_Journal) == "function"
end

-- Renvoie "S/S" / "B/B" / ... ou nil.
function Breed.GetForPetID(petID)
    if not petID then return nil end
    local f = _G.GetBreedID_Journal
    if not f then return nil end
    local ok, name = pcall(f, petID)
    if ok and type(name) == "string" and name ~= "" and not name:find("ERR") then
        return name
    end
    return nil
end
