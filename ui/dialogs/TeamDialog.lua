local addonName, ns = ...

-- ====================================================
-- TEAMDIALOG — fenetre nom + categorie d'une equipe. Deux usages :
-- OpenSave (enregistrer la compo courante : nom + categorie) et
-- OpenEdit (renommer / deplacer une equipe deja enregistree). Expose
-- aussi MakeCategoryPicker, un selecteur de categorie reutilise a
-- l'import (TeamShare). Aucune string en dur : tout via ns.L.
-- ====================================================

local TD = ns.RegisterModule("TeamDialog", {})
ns.TeamDialog = TD

local NONE = "group:none"

-- Libelle colore d'une categorie (ou "aucune" si nil/absente/none).
local function CatLabel(id)
    if not id or id == NONE then return ns.L("TEAMDLG_NO_CATEGORY") end
    local c = ns.Cats and ns.Cats.GetByID(id)
    if not c then return ns.L("TEAMDLG_NO_CATEGORY") end
    return "|cff" .. (c.color or "ffd200") .. (c.name or "?") .. "|r"
end

-- Selecteur de categorie reutilisable. Le menu liste "aucune" + les
-- categories reelles ; Favoris est ecartee (virtuelle : flag t.favorite,
-- pas un champ category). Le parent fixe la largeur via SetPoint.
function TD.MakeCategoryPicker(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(22)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    btn:SetBackdropColor(0.12, 0.12, 0.16, 1); btn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    btn.selected = NONE

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 6, 0); fs:SetPoint("RIGHT", -18, 0)
    fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12); arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetAtlas("housing-floor-arrow-down-default")

    function btn:GetCategory() return self.selected end
    function btn:SetCategory(id)
        self.selected = id or NONE
        fs:SetText(CatLabel(self.selected))
    end

    btn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_CATPICKER")
            root:CreateButton(ns.L("TEAMDLG_NO_CATEGORY"), function() self:SetCategory(NONE) end)
            for _, c in ipairs(ns.Cats and ns.Cats.List() or {}) do
                -- group:none deja couvert par l'entree "Aucune categorie" ci-dessus.
                if c.id ~= "group:favorites" and c.id ~= NONE then
                    root:CreateButton("|cff" .. (c.color or "ffd200") .. (c.name or "?") .. "|r", function()
                        self:SetCategory(c.id)
                    end)
                end
            end
        end)
    end)

    btn:SetCategory(NONE)
    return btn
end

local dlg

local function OnAccept()
    local name = dlg.edit:GetText()
    if not name or name:trim() == "" then return end
    name = name:trim()
    local cat = dlg.picker:GetCategory()
    if not ns.Teams then dlg:Hide(); return end
    if dlg.editID then
        ns.Teams.SetInfo(dlg.editID, name, cat)
    else
        ns.Teams.Save(name, cat)
    end
    dlg:Hide()
end

local function Build()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogTeamDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(300, 172); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogTeamDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)

    local nl = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nl:SetPoint("TOPLEFT", 16, -42); nl:SetText(ns.L("CATDLG_NAME"))
    dlg.edit = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    dlg.edit:SetSize(246, 20); dlg.edit:SetPoint("TOPLEFT", 22, -58); dlg.edit:SetAutoFocus(false)
    dlg.edit:SetScript("OnEnterPressed", OnAccept)
    dlg.edit:SetScript("OnEscapePressed", function() dlg:Hide() end)

    local cl = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cl:SetPoint("TOPLEFT", 16, -92); cl:SetText(ns.L("TEAMDLG_CATEGORY"))
    dlg.picker = TD.MakeCategoryPicker(dlg)
    dlg.picker:SetPoint("TOPLEFT", 22, -108); dlg.picker:SetPoint("RIGHT", dlg, "RIGHT", -22, 0)

    dlg.ok = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    dlg.ok:SetSize(96, 22); dlg.ok:SetPoint("BOTTOMRIGHT", -16, 14); dlg.ok:SetText(OKAY)
    dlg.ok:SetScript("OnClick", OnAccept)
    local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    cancel:SetSize(96, 22); cancel:SetPoint("BOTTOMLEFT", 16, 14); cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function() dlg:Hide() end)

    return dlg
end

-- Enregistre la composition courante (nom + categorie). "Enregistrer" cree
-- TOUJOURS une nouvelle team (Teams.Save, jamais une mise a jour) : la
-- categorie par defaut est "aucune", jamais celle de la derniere team
-- chargee/sauvee (Teams.current.category), sinon une team heritait en
-- silence de la derniere categorie utilisee des qu'on validait par Entree
-- sans rouvrir le picker.
function TD.OpenSave()
    Build()
    dlg.editID = nil
    dlg.title:SetText(ns.L("TEAMDLG_SAVE_TITLE"))
    local c = ns.Teams and ns.Teams.current
    dlg.edit:SetText(c and c.name or "")
    dlg.picker:SetCategory(NONE)
    dlg:Show(); dlg:Raise(); dlg.edit:SetFocus()
end

-- Renomme / deplace une equipe enregistree (clic droit sur une team).
function TD.OpenEdit(id)
    Build()
    local t = id and ns.DB and ns.DB.teams[id]
    if not t then return end
    dlg.editID = id
    dlg.title:SetText(ns.L("TEAMDLG_EDIT_TITLE"))
    dlg.edit:SetText(t.name or "")
    dlg.picker:SetCategory(t.category or NONE)
    dlg:Show(); dlg:Raise(); dlg.edit:SetFocus()
end
