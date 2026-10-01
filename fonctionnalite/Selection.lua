local addonName, ns = ...

-- ====================================================
-- SELECTION — mascotte "epinglee" pour la carte de detail (ns.PetCard) :
-- une mascotte possedee (petID) OU une espece non possedee (speciesID), les
-- deux mutuellement exclusives. N'est pas une notion d'equipe (independant
-- de TeamStore) : consomme par LeftPanel, RightPanel, BottomBar et PetCard.
-- ====================================================

-- Deux selections mutuellement exclusives : une mascotte possedee (petID) OU
-- une espece non possedee (speciesID), pour epingler sa carte.
function ns.SetSelectedPet(petID)
    ns.selectedPetID = petID
    ns.selectedSpecies = nil
    ns.Fire("PET_SELECTED")
end

function ns.SetSelectedSpecies(speciesID)
    ns.selectedSpecies = speciesID
    ns.selectedPetID = nil
    ns.Fire("PET_SELECTED")
end
