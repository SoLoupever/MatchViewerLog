local addonName, ns = ...

-- ====================================================
-- WIDGETS — petits composants UI reutilises par plusieurs panneaux
-- (jusqu'ici copies-colles entre LeftPanel et RightPanel).
-- ====================================================

local Widgets = ns.RegisterModule("Widgets", {})
ns.Widgets = Widgets

-- Barre de recherche a bordure carree doree (loupe + texte d'invite).
-- onChanged(text) est appele a chaque frappe. Retourne l'EditBox.
function Widgets.MakeSearchBox(parent, placeholder, onChanged)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetAutoFocus(false); e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(22, 20, 2, 2)
    ns.Style.Paint(e, { 0.04, 0.04, 0.05, 1 }, ns.Style.COL.border)
    local ic = e:CreateTexture(nil, "OVERLAY")
    ic:SetSize(14, 14); ic:SetPoint("LEFT", 5, 0)
    ic:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local ph = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 24, 0); ph:SetText(placeholder or "")
    -- Croix d'effacement : visible seulement quand il y a du texte.
    local clr = CreateFrame("Button", nil, e)
    clr:SetSize(16, 16); clr:SetPoint("RIGHT", -4, 0); clr:Hide()
    local ct = clr:CreateTexture(nil, "ARTWORK")
    ct:SetAllPoints(); ct:SetAtlas("common-search-clearbutton"); ct:SetAlpha(0.6)
    clr:SetScript("OnEnter", function() ct:SetAlpha(1) end)
    clr:SetScript("OnLeave", function() ct:SetAlpha(0.6) end)
    clr:SetScript("OnClick", function() e:SetText(""); e:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged", function(self)
        local empty = (self:GetText() or "") == ""
        ph:SetShown(empty); clr:SetShown(not empty)
        if onChanged then onChanged(self:GetText() or "") end
    end)
    return e
end
