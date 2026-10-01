local addonName, ns = ...

-- ====================================================
-- TEAMSHAREDIALOG — fenetre d'export/import d'une equipe (code copiable).
-- Partie UI de TeamShare : encodage/decodage et application du payload
-- vivent dans fonctionnalite/TeamShare.lua (ns.TeamShare), ce fichier ne
-- fait que construire/piloter la fenetre autour de ce codec.
-- ====================================================

local TeamShare = ns.TeamShare

-- une seule frame reutilisee, mode export / import / exportCat / importCat.
local dlg, RefreshExportCode, RefreshExportCategoryCode

local function EnsureDlg()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogShareDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(420, 340); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogShareDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    -- Resume de composition (icones inline).
    dlg.summary = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.summary:SetPoint("TOPLEFT", 16, -38); dlg.summary:SetPoint("RIGHT", -16, 0)
    dlg.summary:SetJustifyH("LEFT"); dlg.summary:SetSpacing(4)

    dlg.scriptFS = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dlg.scriptFS:SetPoint("TOPLEFT", dlg.summary, "BOTTOMLEFT", 0, -6)

    -- Choix de categorie (mode import uniquement). Selecteur reutilise de
    -- TeamDialog : la team importee entre directement dans cette categorie.
    dlg.catLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.catLabel:SetPoint("TOPLEFT", 16, -126)
    dlg.picker = ns.TeamDialog and ns.TeamDialog.MakeCategoryPicker(dlg) or nil
    if dlg.picker then
        dlg.picker:SetPoint("LEFT", dlg.catLabel, "RIGHT", 10, 0)
        dlg.picker:SetPoint("RIGHT", dlg, "RIGHT", -16, 0)
    end

    -- Nom de la nouvelle categorie (mode importCat uniquement, meme
    -- emplacement que catLabel/picker : jamais visibles ensemble). Laisse
    -- vide, le nom decode du code (categorie MVL) sert de repli.
    dlg.catNameLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.catNameLabel:SetPoint("TOPLEFT", 16, -126)
    dlg.catNameLabel:Hide()
    dlg.catNameEdit = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    dlg.catNameEdit:SetHeight(20); dlg.catNameEdit:SetAutoFocus(false)
    dlg.catNameEdit:SetPoint("LEFT", dlg.catNameLabel, "RIGHT", 14, 0)
    dlg.catNameEdit:SetPoint("RIGHT", dlg, "RIGHT", -16, 0)
    dlg.catNameEdit:Hide()

    -- Case "xufu" (mode import / importCat) : la chaine collee est un ou
    -- plusieurs codes d'equipe Rematch (xufu.gg) a convertir, pas un code
    -- MVL. Libelle/infobulle changent selon le mode (dlg.xufuTipKey).
    dlg.xufu = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
    dlg.xufu:SetSize(22, 22); dlg.xufu:SetPoint("TOPLEFT", 14, -100)
    dlg.xufu.text = dlg.xufu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.xufu.text:SetPoint("LEFT", dlg.xufu, "RIGHT", 2, 0)
    dlg.xufu:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L(dlg.xufuTipKey or "IMPORT_XUFU_TIP"), nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dlg.xufu:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Case "breed" (mode export) : inclure le breed exact des mascottes dans
    -- le code (l'import chez le destinataire devient strict sur le breed) ou
    -- non (breed "0" ecrit, import tolerant par rarete/niveau, comme avant
    -- cette case). Meme emplacement que la case xufu : jamais visibles ensemble
    -- (import vs export). Decochee par defaut, reinitialisee a chaque ouverture.
    dlg.breedChk = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
    dlg.breedChk:SetSize(22, 22); dlg.breedChk:SetPoint("TOPLEFT", 14, -100)
    dlg.breedChk.text = dlg.breedChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.breedChk.text:SetPoint("LEFT", dlg.breedChk, "RIGHT", 2, 0)
    dlg.breedChk.text:SetText(ns.L("EXPORT_BREED_LABEL"))
    dlg.breedChk:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L("EXPORT_BREED_TIP"), nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dlg.breedChk:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function OnOptionClick()
        if dlg.mode == "exportCat" then RefreshExportCategoryCode(dlg.catID) else RefreshExportCode() end
    end
    dlg.breedChk:SetScript("OnClick", OnOptionClick)

    -- Case "notes" (modes export) : joindre les notes de la team (ou des teams
    -- de la categorie) au code. Sur la meme ligne que la case breed, decochee
    -- par defaut, reinitialisee a chaque ouverture ; grisee si rien a joindre.
    dlg.notesChk = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
    dlg.notesChk:SetSize(22, 22); dlg.notesChk:SetPoint("LEFT", dlg.breedChk.text, "RIGHT", 14, 0)
    dlg.notesChk.text = dlg.notesChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.notesChk.text:SetPoint("LEFT", dlg.notesChk, "RIGHT", 2, 0)
    dlg.notesChk.text:SetText(ns.L("EXPORT_NOTES_LABEL"))
    dlg.notesChk:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L("EXPORT_NOTES_TIP"), nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dlg.notesChk:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dlg.notesChk:SetScript("OnClick", OnOptionClick)

    -- Zone de code (EditBox multiligne dans un ScrollFrame).
    local box = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -150); box:SetPoint("BOTTOMRIGHT", -14, 46)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6); box:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local sf = CreateFrame("ScrollFrame", "MatchViewerLogShareScroll", box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6); sf:SetPoint("BOTTOMRIGHT", -26, 6)
    ns.ScrollSkin.Apply(sf)

    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true); edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal"); edit:SetWidth(360)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) if dlg.mode == "export" then self:HighlightText() end end)
    sf:SetScrollChild(edit)
    dlg.edit = edit

    dlg.hintFS = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dlg.hintFS:SetPoint("BOTTOMLEFT", 16, 20); dlg.hintFS:SetPoint("RIGHT", dlg, "RIGHT", -120, 0)
    dlg.hintFS:SetJustifyH("LEFT")

    -- Bouton d'action (Importer / Tout selectionner) : meme style violet que
    -- les boutons du bas (Invoquer/Enregistrer), pas le bouton Blizzard rouge.
    dlg.action = CreateFrame("Button", nil, dlg, "BackdropTemplate")
    dlg.action:SetSize(100, 22); dlg.action:SetPoint("BOTTOMRIGHT", -14, 14)
    dlg.action:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    dlg.action:SetBackdropColor(0.16, 0.10, 0.22, 1)
    dlg.action:SetBackdropBorderColor(0.55, 0.35, 0.85, 1)
    local ahl = dlg.action:CreateTexture(nil, "HIGHLIGHT"); ahl:SetAllPoints(); ahl:SetColorTexture(1, 1, 1, 0.08)
    dlg.action.text = dlg.action:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.action.text:SetPoint("CENTER")
    dlg.action.SetText = function(self, t) self.text:SetText(t) end
    dlg.action:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    dlg.action:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.55, 0.35, 0.85, 1) end)

    return dlg
