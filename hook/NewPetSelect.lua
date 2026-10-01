local addonName, ns = ...

-- ====================================================
-- NEWPETSELECT — clic sur le toast Blizzard "nouvelle mascotte".
-- Blizzard ouvre le Codex et appelle PetJournal_SelectPet(journal,
-- petID). Comme JournalTakeover masque le journal Blizzard, cette
-- selection n'etait pas reportee : on la relaie vers la liste MVL
-- (selection + defilement). Aucune dependance dure : si la fonction
-- Blizzard n'existe pas, on ne fait rien.
-- ====================================================

ns.RegisterModule("NewPetSelect", {})

local hooked = false

local function Relay(_, petID)
    if type(petID) ~= "string" then return end
    ns.SetSelectedPet(petID)
    if ns.MVL_RevealPet then ns.MVL_RevealPet(petID) end
end

local function Install()
    if hooked then return end
    if type(PetJournal_SelectPet) ~= "function" then return end
    hooksecurefunc("PetJournal_SelectPet", Relay)
    hooked = true
end

if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_Collections") and _G.PetJournal_SelectPet then
    Install()
else
    ns.RegisterWowEvent("ADDON_LOADED", function(loaded)
        if loaded == "Blizzard_Collections" then Install() end
    end)
end
