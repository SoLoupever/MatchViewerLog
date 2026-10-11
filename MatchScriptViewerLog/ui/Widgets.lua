local addonName, ns = ...

-- ====================================================
-- WIDGETS — petits composants UI partages du compagnon.
-- ====================================================

local W = ns.RegisterModule("Widgets", {})
ns.Widgets = W

local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

function W.SmallBtn(parent, w, label)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 20)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.14, 0.12, 0.18, 1); b:SetBackdropBorderColor(0.4, 0.3, 0.55, 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER"); b.text:SetText(label)
    return b
end
