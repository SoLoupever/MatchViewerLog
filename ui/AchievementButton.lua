local addonName, ns = ...

-- ====================================================
-- ACHIEVEMENTBUTTON — hauts faits mascottes (bouclier + points),
-- barre du haut, au milieu (remplit frame.achievBox). Clic = reutilise le handler
-- Blizzard du Codex (PetJournalAchievementStatus_OnClick).
-- ====================================================

ns.RegisterModule("AchievementButton", {})

local box, pointsFS

local function Refresh()
    if not pointsFS then return end
    local cat = PET_ACHIEVEMENT_CATEGORY
    pointsFS:SetText(cat and GetCategoryAchievementPoints(cat, true) or "")
end

local function Build()
    if box then return end
    local frame = ns.Frame and ns.Frame.frame
    box = frame and frame.achievBox
    if not box then return end

    local icon = box:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18); icon:SetPoint("RIGHT", -6, 0)
    icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields-NoPoints")
    icon:SetTexCoord(0, 0.5, 0, 0.5)

    pointsFS = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsFS:SetPoint("RIGHT", icon, "LEFT", -3, 0)

    local btn = CreateFrame("Button", nil, box)
    btn:SetAllPoints()
    local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
    btn:SetScript("OnClick", function()
        if PetJournalAchievementStatus_OnClick then PetJournalAchievementStatus_OnClick() end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(BATTLE_PETS_ACHIEVEMENT or ns.L("ACHIEV_TITLE"), 1, 1, 1)
        GameTooltip:AddLine(BATTLE_PETS_ACHIEVEMENT_TOOLTIP or ns.L("ACHIEV_HINT"), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Refresh()
end

ns.On("MVL_FRAME_READY", Build)
ns.On("MVL_FRAME_SHOW", Refresh)
ns.RegisterWowEvent("ACHIEVEMENT_EARNED", Refresh)
