local addonName, ns = ...

-- ====================================================
-- DELETECATEGORYDIALOG — confirmation de suppression d'une categorie,
-- avec case optionnelle pour supprimer aussi ses equipes. Decochee par
-- defaut, reinitialisee a chaque ouverture.
-- ====================================================

local Dlg = ns.RegisterModule("DeleteCategoryDialog", {})
ns.DeleteCategoryDialog = Dlg

local dlg

local function UpdateText()
    dlg.text:SetText(ns.L(dlg.chk:GetChecked() and "DELCAT_CONFIRM_ALL" or "DELCAT_CONFIRM"))
end

local function EnsureDlg()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogDeleteCategoryDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(360, 160); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogDeleteCategoryDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)
    dlg.title:SetText(ns.L("MENU_DELETE_CAT"))

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    dlg.text = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dlg.text:SetPoint("TOPLEFT", 18, -38); dlg.text:SetPoint("TOPRIGHT", -18, -38)
    dlg.text:SetJustifyH("LEFT"); dlg.text:SetWordWrap(true)

    dlg.chk = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
    dlg.chk:SetSize(22, 22); dlg.chk:SetPoint("TOPLEFT", 14, -82)
    dlg.chk.text = dlg.chk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.chk.text:SetPoint("LEFT", dlg.chk, "RIGHT", 2, 0)
    dlg.chk:SetScript("OnClick", UpdateText)

    dlg.ok = ns.Style.Button(dlg, DELETE, 110, 22)
    dlg.ok:SetPoint("BOTTOMRIGHT", dlg, "BOTTOM", -4, 14)
    dlg.ok:SetScript("OnClick", function()
        if dlg.catID and ns.Cats then
            ns.Cats.Delete(dlg.catID, dlg.chk:IsShown() and dlg.chk:GetChecked())
        end
        dlg:Hide()
    end)

    local cancel = ns.Style.Button(dlg, CANCEL, 110, 22)
    cancel:SetPoint("BOTTOMLEFT", dlg, "BOTTOM", 4, 14)
    cancel:SetScript("OnClick", function() dlg:Hide() end)

    dlg:Hide()
    return dlg
end

function Dlg.Open(catID)
    if not catID then return end
    EnsureDlg()
    dlg.catID = catID
    local n = ns.Teams and ns.Teams.CountByCategory(catID) or 0
    dlg.chk:SetChecked(false)
    dlg.chk:SetShown(n > 0)
    dlg.chk.text:SetText(ns.L("DELCAT_WITH_TEAMS"):format(n))
    UpdateText()
    dlg:Show(); dlg:Raise()
end