end

-- Resume texte d'une composition (a partir de l'equipe chargee).
local function ComposeSummary()
    local c = ns.Teams.current
    local lines = {}
    for i = 1, 3 do
        if c.random[i] then
            local t = c.random[i]
            if t == ns.RANDOM_XP then
                lines[i] = string.format("%d. |cff8fd3ff%s|r", i, ns.L("SLOT_RANDOM_XP"))
            else
                local tn = _G["BATTLE_PET_NAME_" .. t] or ("#" .. t)
                lines[i] = string.format("%d. |cff8fd3ff%s : %s|r", i, ns.L("SLOT_RANDOM"), tn)
            end
        elseif c.special[i] then
            lines[i] = string.format("%d. |cffffd200%s|r", i, ns.L("SLOT_IGNORED"))
        elseif type(c.pets[i]) == "string" then
            local info = ns.Teams.GetPetDisplay(c.pets[i])
            local abil = ns.Teams.GetSlotAbilities(i)
            local icons = ""
            for a = 1, 3 do
                if abil and abil[a] and abil[a].icon then
                    icons = icons .. "|T" .. abil[a].icon .. ":16:16:0:0:64:64:5:59:5:59|t "
                end
            end
            local ic = info and info.icon and ("|T" .. info.icon .. ":18:18:0:0:64:64:5:59:5:59|t ") or ""
            lines[i] = string.format("%d. %s%s |cff8fd3ff%s|r  %s",
                i, ic, info and info.name or "?", info and info.breed or "", icons)
        else
            lines[i] = string.format("%d. |cff808080%s|r", i, ns.L("SLOT_EMPTY"))
        end
    end
    return table.concat(lines, "\n")
