local addonName, ns = ...

-- ====================================================
-- CATEGORYDIALOG — fenetre de creation / edition d'une categorie :
-- champ nom + palette de couleurs. Ouverte par le bouton Teams
-- (creation) ou par clic droit sur une categorie (edition).
-- ====================================================

local CD = ns.RegisterModule("CategoryDialog", {})
ns.CategoryDialog = CD

local COLORS = {
    "ffd200", "ff5555", "ff8844", "eeee44", "55dd55", "40e0d0",
    "5599ff", "bb66ff", "ff66aa", "ffffff", "aaaaaa", "88ffcc",
}

local dlg

local function UpdateSwatches()
    if not dlg then return end
    for _, sw in ipairs(dlg.swatches) do
        local on = (sw.hex == dlg.selHex)
        sw:SetBackdropBorderColor(on and 1 or 0, on and 0.82 or 0, 0, on and 1 or 0)
    end
end

local function OnAccept()
    local name = dlg.edit:GetText()
    if not name or name:trim() == "" then return end
    name = name:trim()
    local hex = dlg.selHex or "ffd200"
    if dlg.editID then ns.Cats.Update(dlg.editID, name, hex) else ns.Cats.Create(name, hex) end
    dlg:Hide()
end

local function Build()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogCatDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(280, 210); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogCatDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)

    local nl = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nl:SetPoint("TOPLEFT", 16, -42); nl:SetText(ns.L("CATDLG_NAME"))
    dlg.edit = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    dlg.edit:SetSize(226, 20); dlg.edit:SetPoint("TOPLEFT", 22, -58); dlg.edit:SetAutoFocus(false)
    dlg.edit:SetScript("OnEnterPressed", OnAccept)
    dlg.edit:SetScript("OnEscapePressed", function() dlg:Hide() end)

    -- Note affichee seulement pour les categories a nom protege (Favoris /
    -- Aucune categorie) : le champ nom est desactive au-dessus, pas juste
    -- silencieusement ignore au clic OK.
    dlg.lockNote = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dlg.lockNote:SetPoint("TOPLEFT", dlg.edit, "BOTTOMLEFT", 0, -2)
    dlg.lockNote:SetText(ns.L("CATDLG_NAME_LOCKED"))
    dlg.lockNote:Hide()

    local cl = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cl:SetPoint("TOPLEFT", 16, -88); cl:SetText(ns.L("CATDLG_COLOR"))
    dlg.swatches = {}
    for i, hex in ipairs(COLORS) do
        local sw = CreateFrame("Button", nil, dlg, "BackdropTemplate")
        sw:SetSize(22, 22)
        local rowi, coli = math.floor((i - 1) / 6), (i - 1) % 6
        sw:SetPoint("TOPLEFT", 22 + coli * 28, -104 - rowi * 28)
        sw:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        sw:SetBackdropColor(r, g, b, 1); sw:SetBackdropBorderColor(0, 0, 0, 0)
        sw.hex = hex
        sw:SetScript("OnClick", function(self) dlg.selHex = self.hex; UpdateSwatches() end)
        dlg.swatches[i] = sw
    end

    dlg.ok = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    dlg.ok:SetSize(96, 22); dlg.ok:SetPoint("BOTTOMRIGHT", -16, 14); dlg.ok:SetText(OKAY)
    dlg.ok:SetScript("OnClick", OnAccept)
    local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    cancel:SetSize(96, 22); cancel:SetPoint("BOTTOMLEFT", 16, 14); cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function() dlg:Hide() end)

    return dlg
end

-- id nil = creation ; id = edition.
function CD.Open(id)
    Build()
    dlg.editID = id
    local locked = id ~= nil and ns.Cats and ns.Cats.IsNameLocked(id)
    if id then
        local c = ns.Cats.GetByID(id)
        dlg.title:SetText(ns.L("CATDLG_EDIT"))
        dlg.edit:SetText(c and c.name or "")
        dlg.selHex = (c and c.color) or "ffd200"
    else
        dlg.title:SetText(ns.L("CATDLG_CREATE"))
        dlg.edit:SetText("")
        dlg.selHex = "ffd200"
    end
    if locked then
        dlg.edit:Disable(); dlg.lockNote:Show()
    else
        dlg.edit:Enable(); dlg.lockNote:Hide()
    end
    UpdateSwatches()
    dlg:Show(); dlg:Raise()
    if not locked then dlg.edit:SetFocus() end
end
