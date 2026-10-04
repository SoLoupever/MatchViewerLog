local addonName, ns = ...

-- ====================================================
-- JOURNALFILTERS — la liste de gauche lit le journal Blizzard filtre.
-- Les filtres (collecte, sources, types, recherche) sont globaux et
-- persistants : on les remet a zero a la creation de la fenetre, et on
-- retablit collecte/sources si le journal revient vide alors que le
-- joueur possede des mascottes.
-- ====================================================

local Filters = ns.RegisterModule("JournalFilters", {})
ns.JournalFilters = Filters

local FILTER_COLLECTED     = _G.LE_PET_JOURNAL_FILTER_COLLECTED
local FILTER_NOT_COLLECTED = _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED

local function ResetCollection()
    local J = C_PetJournal
    if J.SetFilterChecked and FILTER_COLLECTED and FILTER_NOT_COLLECTED then
        J.SetFilterChecked(FILTER_COLLECTED, true)
        J.SetFilterChecked(FILTER_NOT_COLLECTED, true)
    end
    if J.SetAllPetSourcesChecked then J.SetAllPetSourcesChecked(true) end
end

function Filters.ResetAll()
    ResetCollection()
    C_PetJournal.SetAllPetTypesChecked(true)
    ns.petSearchText = nil
    C_PetJournal.SetSearchFilter("")
    ns.Fire("ROSTER_REFRESH")
end

ns.On("MVL_FRAME_READY", Filters.ResetAll)

-- Journal vide malgre des mascottes possedees : filtre Blizzard residuel.
ns.On("MVL_FRAME_SHOW", function()
    local num, owned = C_PetJournal.GetNumPets()
    if (num or 0) > 0 or (owned or 0) == 0 then return end
    if ns.petSearchText and ns.petSearchText ~= "" then return end
    ResetCollection()
    ns.Fire("ROSTER_REFRESH")
end)
