local addonName, ns = ...

-- ====================================================
-- CODEEDITOR — editeur texte du langage de script (equipe chargee).
-- Champ multi-ligne dans un ScrollFrame maison (largeur suivie sur
-- OnSizeChanged). Valide via ns.Engine.Build a l'enregistrement.
-- ====================================================

local Editor = ns.RegisterModule("CodeEditor", {})
ns.CodeEditor = Editor

function Editor.Create(parent)
    local f = CreateFrame("Frame", nil, parent)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 2, 0)
    f.title:SetPoint("TOPRIGHT", -2, 0)
    f.title:SetJustifyH("LEFT"); f.title:SetWordWrap(false)

    -- Cadre + fond sombre pour la zone de saisie.
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -22)
    sf:SetPoint("BOTTOMRIGHT", -24, 54)
    if ns.MVL and ns.MVL.SkinScrollBar then ns.MVL.SkinScrollBar(sf) end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", sf, "TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 4, -4)
    bg:SetColorTexture(0, 0, 0, 0.55)

    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetJustifyH("LEFT")
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetWidth(200)
    edit:SetHeight(200)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(edit)
    sf:SetScript("OnSizeChanged", function(_, w) if w and w > 20 then edit:SetWidth(w) end end)
    sf:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    -- Message d'erreur / etat.
    f.msg = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.msg:SetPoint("BOTTOMLEFT", 2, 30)
    f.msg:SetPoint("BOTTOMRIGHT", -2, 30)
    f.msg:SetJustifyH("LEFT")

    -- Bouton Enregistrer.
    local save = ns.Widgets.SmallBtn(f, 100, ns.L("CODE_SAVE"), ns.Widgets.SPEC.purple)
    save:SetPoint("BOTTOMLEFT", 2, 4); save:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -2, 4)
    save:SetScript("OnClick", function()
        local id = ns.CurrentEditTeam()
        if not id then return end
        local ok, err = ns.Scripts.SetCode(id, f.edit:GetText())
        if ok then
            f.msg:SetText("|cff40ff40" .. ns.L("CODE_SAVED") .. "|r")
        else
            f.msg:SetText("|cffff6060" .. (err or ns.L("CODE_ERROR")) .. "|r")
        end
    end)

    -- Bouton Supprimer (confirmation).
    local del = ns.Widgets.SmallBtn(f, 100, ns.L("CODE_DELETE"), ns.Widgets.SPEC.red)
    del:SetPoint("BOTTOMLEFT", f, "BOTTOM", 2, 4); del:SetPoint("BOTTOMRIGHT", -2, 4)
    del:SetScript("OnClick", function()
        local id = ns.CurrentEditTeam()
        if not (id and ns.Scripts.Has(id)) then return end
        local cur = ns.MVL.GetCurrentTeam()
        StaticPopup_Show("MSVL_DELETE_SCRIPT", cur and cur.name or id, nil, id)
    end)
    f.delete = del

    StaticPopupDialogs["MSVL_DELETE_SCRIPT"] = {
        text = ns.L("CODE_DELETE_CONFIRM"),
        button1 = ns.L("CODE_DELETE"),
        button2 = CANCEL,
        OnAccept = function(_, id)
            f.edit:ClearFocus()
            if ns.Scripts.Delete(id) then
                f.msg:SetText("|cff40ff40" .. ns.L("CODE_DELETED") .. "|r")
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    function f:RefreshEditor()
        local id = ns.CurrentEditTeam()
        local cur = ns.MVL.GetCurrentTeam()
        if not id then
            self.title:SetText("|cffff8080" .. ns.L("EDIT_NO_TEAM") .. "|r")
        else
            self.title:SetText("|cffbfa0ff" .. ns.L("CODE_TITLE"):format(cur and cur.name or id) .. "|r")
        end
        if not self.edit:HasFocus() then
            self.edit:SetText(id and ns.Scripts.GetCode(id) or "")
            self.edit:SetCursorPosition(0)
        end
        self.msg:SetText("")
        self.delete:SetShown(id ~= nil and ns.Scripts.Has(id))
    end

    return f
end