end

-- Resume texte d'une categorie (mode exportCat) : nom + liste des teams
-- qu'elle contient (pas le detail des slots, trop dense pour plusieurs teams).
local function ComposeCategorySummary(catID)
    local cat = ns.Cats and ns.Cats.GetByID(catID)
    local teams = ns.Cats and ns.Cats.TeamsIn(catID) or {}
    local lines = { string.format("|cff%s%s|r  (%d)",
        (cat and cat.color) or "ffd200", (cat and cat.name) or "?", #teams) }
    for _, t in ipairs(teams) do lines[#lines + 1] = "- " .. (t.name or "?") end
    return table.concat(lines, "\n")
end

-- Reconstruit uniquement le code affiche + l'etat script (mode export) :
-- c'est la seule partie qui depend de la case breed. Le resume (summary)
-- reste inchange, il decrit l'equipe locale, pas la portabilite du code.
function RefreshExportCode()
    if not (dlg and dlg.mode == "export" and ns.Teams.HasPets()) then return end
    local payload = TeamShare.BuildPayload(dlg.breedChk and dlg.breedChk:GetChecked(),
        dlg.notesChk and dlg.notesChk:GetChecked())
    dlg.scriptFS:SetText(payload.scriptBlob and payload.scriptBlob ~= ""
        and ns.L("EXPORT_SCRIPT_YES") or ns.L("EXPORT_SCRIPT_NO"))
    dlg.edit:SetText(TeamShare.Encode(payload))
end

-- Meme principe que RefreshExportCode, pour une categorie entiere.
function RefreshExportCategoryCode(catID)
    if not (dlg and dlg.mode == "exportCat") then return end
    local code = TeamShare.EncodeCategory(catID, dlg.breedChk and dlg.breedChk:GetChecked(),
        dlg.notesChk and dlg.notesChk:GetChecked())
    dlg.edit:SetText(code or "")
end

-- Cache tous les champs specifiques a un mode : point de depart commun des
-- 4 Open*, chacun ne reaffiche ensuite que ce qui le concerne.
local function HideModeFields()
    dlg.catLabel:Hide(); if dlg.picker then dlg.picker:Hide() end
    dlg.catNameLabel:Hide(); dlg.catNameEdit:Hide()
    if dlg.xufu then dlg.xufu:Hide() end
    if dlg.breedChk then dlg.breedChk:Hide() end
    if dlg.notesChk then dlg.notesChk:Hide() end
end

-- Reinitialise la case notes a l'ouverture d'un export ; grisee si aucune
-- note a joindre (hasNotes).
local function ResetNotesChk(hasNotes)
    if not dlg.notesChk then return end
    dlg.notesChk:SetChecked(false)
    dlg.notesChk:SetEnabled(hasNotes and true or false)
    dlg.notesChk.text:SetTextColor(hasNotes and 1 or 0.5, hasNotes and 1 or 0.5, hasNotes and 1 or 0.5)
    dlg.notesChk:Show()
end

function TeamShare.OpenExport()
    EnsureDlg()
    dlg.mode = "export"
    HideModeFields()
    if dlg.breedChk then dlg.breedChk:SetChecked(false); dlg.breedChk:Show() end
    local cur = ns.Teams.current.sourceTeamID
    ResetNotesChk(ns.Teams.GetNotes(cur) ~= "")
    dlg.title:SetText(ns.L("EXPORT_TITLE"))
    dlg.action:SetText(ns.L("EXPORT_SELECTALL"))

    if not ns.Teams.HasPets() then
        dlg.summary:SetText("")
        dlg.scriptFS:SetText("")
        dlg.edit:SetText("")
        dlg.hintFS:SetText(ns.L("EXPORT_NO_TEAM"))
        dlg:Show(); dlg:Raise()
        return
    end

    dlg.summary:SetText(ComposeSummary())
    dlg.hintFS:SetText(ns.L("EXPORT_HINT"))
    RefreshExportCode()
    dlg.action:SetScript("OnClick", function() dlg.edit:SetFocus(); dlg.edit:HighlightText() end)
    dlg:Show(); dlg:Raise()
end

-- categoryID optionnel : pre-remplit le selecteur (clic droit sur une categorie).
function TeamShare.OpenImport(categoryID)
    EnsureDlg()
    dlg.mode = "import"
    HideModeFields()
    dlg.catLabel:SetText(ns.L("TEAMDLG_CATEGORY")); dlg.catLabel:Show()
    if dlg.picker then dlg.picker:SetCategory(categoryID or "group:none"); dlg.picker:Show() end
    -- Case de conversion visible seulement si un convertisseur de chaine est
    -- present (MatchViewerLog_Converter). Sans lui, seul le code MVL natif est lu.
    if dlg.xufu then
        dlg.xufuTipKey = "IMPORT_XUFU_TIP"
        dlg.xufu.text:SetText(ns.L("IMPORT_XUFU_LABEL"))
        dlg.xufu:SetChecked(false)
        dlg.xufu:SetShown(ns.stringImporters and #ns.stringImporters > 0)
    end
    dlg.title:SetText(ns.L("IMPORT_TITLE"))
    dlg.summary:SetText("")
    dlg.scriptFS:SetText("")
    dlg.hintFS:SetText(ns.L("IMPORT_HINT"))
    dlg.edit:SetText("")
    dlg.action:SetText(ns.L("IMPORT_DO"))
    dlg.action:SetScript("OnClick", function()
        local text = dlg.edit:GetText()
        local payload
        if dlg.xufu and dlg.xufu:GetChecked() then
            -- Convertisseurs fournis par MatchViewerLog_Converter (xufu/Rematch).
            for _, fn in ipairs(ns.stringImporters or {}) do
                local ok, p = pcall(fn, text)
                if ok and p then payload = p; break end
            end
        else
            payload = TeamShare.Decode(text)
        end
        if not payload then
            dlg.scriptFS:SetText("|cffff6060" .. ns.L("IMPORT_BAD_CODE") .. "|r")
            return
        end
        local id, missing = TeamShare.ApplyPayload(payload, dlg.picker and dlg.picker:GetCategory() or nil)
        if id then
            dlg.summary:SetText(ComposeSummary())
            if missing and missing > 0 then
                dlg.scriptFS:SetText("|cffffd200" .. ns.L("IMPORT_MISSING"):format(missing) .. "|r")
            else
                dlg.scriptFS:SetText("|cff40e040" .. ns.L("IMPORT_OK") .. "|r")
            end
        else
            dlg.scriptFS:SetText("|cffff6060" .. ns.L("IMPORT_BAD_CODE") .. "|r")
        end
    end)
    dlg:Show(); dlg:Raise(); dlg.edit:SetFocus()
end

-- Exporte une categorie entiere (toutes ses teams) en un seul code.
function TeamShare.OpenExportCategory(catID)
    EnsureDlg()
    dlg.mode = "exportCat"
    dlg.catID = catID
    HideModeFields()
    if dlg.breedChk then dlg.breedChk:SetChecked(false); dlg.breedChk:Show() end
    dlg.title:SetText(ns.L("EXPORT_CAT_TITLE"))
    dlg.action:SetText(ns.L("EXPORT_SELECTALL"))

    local teams = ns.Cats and ns.Cats.TeamsIn(catID) or {}
    local anyNotes = false
    for _, t in ipairs(teams) do if t.notes and t.notes ~= "" then anyNotes = true; break end end
    ResetNotesChk(anyNotes)
    if #teams == 0 then
        dlg.summary:SetText("")
        dlg.scriptFS:SetText("")
        dlg.edit:SetText("")
        dlg.hintFS:SetText(ns.L("EXPORT_CAT_NO_TEAMS"))
        dlg:Show(); dlg:Raise()
        return
    end

    dlg.summary:SetText(ComposeCategorySummary(catID))
    local withScript = 0
    for _, t in ipairs(teams) do if ns.TeamHasScript(t.id) then withScript = withScript + 1 end end
    dlg.scriptFS:SetText(string.format(ns.L("EXPORT_CAT_SCRIPT_COUNT"), withScript, #teams))
    dlg.hintFS:SetText(ns.L("EXPORT_HINT"))
    RefreshExportCategoryCode(catID)
    dlg.action:SetScript("OnClick", function() dlg.edit:SetFocus(); dlg.edit:HighlightText() end)
    dlg:Show(); dlg:Raise()
end

-- Importe une categorie entiere : code de categorie MVL, ou (case xufu)
-- plusieurs codes Xufu colles a la suite. existingCategoryID optionnel :
-- rejoint une categorie existante au lieu d'en creer une nouvelle (dans ce
-- cas le champ nom est masque, inutile).
function TeamShare.OpenImportCategory(existingCategoryID)
    EnsureDlg()
    dlg.mode = "importCat"
    dlg.catID = existingCategoryID
    HideModeFields()
    if not existingCategoryID then
        dlg.catNameLabel:SetText(ns.L("IMPORT_CAT_NAME_LABEL")); dlg.catNameLabel:Show()
        dlg.catNameEdit:SetText(""); dlg.catNameEdit:Show()
    end
    -- Case de conversion visible seulement si un convertisseur "categorie"
    -- est present (MatchViewerLog_Converter).
    if dlg.xufu then
        dlg.xufuTipKey = "IMPORT_XUFU_CAT_TIP"
        dlg.xufu.text:SetText(ns.L("IMPORT_XUFU_CAT_LABEL"))
        dlg.xufu:SetChecked(false)
        dlg.xufu:SetShown(ns.categoryStringImporters and #ns.categoryStringImporters > 0)
    end
    dlg.title:SetText(ns.L("IMPORT_CAT_TITLE"))
    dlg.summary:SetText("")
    dlg.scriptFS:SetText("")
    dlg.hintFS:SetText(ns.L("IMPORT_CAT_HINT"))
    dlg.edit:SetText("")
    dlg.action:SetText(ns.L("IMPORT_DO"))
    dlg.action:SetScript("OnClick", function()
        local text = dlg.edit:GetText()
        local catPayload
        if dlg.xufu and dlg.xufu:GetChecked() then
            for _, fn in ipairs(ns.categoryStringImporters or {}) do
                local ok, teams = pcall(fn, text)
                if ok and teams and #teams > 0 then
                    local name = dlg.catNameEdit:GetText()
                    name = name and name:trim() or ""
                    if name == "" and not dlg.catID then
                        dlg.scriptFS:SetText("|cffff6060" .. ns.L("IMPORT_CAT_NEED_NAME") .. "|r")
                        return
                    end
                    catPayload = { name = name, color = nil, teams = teams }
                    break
                end
            end
        else
            catPayload = TeamShare.DecodeCategory(text)
            if catPayload then
                local typedName = dlg.catNameEdit:GetText()
                typedName = typedName and typedName:trim() or ""
                if typedName ~= "" then catPayload.name = typedName end
            end
        end
        if not catPayload then
            dlg.scriptFS:SetText("|cffff6060" .. ns.L("IMPORT_BAD_CODE") .. "|r")
            return
        end
        local catID, imported, missing = TeamShare.ApplyCategoryPayload(catPayload, dlg.catID)
        if catID then
            local catName = (ns.Cats and ns.Cats.GetByID(catID) and ns.Cats.GetByID(catID).name) or catPayload.name
            dlg.summary:SetText(ComposeCategorySummary(catID))
            dlg.scriptFS:SetText("|cff40e040" .. string.format(ns.L("IMPORT_CAT_DONE"), imported, catName) .. "|r")
            if missing and missing > 0 then
                dlg.hintFS:SetText(ns.L("IMPORT_MISSING"):format(missing))
            end
        else
            dlg.scriptFS:SetText("|cffff6060" .. ns.L("IMPORT_BAD_CODE") .. "|r")
        end
    end)
    dlg:Show(); dlg:Raise(); dlg.edit:SetFocus()
end
