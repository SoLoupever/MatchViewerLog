local addonName, ns = ...

-- ====================================================
-- PETMENU — menu clic-droit sur une mascotte (gauche) : invoquer/
-- renvoyer, favori/retirer, mise en cage, renommer. Reprend la
-- logique Blizzard (memes popups renommer/cage).
-- ====================================================

local PetMenu = ns.RegisterModule("PetMenu", {})
ns.PetMenu = PetMenu

function PetMenu.Open(owner, petID)
    if not petID or not MenuUtil or not MenuUtil.CreateContextMenu then return end

    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("MVL_PET_MENU")

        -- Invoquer / Renvoyer
        local summoned = C_PetJournal.GetSummonedPetGUID() == petID
        local b = root:CreateButton(summoned and PET_DISMISS or BATTLE_PET_SUMMON, function()
            C_PetJournal.SummonPetByGUID(petID)
        end)
        if not C_PetJournal.PetIsSummonable(petID) then b:SetEnabled(false) end

        -- Renommer (popup Blizzard)
        local rn = root:CreateButton(BATTLE_PET_RENAME, function()
            StaticPopup_Show("BATTLE_PET_RENAME", nil, nil, petID)
        end)
        rn:SetEnabled(C_PetJournal.IsJournalUnlocked())

        -- Favori / retirer
        if C_PetJournal.PetIsFavorite(petID) then
            root:CreateButton(BATTLE_PET_UNFAVORITE, function() C_PetJournal.SetFavorite(petID, 0) end)
        else
            root:CreateButton(BATTLE_PET_FAVORITE, function() C_PetJournal.SetFavorite(petID, 1) end)
        end

        -- Relacher (popup de confirmation Blizzard, comme le Codex).
        if C_PetJournal.PetCanBeReleased and C_PetJournal.PetCanBeReleased(petID) then
            local rl = root:CreateButton(BATTLE_PET_RELEASE, function()
                StaticPopup_Show("BATTLE_PET_RELEASE",
                    (PetJournalUtil_GetDisplayName and PetJournalUtil_GetDisplayName(petID)) or "", nil, petID)
            end)
            local ok = not (C_PetJournal.PetIsSlotted(petID)
                or (C_PetBattles and C_PetBattles.IsInBattle())
                or not C_PetJournal.IsJournalUnlocked())
            rl:SetEnabled(ok)
        end

        -- File d'XP (ajouter / retirer)
        if ns.Teams then
            if ns.Teams.QueueHas(petID) then
                root:CreateButton(ns.L("MENU_QUEUE_REMOVE"), function() ns.Teams.QueueRemove(petID) end)
            else
                root:CreateButton(ns.L("MENU_QUEUE_ADD"), function() ns.Teams.QueueAdd(petID) end)
            end
        end

        -- Mise en cage (si echangeable)
        if C_PetJournal.PetIsTradable(petID) then
            local text = BATTLE_PET_PUT_IN_CAGE
            local disabled = false
            if C_PetJournal.PetIsSlotted(petID) then
                text, disabled = BATTLE_PET_PUT_IN_CAGE_SLOTTED, true
            elseif C_PetJournal.PetIsHurt(petID) then
                text, disabled = BATTLE_PET_PUT_IN_CAGE_HEALTH, true
            end
            local cb = root:CreateButton(text, function()
                StaticPopup_Show("BATTLE_PET_PUT_IN_CAGE", nil, nil, petID)
            end)
            cb:SetEnabled(not disabled)
        end
    end)
end
