local addonName, ns = ...

-- ====================================================
-- NOTESDIALOG — fenetre de notes libres de l'equipe chargee. Sauvegarde
-- a la frappe dans la team (Teams.SetNotes). Suit l'equipe chargee ;
-- sans team enregistree, la saisie est desactivee.
-- ====================================================

local Notes = ns.RegisterModule("NotesDialog", {})
ns.NotesDialog = Notes

local W, H = 380, 300
local dlg

local function CurrentID()
    local id = ns.Teams and ns.Teams.current.sourceTeamID
    return (id and ns.DB and ns.DB.teams[id]) and id or nil
end

local function SetTitle(id)
    local name = id and ns.DB.teams[id].name or nil
    dlg.title:SetText(ns.L("NOTES_TITLE") .. (name and (" |cff40e0d0" .. name .. "|r") or ""))
end

local function Refresh()
    if not dlg then return end
    local id = CurrentID()
    dlg.id = id
    dlg.loading = true
    SetTitle(id)
    if id then
        dlg.edit:SetText(ns.Teams.GetNotes(id))
        dlg.edit:Enable()
        dlg.hint:Hide()
    else
        dlg.edit:SetText("")
        dlg.edit:Disable(); dlg.edit:ClearFocus()
        dlg.hint:Show()
    end
    dlg.loading = false
    dlg.scroll:SetVerticalScroll(0)
end

local function EnsureDlg()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogNotesDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(W, H); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("FULLSCREEN_DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:SetClampedToScreen(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogNotesDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOPLEFT", 16, -14); dlg.title:SetPoint("RIGHT", -34, 0)
    dlg.title:SetJustifyH("LEFT"); dlg.title:SetWordWrap(false)

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local box = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -38); box:SetPoint("BOTTOMRIGHT", -14, 14)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6); box:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local scroll = CreateFrame("ScrollFrame", "MatchViewerLogNotesScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6); scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    dlg.scroll = scroll
    ns.ScrollSkin.Apply(scroll)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject("ChatFontNormal")
    edit:SetMaxLetters(ns.Teams.NOTES_MAX)
    edit:SetWidth(W - 14 * 2 - 6 - 26)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        if dlg.loading then return end
        if dlg.id then ns.Teams.SetNotes(dlg.id, self:GetText()) end
    end)
    -- Garde le curseur visible pendant la frappe.
    edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
        y = -y
        local top, view = scroll:GetVerticalScroll(), scroll:GetHeight()
        if y < top then scroll:SetVerticalScroll(y)
        elseif y + h > top + view then scroll:SetVerticalScroll(y + h - view) end
    end)
    scroll:SetScrollChild(edit)
    -- Clic dans la zone vide = focus sur la saisie.
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() if edit:IsEnabled() then edit:SetFocus() end end)
    dlg.edit = edit

    dlg.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    dlg.hint:SetPoint("CENTER"); dlg.hint:SetWidth(W - 80); dlg.hint:SetText(ns.L("NOTES_NO_TEAM"))

    -- Une frame est visible a la creation : on la masque avant de brancher
    -- OnShow, sinon le 1er Toggle la referme au lieu de l'ouvrir.
    dlg:Hide()
    dlg:SetScript("OnShow", Refresh)
    return dlg
end

function Notes.Toggle()
    EnsureDlg()
    if dlg:IsShown() then dlg:Hide() else dlg:Show(); dlg:Raise() end
end

-- Suit l'equipe chargee / supprimee tant que la fenetre est ouverte.
local function Follow()
    if not (dlg and dlg:IsShown()) then return end
    local id = CurrentID()
    if id and id == dlg.id then SetTitle(id) else Refresh() end
end
ns.On("TEAM_LOADED", Follow)
ns.On("TEAMS_CHANGED", Follow)
ns.On("MVL_FRAME_HIDE", function() if dlg then dlg:Hide() end end)
